/* task.c -- タスクとスケジューラ（第30章・第33章6節） */
#include "os.h"

task_t  tasks[NTASK];
task_t *current_tcb;
volatile u32 g_tick;
int g_preemptive;

static u32 stacks[NTASK][STACK_WORDS] EWRAM_BSS;   /* タスクのスタックは EWRAM に */
static int slice;                                   /* タイムスライスの残り */
#define SLICE_LEN 10                                /* 10 ティック = 約 10ms */

void switch_context(task_t *old, task_t *new_);    /* switch.s */

/* ---- 番兵（第34章4節: あふれは、静かに隣を壊す） ---- */
int stack_ok(const task_t *t) { return *t->stack_bottom == STACK_GUARD; }

static task_t *alloc_slot(void)
{
    for (int i = 0; i < NTASK; i++)
        if (tasks[i].state == FINISHED && tasks[i].sp == 0) return &tasks[i];
    return 0;
}

void task_init(void)
{
    for (int i = 0; i < NTASK; i++) {
        tasks[i].state = FINISHED;
        tasks[i].sp    = 0;
        tasks[i].stack_bottom = &stacks[i][0];
        stacks[i][0] = STACK_GUARD;
    }
}

/* ---- 協調版の偽の履歴: lr の位置に入口、r4〜r11 は 0（第30章3節） ---- */
int task_create(void (*entry)(void))
{
    task_t *t = alloc_slot();
    if (!t) return -1;
    u32 *sp = t->stack_bottom + STACK_WORDS;
    *(--sp) = (u32)entry;           /* pc の位置に入口を置く */
    for (int i = 0; i < 8; i++)     /* r4〜r11 の初期値（0 でよい） */
        *(--sp) = 0;
    t->sp    = sp;
    t->state = READY;               /* 実行可能の状態にする */
    return t - tasks;
}

/* ---- プリエンプティブ版の偽の履歴: BIOS の包みと同じ並びで 16 語（第30章6節） ---- */
int task_create_p(void (*entry)(void))
{
    task_t *t = alloc_slot();
    if (!t) return -1;
    u32 *sp = t->stack_bottom + STACK_WORDS;
    *(--sp) = 0;                    /* lr（使わない） */
    for (int i = 0; i < 8; i++)     /* r11〜r4 */
        *(--sp) = 0;
    *(--sp) = (u32)entry + 4;       /* PC+4（BIOS が 4 引く） */
    for (int i = 0; i < 5; i++)     /* r12, r3〜r0 */
        *(--sp) = 0;
    *(--sp) = 0x1F;                 /* CPSR: System モード、IRQ 許可 */
    t->sp    = sp;
    t->state = READY;
    return t - tasks;
}

/* ---- 次を選ぶ（第33章6節: 三つの状態と、何もしないタスク） ----
   眠っているタスクは時刻が来たら起こし、READY だけを巡回で選ぶ。
   誰もいなければタスク 0（アイドル）へ。 */
task_t *schedule_pick_next(void)
{
    int cur = current_tcb - tasks;
    for (int i = 0; i < NTASK; i++)
        if (tasks[i].state == WAITING && (int)(g_tick - tasks[i].wake_tick) >= 0)
            tasks[i].state = READY;
    for (int k = 1; k <= NTASK; k++) {
        int i = (cur + k) % NTASK;
        if (tasks[i].state == READY) return &tasks[i];
    }
    return &tasks[0];               /* アイドルタスク（常に READY）*/
}

/* ---- 協調版: 自分から譲る（第30章4節） ---- */
void yield(void)
{
    unsigned s = irq_disable();
    task_t *prev = current_tcb;
    task_t *next = schedule_pick_next();
    if (next != prev) {
        current_tcb = next;
        switch_context(prev, next);
    }
    irq_restore(s);
}

/* ---- タイマ割り込みから呼ばれる（第30章5節）。切り替えるなら 1 を返す ---- */
int on_tick(void)
{
    g_tick++;
    if (++slice >= SLICE_LEN) { slice = 0; return 1; }
    return 0;
}

/* ---- 待機（第33章）: 協調版は譲り、プリエンプティブ版は次のティックで取り上げられるのを待つ ----
   注意: ここで BIOS の Halt（swi）を呼んではいけない。BIOS の swi 処理は SVC スタックに
   r11/r12/lr を積んだまま System モードへ降りて走るので、その最中に別のタスクへ切り替わり、
   そのタスクも swi を呼ぶと、共有の SVC スタックが壊れる（第32章4節「玄関は借り物」の代償）。
   本書の実装では、swi 0x02 (Halt) を呼ぶのはアイドルタスク（タスク 0）だけとする。 */
static void wait_until_ready(void)
{
    while (current_tcb->state != READY) {
        if (g_preemptive) slice = SLICE_LEN;   /* 次のティックで必ず取り上げてもらう */
        else              yield();
    }
}

void block_current(u32 *waiters)
{
    int id = current_tcb - tasks;
    *waiters |= 1u << id;
    current_tcb->state = BLOCKED;
    unsigned s = irq_disable();
    irq_restore(s & ~0x80u);        /* 待つあいだは割り込みを開けておく */
    wait_until_ready();
    irq_restore(s);
}

void wake_one(u32 *waiters)
{
    for (int i = 0; i < NTASK; i++)
        if (*waiters & (1u << i)) {
            *waiters &= ~(1u << i);
            tasks[i].state = READY;
            return;
        }
}

/* ---- 窓口（第32章4節）: 他の三機種の trap / rst / ecall に相当する ---- */
void svc_yield(void)
{
    if (g_preemptive) {             /* 次のティックで取り上げられる（Halt は使わない。上の注意） */
        task_t *me = current_tcb;
        slice = SLICE_LEN;
        while (current_tcb == me && schedule_pick_next() != me) { }
    } else {
        yield();
    }
}

void svc_sleep(u32 ticks)
{
    current_tcb->wake_tick = g_tick + ticks;
    current_tcb->state = WAITING;
    wait_until_ready();
}

void svc_putc(char c)  { console_putc(c); }
u16  svc_getkey(void)  { return input_getkey(); }

void svc_exit(void)
{
    current_tcb->state = FINISHED;  /* 殺すとは、状態を一つ書くこと */
    for (;;) svc_yield();           /* 二度と選ばれない */
}
