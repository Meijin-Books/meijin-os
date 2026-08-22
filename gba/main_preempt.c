/* main_preempt.c -- プリエンプティブ（第30章5〜6節: 外から順番を取り上げる）
   どちらのタスクも譲らない。それでも両方が進む。数は揃わない（第20章7節の 48A1 対 3FBA と同じ） */
#include "os.h"

void kprintf_init(void);
static u32 cntA, cntB;

static void task_a(void)              /* 譲らない住人 */
{
    for (;;) {
        cntA++;
        console_hex_at(2, 2, "A = ", cntA);
    }
}

static void task_b(void)              /* こちらも譲らない */
{
    for (;;) {
        cntB++;
        console_hex_at(4, 2, "B = ", cntB);
    }
}

static void task_clock(void)          /* 眠りは OS にしか作れない（svc_sleep） */
{
    for (u32 sec = 0;; sec++) {
        console_hex_at(6, 2, "tick = ", g_tick);
        kprintf("preempt: sec=%d A=%x B=%x\n", sec, cntA, cntB);
        svc_sleep(1000);              /* 1000 ティック = 約 1 秒 */
    }
}

int main(void)
{
    console_init();
    kprintf_init();
    console_puts("MeijinOS/ARM v0.2 (preempt)\n");
    task_init();
    tasks[0].state = READY;           /* タスク 0 = アイドル。main 自身がそれになる */
    task_create_p(task_a);
    task_create_p(task_b);
    task_create_p(task_clock);
    current_tcb = &tasks[0];
    irq_init(1);                      /* プリエンプティブ版のハンドラを登録 */

    /* ここから先、main はアイドルタスク（タスク 0）として生きる。
       次のティックで取り上げられ、誰も走れないときだけここへ戻ってくる */
    for (;;) svc_halt();              /* 次の割り込みまで休む */
}
