/* MeijinOS RISC-V編 検証カーネル
   目的: 本書掲載のログ・数値を実測で確定させる */

typedef unsigned int   uint32_t;
typedef unsigned char  uint8_t;
typedef unsigned int   size_t;

#define UART0 0x10000000u
#define PAGE_SIZE 4096
#define SATP_SV32 (1u << 31)

#define PTE_V (1<<0)
#define PTE_R (1<<1)
#define PTE_W (1<<2)
#define PTE_X (1<<3)
#define PTE_U (1<<4)

#define MAX_PROCS 4
#define RUNNABLE 1
#define RUNNING  2
#define DEAD     3

#define SYS_PUTC   1
#define SYS_EXIT   2
#define SYS_YIELD  3
#define SYS_SEND   4
#define SYS_RECV   5
#define SYS_PUTHEX 6

/* frame index */
#define F_PC  0
#define F_SP  2
#define F_A0  10
#define F_A1  11
#define F_A7  17

extern char heap_start[], heap_end[];

static char *next_free;

/* ---------------- UART ---------------- */
static void uart_putc(char c) { *(volatile uint8_t*)UART0 = c; }
static void uart_puts(const char *s) { while (*s) uart_putc(*s++); }

static void put_hex(uint32_t v) {
    const char *d = "0123456789abcdef";
    uart_puts("0x");
    for (int i = 28; i >= 0; i -= 4) uart_putc(d[(v >> i) & 0xf]);
}
static void put_dec(uint32_t v) {
    char b[12]; int i = 0;
    if (!v) { uart_putc('0'); return; }
    while (v) { b[i++] = '0' + v % 10; v /= 10; }
    while (i--) uart_putc(b[i]);
}

/* ---------------- mem ---------------- */
static void *memset_(void *p, int c, size_t n) {
    uint8_t *q = p; while (n--) *q++ = (uint8_t)c; return p;
}
static void *memcpy_(void *d, const void *s, size_t n) {
    uint8_t *a = d; const uint8_t *b = s; while (n--) *a++ = *b++; return d;
}

static void *alloc_page(void) {
    if (next_free + PAGE_SIZE > heap_end) { uart_puts("OOM\n"); for(;;); }
    void *p = next_free; next_free += PAGE_SIZE;
    memset_(p, 0, PAGE_SIZE);
    return p;
}

/* ---------------- page table ---------------- */
static void map_page(uint32_t *root, uint32_t va, uint32_t pa, uint32_t flags) {
    uint32_t vpn1 = (va >> 22) & 0x3ff;
    uint32_t vpn0 = (va >> 12) & 0x3ff;
    if (!(root[vpn1] & PTE_V)) {
        uint32_t *lv0 = alloc_page();
        root[vpn1] = (((uint32_t)lv0 >> 12) << 10) | PTE_V;
    }
    uint32_t *lv0 = (uint32_t *)((root[vpn1] >> 10) << 12);
    lv0[vpn0] = ((pa >> 12) << 10) | flags | PTE_V;
}

static uint32_t *kernel_pt;

static void kernel_map_init(void) {
    kernel_pt = alloc_page();
    for (uint32_t a = 0x80000000u; a < 0x88000000u; a += PAGE_SIZE)
        map_page(kernel_pt, a, a, PTE_R | PTE_W | PTE_X);
    map_page(kernel_pt, UART0, UART0, PTE_R | PTE_W);
}

static void switch_pt(uint32_t *root) {
    uint32_t satp = SATP_SV32 | ((uint32_t)root >> 12);
    __asm__ volatile("csrw satp, %0" :: "r"(satp));
    __asm__ volatile("sfence.vma zero, zero");
}

/* ---------------- process ---------------- */
struct process {
    int pid, state;
    uint32_t *page_table;
    uint32_t tf[32];        /* [0]=PC, [1..31]=x1..x31（計32 word） */
};
static struct process procs[MAX_PROCS];
static struct process *current;
static int nproc = 0;
static int all_done = 0;

