.section .text.init
.globl _start
_start:
    csrr  t0, mhartid
    bnez  t0, park

    la    sp, stack_top

    /* BSS clear */
    la    t0, bss_start
    la    t1, bss_end
1:  bgeu  t0, t1, 2f
    sw    zero, 0(t0)
    addi  t0, t0, 4
    j     1b
2:
    /* mstatus.MPP = S (01) */
    li    t0, (3 << 11)
    csrc  mstatus, t0
    li    t0, (1 << 11)
    csrs  mstatus, t0

    la    t0, kernel_main
    csrw  mepc, t0

    /* PMP: allow S-mode all physical memory (TOR, top = 0xffffffff) */
    li    t0, 0x3fffffff        /* pmpaddr is addr>>2 : covers full 32bit space */
    csrw  pmpaddr0, t0
    li    t0, 0x0f              /* A=TOR(01)<<3 | X|W|R */
    csrw  pmpcfg0, t0

    /* delegate traps to S-mode */
    li    t0, 0xffff
    csrw  medeleg, t0
    csrw  mideleg, t0

    csrw  satp, zero

    mret

park:
    wfi
    j     park
