@ switch.s -- コンテキストスイッチ（第30章2節・6節、付録H-2）
@   協調版 switch_context / プリエンプティブ版 irq_handler_preempt / BIOS の Halt
    .arm
    .text

@ ---- 協調版 ― これだけです（第30章2節） ----
    .global switch_context
switch_context:                @ r0 = old TCB, r1 = new TCB
    stmfd sp!, {r4-r11, lr}    @ 保つべきレジスタと LR を退避
    str   sp, [r0]             @ 現在の SP を old->sp へ保存
    ldr   sp, [r1]             @ new の SP を取り出す
    ldmfd sp!, {r4-r11, pc}    @ レジスタを戻し new を再開

@ ---- プリエンプティブ版 ― BIOS 経由・IRQ モードで呼ばれる（第30章6節） ----
    .global irq_handler_preempt
irq_handler_preempt:
    ldr   r0, =0x04000200     @ IE/IF の番地
    ldrh  r1, [r0]            @ IE（許可されている要因）
    ldrh  r2, [r0, #2]        @ IF（起きている要因）
    and   r1, r1, r2          @ 起きていて、許可されている割り込み
    strh  r1, [r0, #2]        @ IF へ書き戻して確認応答
    ldr   r2, =0x03007FF8     @ BIOS の待機フラグにも合成
    ldrh  r3, [r2]
    orr   r3, r3, r1
    strh  r3, [r2]

    tst   r1, #0x0001         @ VBlank なら、入力を読んでおく（第35章4節）
    beq   1f
    stmfd sp!, {r1, lr}
    ldr   r3, =input_poll
    mov   lr, pc
    bx    r3
    ldmfd sp!, {r1, lr}
1:
    tst   r1, #0x0008         @ タイマ0（ティック）か?
    bxeq  lr                  @ 違えば BIOS へ帰る
    stmfd sp!, {r1, lr}
    ldr   r3, =on_tick        @ ティックを進め、スライスを数える（r0 = 切り替えるか）
    mov   lr, pc
    bx    r3
    ldmfd sp!, {r1, lr}
    cmp   r0, #0
    bxeq  lr                  @ スライスがまだ残っていれば BIOS へ帰る

    mrs   r1, spsr            @ 中断されたタスクの CPSR
    and   r2, r1, #0x1F
    cmp   r2, #0x13           @ BIOS の swi（Halt など）の最中に割り込まれたか?
    bxeq  lr                  @ Supervisor モードの途中では切り替えない（SVC スタックと lr_svc は
                              @ 全タスク共有。ここで切り替えると別のタスクが他人の r11/lr を pop する）
    @ --- ここからタスク切り替え ---
    mov   r0, sp              @ BIOS の包み（r0-r3, r12, PC+4）の先頭
    msr   cpsr_c, #0x9F       @ System モードへ（IRQ は禁止のまま）
    stmfd sp!, {r4-r11, lr}   @ 守るべき世界を、タスクのスタックへ
    ldmia r0, {r2-r7}         @ BIOS の包みを回収し
    stmfd sp!, {r1-r7}        @ CPSR と共にタスクのスタックへ積む
    ldr   r0, =current_tcb
    ldr   r1, [r0]
    str   sp, [r1]            @ TCB に SP を封印
    bl    schedule_pick_next  @ 次の TCB を選ぶ（r0 に返る）
    ldr   r1, =current_tcb
    str   r0, [r1]
    ldr   sp, [r0]            @ 次のタスクの SP に差し替え
    ldmfd sp!, {r1-r7}        @ 次のタスクの CPSR と包みを取り出す
    msr   cpsr_c, #0x92       @ いったん IRQ モードへ
    stmia sp, {r2-r7}         @ 包みを次のタスクの値で詰め直す
    msr   spsr_cxsf, r1       @ 次のタスクの CPSR を SPSR へ
    msr   cpsr_c, #0x9F       @ ふたたび System モードへ
    ldmfd sp!, {r4-r11, lr}   @ 次のタスクの世界を開封
    msr   cpsr_c, #0x92       @ IRQ モードへ戻る
    bx    lr                  @ BIOS へ。BIOS が包みを開いて復帰

@ ---- BIOS の Halt（swi 0x02）。ARM 状態では番号を bit23-16 に置く ----
    .global svc_halt
svc_halt:
    swi   0x020000
    bx    lr

@ ---- User モードへ降りる（第31章3節）。以降は弱い権限で走る ----
    .global drop_to_user
drop_to_user:
    msr   cpsr_c, #0x10       @ User モード（割り込みは許可のまま）
    bx    lr
