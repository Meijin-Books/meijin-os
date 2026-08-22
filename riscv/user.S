/* ユーザプログラム群。仮想0x1000に写される前提（位置独立に書く） */

.section .rodata
.balign 4

/* --- 第43章5節 プロセスA: 'A'を出して譲る --- */
.globl u_ab_start, u_ab_end
u_ab_start:
    li    s0, 0
1:  addi  s0, s0, 1
    li    a0, 65            /* 'A' */
    li    a7, 1             /* SYS_PUTC */
    ecall
    li    a7, 3             /* SYS_YIELD */
    ecall
    li    t0, 8
    blt   s0, t0, 1b
    li    a7, 2             /* SYS_EXIT */
    ecall
u_ab_end:

/* --- プロセスB: 'B' --- */
.globl u_ba_start, u_ba_end
u_ba_start:
    li    s0, 0
1:  addi  s0, s0, 1
    li    a0, 66            /* 'B' */
    li    a7, 1
    ecall
    li    a7, 3
    ecall
    li    t0, 8
    blt   s0, t0, 1b
    li    a7, 2
    ecall
u_ba_end:

/* --- 第44章2節 実験その一: 自分の0x2000に署名して読み返す --- */
.globl u_sigA_start, u_sigA_end
u_sigA_start:
    li    t0, 0x2000
    li    t1, 0xAAAAAAAA
    sw    t1, 0(t0)
    li    a7, 3             /* yield */
    ecall
    li    t0, 0x2000
    lw    a0, 0(t0)
    li    a7, 6             /* SYS_PUTHEX */
    ecall
    li    a0, 10
    li    a7, 1
    ecall
    li    a7, 2
    ecall
u_sigA_end:

.globl u_sigB_start, u_sigB_end
u_sigB_start:
    li    t0, 0x2000
    li    t1, 0xBBBBBBBB
    sw    t1, 0(t0)
    li    a7, 3
    ecall
    li    a7, 2
    ecall
u_sigB_end:

/* --- 第44章3節 頂上: 地図に無い0x5000へ書く --- */
.globl u_evil_start, u_evil_end
u_evil_start:
    li    a0, 88            /* 'X' */
    li    a7, 1
    ecall
    li    a0, 10
    li    a7, 1
    ecall
    li    t0, 0x5000        /* 地図に載っていない番地 */
    li    t1, 0xDEADBEEF
    sw    t1, 0(t0)         /* ★ 越境 */
    li    a0, 89            /* 'Y' : ここへは来ない */
    li    a7, 1
    ecall
    li    a7, 2
    ecall
u_evil_end:

/* --- 相方: 生き残って動き続けることを示す --- */
.globl u_loop_start, u_loop_end
u_loop_start:
    li    s0, 0
1:  addi  s0, s0, 1
    li    a0, 66            /* 'B' */
    li    a7, 1
    ecall
    li    a7, 3
    ecall
    li    t0, 8
    blt   s0, t0, 1b
    li    a0, 10
    li    a7, 1
    ecall
    li    a7, 2
    ecall
u_loop_end:

/* --- 第45章4節 IPC --- */
.globl u_send_start, u_send_end
u_send_start:
    li    a0, 2             /* to pid 2 */
    li    a1, 0x1234
    li    a7, 4             /* SYS_SEND */
    ecall
    li    a7, 2
    ecall
u_send_end:

.globl u_recv_start, u_recv_end
u_recv_start:
    li    a7, 5             /* SYS_RECV */
    ecall
    li    a7, 6             /* SYS_PUTHEX */
    ecall
    li    a0, 10
    li    a7, 1
    ecall
    li    a7, 2
    ecall
u_recv_end:
