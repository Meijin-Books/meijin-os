/* os.h -- MeijinOS/ARM の内部インタフェース（第30〜35章） */
#ifndef OS_H
#define OS_H
#include "gba.h"

/* ---- タスク（第30章1節: 台帳は、できるだけ薄く） ---- */
enum { READY = 0, WAITING, BLOCKED, FINISHED };

typedef struct task {
    u32 *sp;            /* このタスクのスタックの先頭（封印された世界） */
    volatile int state; /* READY / WAITING / BLOCKED / FINISHED（割り込みの中から書き換わる。第33章6節） */
    u32  wake_tick;     /* WAITING のとき、起きる時刻 */
    u32 *stack_bottom;  /* 番兵の置き場所（第34章4節） */
} task_t;

#define NTASK       6
#define STACK_WORDS 512               /* 1 タスク 2KB */
#define STACK_GUARD 0xDEADC0DE

extern task_t  tasks[NTASK];
extern task_t *current_tcb;
extern volatile u32 g_tick;           /* システムティック（第29章6節） */

void task_init(void);
int  task_create(void (*entry)(void));     /* 協調版の偽の履歴（9 語） */
int  task_create_p(void (*entry)(void));   /* プリエンプティブ版の偽の履歴（16 語） */
task_t *schedule_pick_next(void);          /* 次の TCB を選ぶ（irq_handler_preempt からも呼ばれる） */
void yield(void);                          /* 協調版: 自分から譲る */
int  stack_ok(const task_t *t);

/* ---- 割り込み（第29章） ---- */
void irq_init(int preemptive);     /* IME/IE/IF・VBlank・タイマ0 を順序どおりに設定 */
void irq_handler(void);            /* 協調版: C のディスパッチャ（IWRAM / ARM） */
void irq_handler_preempt(void);    /* プリエンプティブ版: アセンブリ（switch.s） */
extern int g_preemptive;
unsigned irq_disable(void);
void     irq_restore(unsigned cpsr);

/* ---- 窓口（第32章4節: GBA だけ、窓口が関数呼び出し） ---- */
void svc_yield(void);
void svc_sleep(u32 ticks);
void svc_putc(char c);
u16  svc_getkey(void);
void svc_exit(void);
void svc_halt(void);               /* BIOS の swi 0x02（switch.s） */

/* ---- 同期（第33章） ---- */
typedef struct { int locked; u32 waiters; } mutex_t;
typedef struct { int count;  u32 waiters; } sem_t;
void mutex_lock(mutex_t *m);
void mutex_unlock(mutex_t *m);
void sem_wait(sem_t *s);
void sem_post(sem_t *s);
void block_current(u32 *waiters);
void wake_one(u32 *waiters);

/* ---- デバイス（第35章） ---- */
void console_init(void);
void console_putc(char ch);
void console_puts(const char *s);
void console_puthex(u32 v);
void console_goto(int r, int c);
void console_print_at(int r, int c, const char *s);
void console_hex_at(int r, int c, const char *label, u32 v);
void input_poll(void);             /* VBlank ごとに呼ぶ。エッジをキューへ */
u16  input_getkey(void);           /* 押した瞬間を一つ取り出す（無ければ 0） */

/* ---- メモリ（第34章） ---- */
void *bump_alloc(unsigned size);

/* ---- デバッグ（第36章） ---- */
void kprintf(const char *fmt, ...);

#endif
