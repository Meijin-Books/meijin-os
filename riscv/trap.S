/* トラップの入口。
   sscratch = 現在プロセスの trap frame の番地。
   frame layout: [0]=PC, [1..31] = x1..x31  (計32 word) */

.section .text
.align 4
.globl trap_entry
trap_entry:
    csrrw t0, sscratch, t0      /* t0 = frame addr, sscratch = 元のt0 */

    sw    ra,  1*4(t0)
    sw    sp,  2*4(t0)
    sw    gp,  3*4(t0)
    sw    tp,  4*4(t0)
    /* t0(x5) は後で */
    sw    t1,  6*4(t0)
    sw    t2,  7*4(t0)
    sw    s0,  8*4(t0)
    sw    s1,  9*4(t0)
    sw    a0, 10*4(t0)
    sw    a1, 11*4(t0)
    sw    a2, 12*4(t0)
    sw    a3, 13*4(t0)
    sw    a4, 14*4(t0)
    sw    a5, 15*4(t0)
    sw    a6, 16*4(t0)
    sw    a7, 17*4(t0)
    sw    s2, 18*4(t0)
    sw    s3, 19*4(t0)
    sw    s4, 20*4(t0)
    sw    s5, 21*4(t0)
    sw    s6, 22*4(t0)
    sw    s7, 23*4(t0)
    sw    s8, 24*4(t0)
    sw    s9, 25*4(t0)
    sw    s10,26*4(t0)
    sw    s11,27*4(t0)
    sw    t3, 28*4(t0)
    sw    t4, 29*4(t0)
    sw    t5, 30*4(t0)
    sw    t6, 31*4(t0)

    /* 元のt0を回収して保存。sscratchはframe addrに戻す */
    csrrw t1, sscratch, t0
    sw    t1,  5*4(t0)

    /* PC (sepc) を frame[0] へ */
    csrr  t1, sepc
    sw    t1,  0*4(t0)

    /* カーネルスタックへ乗り換え */
    la    sp, kernel_stack_top

    csrr  a0, scause
    csrr  a1, sepc
    csrr  a2, stval
    jal   ra, trap_handler

    /* 復元。sscratch は current の frame を指している（scheduleで差し替わる場合あり） */
    csrr  t0, sscratch

    lw    t1,  0*4(t0)
    csrw  sepc, t1

    lw    ra,  1*4(t0)
    lw    sp,  2*4(t0)
    lw    gp,  3*4(t0)
    lw    tp,  4*4(t0)
    lw    t1,  6*4(t0)
    lw    t2,  7*4(t0)
    lw    s0,  8*4(t0)
    lw    s1,  9*4(t0)
    lw    a0, 10*4(t0)
    lw    a1, 11*4(t0)
    lw    a2, 12*4(t0)
    lw    a3, 13*4(t0)
    lw    a4, 14*4(t0)
    lw    a5, 15*4(t0)
    lw    a6, 16*4(t0)
    lw    a7, 17*4(t0)
    lw    s2, 18*4(t0)
    lw    s3, 19*4(t0)
    lw    s4, 20*4(t0)
    lw    s5, 21*4(t0)
    lw    s6, 22*4(t0)
    lw    s7, 23*4(t0)
    lw    s8, 24*4(t0)
    lw    s9, 25*4(t0)
    lw    s10,26*4(t0)
    lw    s11,27*4(t0)
    lw    t3, 28*4(t0)
    lw    t4, 29*4(t0)
    lw    t5, 30*4(t0)
    lw    t6, 31*4(t0)

    lw    t0,  5*4(t0)          /* t0 は最後 */

    sret
