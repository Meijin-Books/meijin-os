/* irq.c -- 割り込みとシステムティック（第29章） */
#include "os.h"

int on_tick(void);

/* 臨界区間を守る ― 元の状態を控えて戻す（第30章5節） */
unsigned irq_disable(void)
{
    unsigned cpsr;
    __asm__ volatile("mrs %0, cpsr" : "=r"(cpsr));
    __asm__ volatile("msr cpsr_c, %0" :: "r"(cpsr | 0x80));
    return cpsr;                    /* 元の状態を返す */
}
void irq_restore(unsigned cpsr)
{
    __asm__ volatile("msr cpsr_c, %0" :: "r"(cpsr));
}

/* 協調版のディスパッチャ（第29章3節）。BIOS が IRQ モード・割り込み禁止で呼ぶ。
   0x03007FFC から飛んでくるので、ARM 状態でなければならない。 */
IWRAM_ARM void irq_handler(void)
{
    u16 flags = REG_IE & REG_IF;    /* 許可済みかつ発生 */

    if (flags & IRQ_VBLANK) input_poll();
    if (flags & IRQ_TIMER0) on_tick();

    REG_IF      = flags;            /* IF へ書き戻して確認済みにする */
    REG_IFBIOS |= flags;            /* BIOS の待機用フラグも更新する */
}

/* 設定には順序がある（第29章4節） */
void irq_init(int preemptive)
{
    g_preemptive = preemptive;
    REG_IME = 0;                               /* まず全体を止める */
    REG_DISPSTAT |= 0x0008;                    /* VBlank 割り込みを有効にする */
    REG_TM0CNT_L = 0x10000 - 262;              /* 約 1ms でオーバーフロー（第29章5節） */
    REG_TM0CNT_H = 0x00C1;                     /* 動作 + 割り込み + 64 分周 */
    REG_IE = IRQ_VBLANK | IRQ_TIMER0;
    IRQ_VECTOR = preemptive ? irq_handler_preempt : irq_handler;
    REG_IME = 1;                               /* 最後に、全体の割り込みを許可する */

    /* crt0 は I ビットを立てたまま main へ来る。CPSR 側の元栓も開ける（第27章5節） */
    unsigned cpsr;
    __asm__ volatile("mrs %0, cpsr" : "=r"(cpsr));
    __asm__ volatile("msr cpsr_c, %0" :: "r"(cpsr & ~0x80u));
}
