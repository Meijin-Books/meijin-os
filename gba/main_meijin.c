/* main_meijin.c -- MeijinOS/ARM v1.0（第35章6節: シェルというタスクと、アプリの起動）
   シェル（タスク 1）が入力を待ち、コマンドでアプリを起動する。
   十字キー上下で候補を選び、A ボタンで確定。B ボタンで最後に起動したアプリを殺す。
   すべてのアプリは svc_* の窓口だけを通してカーネルに頼る。 */
#include "os.h"

void kprintf_init(void);

/* ---- アプリ（二階の住人） ---- */
static void clock_app(void)           /* 時計: 1 秒に 1 つ進む */
{
    for (u32 sec = 0;; sec++) {
        console_hex_at(12, 2, "clock: ", sec);
        svc_sleep(1000);
    }
}

static void draw_app(void)            /* お絵かき: 模様を回し続ける（譲らない住人） */
{
    static const char pat[] = "|/-\\";
    char line[24];
    for (u32 i = 0;; i++) {
        for (int k = 0; k < 16; k++) line[k] = pat[(i + k) & 3];
        line[16] = 0;
        console_print_at(14, 2, "draw : "); console_print_at(14, 9, line);
        svc_sleep(100);
    }
}

static void count_app(void)           /* 五つ数えて、自分で終わる（svc_exit） */
{
    for (u32 i = 1; i <= 5; i++) {
        console_hex_at(16, 2, "count: ", i);
        svc_sleep(500);
    }
    console_print_at(16, 2, "count: done ");
    svc_exit();
}

/* ---- シェル ---- */
typedef struct { const char *name; void (*entry)(void); } cmd_t;
static const cmd_t cmds[] = {
    { "clock", clock_app }, { "draw", draw_app }, { "count", count_app },
};
#define NCMD ((int)(sizeof cmds / sizeof cmds[0]))
static int last_app = -1;

static void show_menu(int sel)
{
    unsigned f = irq_disable();       /* 画面の更新中は、取り上げられたくない */
    for (int i = 0; i < NCMD; i++) {
        console_goto(3 + i, 2);
        console_puts(i == sel ? "> " : "  ");
        console_puts(cmds[i].name);
    }
    console_goto(8, 2); console_puts("tasks: ");
    for (int i = 0; i < NTASK; i++)
        console_putc("RWBF"[tasks[i].state]);   /* R=READY W=WAITING B=BLOCKED F=FINISHED */
    irq_restore(f);
}

static void shell_task(void)
{
    int sel = 0;
    console_print_at(1, 0, "UP/DN:select A:run B:kill");
    for (;;) {
        show_menu(sel);
        u16 k;
        while ((k = svc_getkey()) == 0) svc_sleep(16);   /* 1 フレームほど眠って、また聞く */
        if (k & KEY_UP)   sel = (sel + NCMD - 1) % NCMD;
        if (k & KEY_DOWN) sel = (sel + 1) % NCMD;
        if (k & KEY_A) {
            int id = task_create_p(cmds[sel].entry);       /* spawn_app */
            kprintf("shell: spawn %s -> task %d\n", cmds[sel].name, id);
            if (id >= 0) last_app = id;
            else { console_print_at(10, 2, "no free task slot"); }
        }
        if ((k & KEY_B) && last_app > 1) {                   /* 殺すとは、状態を一つ書くこと */
            tasks[last_app].state = FINISHED;
            tasks[last_app].sp    = 0;                       /* 区画を返す */
            kprintf("shell: killed task %d\n", last_app);
            last_app = -1;
        }
        for (int i = 0; i < NTASK; i++)                      /* 番兵の見回り（第36章3節） */
            if (tasks[i].state != FINISHED && !stack_ok(&tasks[i]))
                kprintf("PANIC: stack overflow in task %d\n", i);
    }
}

int main(void)
{
    console_init();
    kprintf_init();
    console_puts("MeijinOS/ARM v1.0\n");
    task_init();
    tasks[0].state = READY;           /* タスク 0 = アイドル（main 自身） */
    task_create_p(shell_task);        /* タスク 1 = シェル */
    current_tcb = &tasks[0];
    irq_init(1);
    kprintf("MeijinOS/ARM v1.0 boot\n");
    for (;;) svc_halt();
}
