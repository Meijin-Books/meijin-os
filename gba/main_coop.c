/* main_coop.c -- 協調的マルチタスク（第30章4節: 譲り合いで回す）
   二つのタスクが、それぞれ数えては yield で譲る。画面に二つのカウンタが並ぶ。 */
#include "os.h"

void kprintf_init(void);
static u32 cntA, cntB;

static void idle_task(void)           /* 選ぶ相手がいない、という事態をなくすためだけに居る */
{
    for (;;) yield();
}

static void task_a(void)
{
    for (;;) {
        cntA++;
        console_hex_at(2, 2, "A = ", cntA);
        yield();                      /* 自分から譲る */
    }
}

static void task_b(void)
{
    for (;;) {
        cntB++;
        console_hex_at(4, 2, "B = ", cntB);
        yield();
    }
}

int main(void)
{
    console_init();
    kprintf_init();
    console_puts("MeijinOS/ARM v0.1 (coop)\n");
    task_init();
    task_create(idle_task);           /* タスク 0 = アイドル */
    task_create(task_a);
    task_create(task_b);
    irq_init(0);                      /* 協調版: ティックは刻むが、取り上げない */
    kprintf("coop: start\n");

    current_tcb = &tasks[0];
    task_t dummy;                     /* main の世界は捨てる。最初のタスクへ */
    extern void switch_context(task_t *, task_t *);
    switch_context(&dummy, &tasks[0]);
    for (;;) { }
}