struct mailbox { uint32_t data; int has_mail, from_pid; };
static struct mailbox mailboxes[MAX_PROCS+1];

#define USER_CODE_VA   0x1000u
#define USER_STACK_VA  0x2000u
#define USER_STACK_TOP 0x3000u

static struct process *create_process(const void *code, size_t size) {
    struct process *p = &procs[nproc];
    p->pid = nproc + 1;
    nproc++;
    p->page_table = alloc_page();

    for (uint32_t a = 0x80000000u; a < 0x88000000u; a += PAGE_SIZE)
        map_page(p->page_table, a, a, PTE_R | PTE_W | PTE_X);
    map_page(p->page_table, UART0, UART0, PTE_R | PTE_W);

    void *cp = alloc_page();
    memcpy_(cp, code, size);
    map_page(p->page_table, USER_CODE_VA, (uint32_t)cp, PTE_R | PTE_X | PTE_U);

    void *sp = alloc_page();
    map_page(p->page_table, USER_STACK_VA, (uint32_t)sp, PTE_R | PTE_W | PTE_U);

    p->tf[F_PC] = USER_CODE_VA;
    p->tf[F_SP] = USER_STACK_TOP;
    p->state = RUNNABLE;

    uart_puts("[PROC] created pid="); put_dec(p->pid);
    uart_puts(" (pt="); put_hex((uint32_t)p->page_table); uart_puts(")\n");
    return p;
}

static void enter_user(struct process *p);

/* 実験の進行状態。schedule() が尽きたら次の実験へ（スタックを捨てて再入） */
static int exp_stage = 0;
void run_stage(void);
static void resume_main(void) {
    exp_stage++;
    __asm__ volatile("la sp, kernel_stack_top");
    run_stage();
    for(;;);
}

static void schedule(void) {
    for (int i = 0; i < nproc; i++) {
        int idx = (current ? (current - procs + 1 + i) % nproc : i);
        if (procs[idx].state == RUNNABLE) {
            current = &procs[idx];
            enter_user(current);
        }
    }
    uart_puts("[PROC] all processes exited.\n");
    switch_pt(kernel_pt);                     /* カーネル空間へ戻る */
    __asm__ volatile("csrw sscratch, zero");
    resume_main();                            /* 次の実験へ */
}

/* current を U-mode で走らせる（トラップで戻ってくる） */
static void enter_user(struct process *p) {
    switch_pt(p->page_table);
    __asm__ volatile("csrw sscratch, %0" :: "r"((uint32_t)p->tf));
    __asm__ volatile("csrw sepc, %0" :: "r"(p->tf[F_PC]));
    /* SPP=0 -> U-mode */
    __asm__ volatile("csrc sstatus, %0" :: "r"(1u << 8));
    /* restore user regs and sret : trap_entry の復元経路を再利用 */
    __asm__ volatile(
        "csrr t0, sscratch\n"
        "lw   ra,  1*4(t0)\n"
        "lw   sp,  2*4(t0)\n"
        "lw   a0, 10*4(t0)\n"
        "lw   a1, 11*4(t0)\n"
        "lw   a7, 17*4(t0)\n"
        "lw   s0,  8*4(t0)\n"
        "lw   t1,  6*4(t0)\n"
        "lw   t2,  7*4(t0)\n"
        "lw   t0,  5*4(t0)\n"
        "sret\n");
}

/* ---------------- syscall ---------------- */
static void handle_syscall(void) {
    uint32_t *tf = current->tf;
    switch (tf[F_A7]) {
    case SYS_PUTC:
        uart_putc((char)tf[F_A0]);
        tf[F_A0] = 0;
        break;
    case SYS_PUTHEX:
        put_hex(tf[F_A0]);
        tf[F_A0] = 0;
        break;
    case SYS_EXIT:
        uart_puts("[SYS] process "); put_dec(current->pid); uart_puts(" exited.\n");
        current->state = DEAD;
        break;                       /* 切り替えは trap_handler の帰り道の一回だけ */
    case SYS_YIELD:
        break;                       /* trap_handler 側で切替 */
    case SYS_SEND: {
        int to = (int)tf[F_A0];
        mailboxes[to].data = tf[F_A1];
        mailboxes[to].from_pid = current->pid;
        mailboxes[to].has_mail = 1;
        uart_puts("[IPC] pid="); put_dec(current->pid);
        uart_puts(" -> pid="); put_dec(to);
        uart_puts(" : "); put_hex(tf[F_A1]); uart_puts("\n");
        break;
    }
    case SYS_RECV: {
        struct mailbox *mb = &mailboxes[current->pid];
        if (!mb->has_mail) {         /* まだ来ていない: PCを戻して再試行させる */
            tf[F_PC] -= 4;
            break;
        }
        mb->has_mail = 0;
        tf[F_A0] = mb->data;
        uart_puts("[IPC] pid="); put_dec(current->pid);
        uart_puts(" received "); put_hex(mb->data);
        uart_puts(" from pid="); put_dec(mb->from_pid); uart_puts("\n");
        break;
    }
    default:
        uart_puts("[SYS] unknown syscall "); put_dec(tf[F_A7]); uart_puts("\n");
        tf[F_A0] = (uint32_t)-1;
    }
}

static const char *fault_name(uint32_t c) {
    if (c == 12) return "Instruction";
    if (c == 13) return "Load";
    return "Store";
}

/* ---- 第40章7節: 不正命令から、生きて戻る実験 ---- */
static uint32_t probe_tf[32];          /* 実験中だけ sscratch が指す退避領域 */
static volatile int probe_active;

void trap_handler(uint32_t scause, uint32_t sepc, uint32_t stval) {
    if (probe_active) {                /* この実験のときだけ：不正命令を飛ばして戻す */
        probe_active = 0;
        uart_puts("[TRAP] scause="); put_dec(scause); uart_puts(" (Illegal instruction)\n");
        uart_puts("[TRAP] sepc="); put_hex(sepc);
        uart_puts(" stval="); put_hex(stval); uart_puts("\n");
        uart_puts("-> skipped the bad instruction.\n");
        probe_tf[F_PC] = sepc + 4;     /* trap_entry の復元経路が [0] を sepc に戻す */
        return;
    }

    uint32_t *tf = current->tf;
    tf[F_PC] = sepc;

    if (scause & 0x80000000u) return;

    switch (scause) {
    case 8:
        tf[F_PC] = sepc + 4;
        handle_syscall();
        break;
    case 12: case 13: case 15:
        uart_puts("[TRAP] scause="); put_dec(scause);
        uart_puts(" ("); uart_puts(fault_name(scause)); uart_puts(" page fault)\n");
        uart_puts("[TRAP] stval="); put_hex(stval);
        uart_puts("  sepc="); put_hex(sepc); uart_puts("\n");
        uart_puts("  -> pid="); put_dec(current->pid);
        uart_puts(" tried to touch an unmapped address.\n");
        uart_puts("  -> killing pid="); put_dec(current->pid); uart_puts(".\n");
        current->state = DEAD;
        break;                       /* 切り替えは帰り道の一回だけ */
    default:
        uart_puts("[TRAP] unexpected scause="); put_dec(scause);
        uart_puts(" sepc="); put_hex(sepc); uart_puts("\n");
        for(;;);
    }
    /* yield / exit 後も含め、次の走者へ */
    schedule();
}

/* ---------------- user programs ---------------- */
extern char u_ab_start[],   u_ab_end[];
extern char u_ba_start[],   u_ba_end[];
extern char u_sigA_start[], u_sigA_end[];
extern char u_sigB_start[], u_sigB_end[];
extern char u_evil_start[], u_evil_end[];
extern char u_loop_start[], u_loop_end[];
extern char u_send_start[], u_send_end[];
extern char u_recv_start[], u_recv_end[];

