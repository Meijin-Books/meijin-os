@ crt0.s -- 電源投入から main まで（第28章4節・付録H-1）
@   四つの仕事: ヘッダを飛び越す / 二本のスタックを立てる / .data を写す / .bss を消す
    .section .crt0, "ax"
    .arm
    .global _start
_start:
    b     _boot            @ 先頭はヘッダを飛び越えて本体へ
    @ ここに192バイトのヘッダが入る（gbafix が埋める）
    .space 188             @ ヘッダの残り188バイト分を確保

_boot:
    msr   cpsr_c, #0xD2    @ IRQ モードへ（割り込み禁止）
    ldr   sp, =__sp_irq    @ IRQ 用スタックを設定
    msr   cpsr_c, #0xDF    @ System モードへ（禁止のまま）
    ldr   sp, =__sp_usr    @ 本編用スタックを設定

    ldr   r0, =__data_lma  @ .data を ROM から IWRAM へ写す
    ldr   r1, =__data_start
    ldr   r2, =__data_end
1:  cmp   r1, r2
    ldrlo r3, [r0], #4     @ r1 < r2 のあいだだけ実行
    strlo r3, [r1], #4
    blo   1b

    ldr   r1, =__bss_start @ .bss を 0 で埋める
    ldr   r2, =__bss_end
    mov   r3, #0
2:  cmp   r1, r2
    strlo r3, [r1], #4
    blo   2b

    ldr   r0, =main        @ C 言語の main へ
    bx    r0