/* ---------------- experiments ---------------- */
static void reset_procs(void) {
    nproc = 0; current = 0;
    for (int i = 0; i < MAX_PROCS; i++) procs[i].state = 0;
    for (int i = 0; i <= MAX_PROCS; i++) mailboxes[i].has_mail = 0;
}

static void trap_init(void) {
    extern void trap_entry(void);
    __asm__ volatile("csrw stvec, %0" :: "r"((uint32_t)trap_entry));
}

/* ---- 第40章7節: S-mode から mstatus を読む → illegal instruction → 生きて戻る ---- */
void probe_illegal(void) {
    __asm__ volatile("csrw sscratch, %0" :: "r"((uint32_t)probe_tf));
    probe_active = 1;
    uart_puts("[TRAP] handler installed.\n");
    __asm__ volatile("csrr t0, mstatus" ::: "t0");   /* 本文と同じ一命令（機械語 0x300022f3） */
    uart_puts("[TRAP] survived.\n");
    __asm__ volatile("csrw sscratch, zero");
}

void kernel_main(void) {
    next_free = heap_start;
    uart_puts("[BOOT] M-mode -> S-mode. Now in supervisor.\n");

    /* ---- 第40章7節: トラップ実験 ---- */
    trap_init();
    probe_illegal();

    kernel_map_init();

    /* ---- 第42章: MMU実験 ---- */
    uart_puts("[MMU] before: pc runs on physical address.\n");
    switch_pt(kernel_pt);
    uart_puts("[MMU] after : pc runs on VIRTUAL address.\n");

    *(volatile uint32_t *)0x80300000 = 0xDEADBEEF;
    map_page(kernel_pt, 0x20000000, 0x80300000, PTE_R | PTE_W);
    __asm__ volatile("sfence.vma zero, zero");
    uart_puts("[MMU] read from 0x20000000 -> ");
    put_hex(*(volatile uint32_t *)0x20000000); uart_puts("\n");
    *(volatile uint32_t *)0x20000000 = 0xCAFEBABE;
    uart_puts("[MMU] wrote to 0x20000000\n");
    uart_puts("[MMU] physical 0x80300000 -> ");
    put_hex(*(volatile uint32_t *)0x80300000); uart_puts("\n");

    run_stage();
    for(;;);
}

void run_stage(void) {
    switch (exp_stage) {
    case 0:
        uart_puts("\n--- EXP1: interleave ---\n");
        reset_procs();
        create_process(u_ab_start, u_ab_end - u_ab_start);
        create_process(u_ba_start, u_ba_end - u_ba_start);
        uart_puts("[PROC] entering U-mode...\n");
        schedule();
        break;
    case 1:
        uart_puts("\n--- EXP2: same VA, different place ---\n");
        reset_procs();
        create_process(u_sigA_start, u_sigA_end - u_sigA_start);
        create_process(u_sigB_start, u_sigB_end - u_sigB_start);
        schedule();
        break;
    case 2:
        uart_puts("\n--- EXP3: the summit (page fault) ---\n");
        reset_procs();
        create_process(u_evil_start, u_evil_end - u_evil_start);
        create_process(u_loop_start, u_loop_end - u_loop_start);
        uart_puts("[PROC] entering U-mode (pid=1)...\n");
        schedule();
        break;
    case 3:
        uart_puts("\n--- EXP4: IPC ---\n");
        reset_procs();
        create_process(u_send_start, u_send_end - u_send_start);
        create_process(u_recv_start, u_recv_end - u_recv_start);
        schedule();
        break;
    default:
        uart_puts("\n=== ALL EXPERIMENTS DONE ===\n");
        __asm__ volatile("csrw satp, zero");
        __asm__ volatile("sfence.vma zero, zero");
        *(volatile uint32_t*)0x100000 = 0x5555;
        for(;;);
    }
}
