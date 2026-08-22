; =============================================
; meijin10.asm ── MeijinOS v1.0
; システムコール・タスクバー・メールボックス・kill
; タスク0: 時計 / タスク1: ボタンカウンタ / タスク2: ゾンビ
; =============================================
INCLUDE "hardware.inc"

; --- システムコールの玄関(rstベクタ群) ---
SECTION "RST10", ROM0[$10]      ; Yield: CPUを譲る
    di
    jp SwitchBody
SECTION "RST18", ROM0[$18]      ; Show: A=値 C=表示スロット(0-3)
    jp SysShow
SECTION "RST20", ROM0[$20]      ; Sleep: A=眠るフレーム数
    di
    jp SysSleep
SECTION "RST28", ROM0[$28]      ; Exit: 自分を終了する
    di
    jp SysExit
SECTION "RST30", ROM0[$30]      ; GetInput: A=押された瞬間のボタン
    jp SysGetInput

SECTION "VBlankVector", ROM0[$0040]
    jp VBlankHandler
SECTION "TimerVector", ROM0[$0050]
    jp TimerHandler

SECTION "Header", ROM0[$100]
    jp EntryPoint
    ds $150 - @, 0

SECTION "MainCode", ROM0
; =============================================
; コンテキストスイッチ(v0.2と同じ心臓、タスク3つ対応)
; =============================================
TimerHandler:
    ; (割り込みなのでIMEは自動でオフ)
SwitchBody:
    push af
    push bc
    push de
    push hl
    ld [wSPSave], sp
    ; 保存先 = wTasks + cur*8
    ld a, [wCurTask]
    add a
    add a
    add a
    ld c, a
    ld b, 0
    ld hl, wTasks
    add hl, bc
    ld a, [wSPSave]
    ld [hli], a
    ld a, [wSPSave + 1]
    ld [hl], a
    ; --- 次の「生きていて、起きている」タスクを選ぶ ---
    ld d, 3                  ; 最大3人まで順に当たる
.pick:
    ld a, [wCurTask]
    inc a
    cp 3
    jr c, .ok
    xor a
.ok:
    ld [wCurTask], a
    ; entry = wTasks + a*8
    add a
    add a
    add a
    ld c, a
    ld b, 0
    ld hl, wTasks
    add hl, bc
    inc hl
    inc hl                   ; +2 = alive
    ld a, [hli]              ; alive?
    or a
    jr z, .next
    ; wake(+3,+4) <= tick ?
    ld a, [wTick]
    sub [hl]                 ; tickLo - wakeLo
    inc hl
    ld a, [wTick + 1]
    sbc [hl]                 ; tickHi - wakeHi (キャリー連鎖)
    jr nc, .found            ; tick >= wake なら起きている
.next:
    dec d
    jr nz, .pick
    ; 誰も起きていない(本構成では起きない設計だが保険)
    jr .pick
.found:
    ; 選ばれたタスクのSPを取り出す
    ld a, [wCurTask]
    add a
    add a
    add a
    ld c, a
    ld b, 0
    ld hl, wTasks
    add hl, bc
    ld a, [hli]
    ld h, [hl]
    ld l, a
    ld sp, hl
    pop hl
    pop de
    pop bc
    pop af
    reti

; =============================================
; システムコールの中身
; =============================================
SysShow:                     ; A=値, C=スロット(0-3)
    push hl
    push bc
    ld b, 0
    ld hl, wShow
    add hl, bc
    ld [hl], a
    pop bc
    pop hl
    ret

SysSleep:                    ; A=フレーム数 (diで入ってくる)
    push bc
    ld b, a
    ; wake = tick + A (adcの桁上がり連鎖)
    ld a, [wTick]
    add b
    ld c, a                  ; wakeLo
    ld a, [wTick + 1]
    adc 0
    ld b, a                  ; wakeHi
    ; 自分のentry+3,+4へ書く
    ld a, [wCurTask]
    add a
    add a
    add a
    push hl
    ld l, a
    ld h, 0
    push de
    ld de, wTasks + 3
    add hl, de
    pop de
    ld [hl], c
    inc hl
    ld [hl], b
    pop hl
    pop bc
    jp SwitchBody            ; 眠りにつく＝CPUを譲る

SysExit:                     ; 自分を殺す (diで入ってくる)
    push hl
    ld a, [wCurTask]
    add a
    add a
    add a
    add 2                    ; +2 = aliveフラグ
    ld l, a
    ld h, 0
    push de
    ld de, wTasks
    add hl, de
    pop de
    ld [hl], 0               ; alive = 0
    pop hl
    jp SwitchBody            ; 二度と選ばれない

SysGetInput:                 ; A=押下エッジ(読むと消える)
    di
    ld a, [wInputEdge]
    push af
    xor a
    ld [wInputEdge], a
    pop af
    ei
    ret

; =============================================
; VBlank: OSの定例業務(時刻・入力・画面・ホットキー)
; =============================================
VBlankHandler:
    push af
    push bc
    push de
    push hl
    ; --- tick(16ビット)を進める ---
    ld hl, wTick
    inc [hl]
    jr nz, .tickdone
    inc hl
    inc [hl]
.tickdone:
    ; --- 入力を読む(アクションボタン側) ---
    ld a, %00010000          ; ビット5=0でA/B/Select/Startを選択
    ld [$FF00], a
    nop
    nop
    ld a, [$FF00]
    cpl                      ; 押下=1に反転
    and $0F                  ; 0:A 1:B 2:Select 3:Start
    ld b, a                  ; B = いま押されている
    ld a, [wPrevPad]
    cpl
    and b                    ; エッジ = 今回∧¬前回
    ld c, a
    ld a, [wInputEdge]
    or c                     ; メールボックスへ積む
    ld [wInputEdge], a
    ld a, b
    ld [wPrevPad], a
    ; --- ホットキー: SELECT+START同時押し → タスク2をkill ---
    ld a, b
    and %00001100
    cp %00001100
    jr nz, .nokill
    ld a, 0
    ld [wTasks + 2*8 + 2], a ; タスク2のalive=0
.nokill:
    ; --- 表示スロット4つをBGへ(16進2桁ずつ) ---
    ld a, [wShow + 0]
    ld hl, $9800 + 2*32 + 2
    call DrawHexByte
    ld a, [wShow + 1]
    ld hl, $9800 + 4*32 + 2
    call DrawHexByte
    ld a, [wShow + 2]
    ld hl, $9800 + 6*32 + 2
    call DrawHexByte
    ; --- タスクバー(Window)更新: tick4桁 + 生存数 ---
    ld a, [wTick + 1]
    ld hl, $9C00 + 1
    call DrawHexByte
    ld a, [wTick]
    call DrawHexByte         ; HLは続き(+2)を指している
    ; 生存数 = alive合計
    ld a, [wTasks + 0*8 + 2]
    ld b, a
    ld a, [wTasks + 1*8 + 2]
    add b
    ld b, a
    ld a, [wTasks + 2*8 + 2]
    add b                    ; A = 0〜3
    ld [$9C00 + 8], a        ; そのままタイル番号0〜3
    pop hl
    pop de
    pop bc
    pop af
    reti

DrawHexByte:                 ; AをHL位置に16進2桁で描く(HLは+2進む)
    push af
    swap a
    and $0F
    ld [hli], a
    pop af
    and $0F
    ld [hli], a
    ret

; =============================================
; 起動
; =============================================
EntryPoint:
    ld sp, $D180             ; タスク0(時計)のスタック
    ld a, 0
    ld [rNR52], a
.wait:
    ld a, [rLY]
    cp 144
    jp c, .wait
    ld a, 0
    ld [rLCDC], a
    ; タイル転送
    ld de, HexTiles
    ld hl, $9000
    ld bc, HexTilesEnd - HexTiles
.copy:
    ld a, [de]
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or c
    jp nz, .copy
    ; BGマップとWindowマップを空白で埋める
    ld hl, $9800
    ld bc, 32 * 32 * 2       ; $9800〜$9FFF(BG+Window両方)
.clear:
    ld a, 16
    ld [hli], a
    dec bc
    ld a, b
    or c
    jp nz, .clear
    ; OS変数の初期化
    xor a
    ld [wTick], a
    ld [wTick + 1], a
    ld [wInputEdge], a
    ld [wPrevPad], a
    ld [wShow], a
    ld [wShow + 1], a
    ld [wShow + 2], a
    ld [wShow + 3], a
    ld [wCurTask], a
    ; タスク表: 全員alive=1, wake=0
    ld hl, wTasks
    ld b, 24
.cleartbl:
    ld [hl], 0
    inc hl
    dec b
    jr nz, .cleartbl
    ld a, 1
    ld [wTasks + 0*8 + 2], a
    ld [wTasks + 1*8 + 2], a
    ld [wTasks + 2*8 + 2], a
    ; タスク1・2の偽の履歴を偽造
    ld hl, $D200 - 10
    ld a, l
    ld [wTasks + 1*8 + 0], a
    ld a, h
    ld [wTasks + 1*8 + 1], a
    ld hl, $D200 - 2
    ld a, LOW(TaskCounter)
    ld [hli], a
    ld a, HIGH(TaskCounter)
    ld [hl], a
    ld hl, $D280 - 10
    ld a, l
    ld [wTasks + 2*8 + 0], a
    ld a, h
    ld [wTasks + 2*8 + 1], a
    ld hl, $D280 - 2
    ld a, LOW(TaskZombie)
    ld [hli], a
    ld a, HIGH(TaskZombie)
    ld [hl], a
    ; タスクバーの位置(画面最下行)
    ld a, 136
    ld [rWY], a
    ld a, 7
    ld [rWX], a
    ; パレットとLCD(BG+Window有効、Windowマップは$9C00)
    ld a, %11100100
    ld [rBGP], a
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_WINON | LCDCF_WIN9C00
    ld [rLCDC], a
    ; タイマー始動と割り込み許可
    ld a, 0
    ld [rTMA], a
    ld a, %00000100
    ld [rTAC], a
    xor a
    ld [rIF], a
    ld a, %00000101          ; VBlank + Timer
    ld [rIE], a
    ei
    jp TaskClock             ; そのままタスク0になる

; =============================================
; アプリたち(システムコールしか使わない)
; =============================================
TaskClock:                   ; 1秒に1回、秒カウンタを表示
    ld e, 0
.loop:
    inc e
    ld a, e
    ld c, 0
    rst $18                  ; Show(値=A, スロット=C)
    ld a, 60
    rst $20                  ; Sleep(60フレーム)
    jr .loop

TaskCounter:                 ; Aボタンを押した回数を表示
    ld d, 0
.loop:
    rst $30                  ; GetInput
    bit 0, a                 ; Aボタンのエッジ?
    jr z, .show
    inc d
.show:
    ld a, d
    ld c, 1
    rst $18
    rst $10                  ; 礼儀正しく譲る
    jr .loop

TaskZombie:                  ; 行儀の悪い住人(第13章のあいつ)
    ld a, [wZom]
    inc a
    ld [wZom], a
    ld c, 2
    rst $18
    jr TaskZombie            ; 譲らない

; =============================================
SECTION "TileData", ROM0
HexTiles:
    db $3C,$3C,$66,$66,$6E,$6E,$76,$76,$66,$66,$66,$66,$3C,$3C,$00,$00
    db $18,$18,$38,$38,$18,$18,$18,$18,$18,$18,$18,$18,$3C,$3C,$00,$00
    db $3C,$3C,$66,$66,$06,$06,$0C,$0C,$30,$30,$60,$60,$7E,$7E,$00,$00
    db $3C,$3C,$66,$66,$06,$06,$1C,$1C,$06,$06,$66,$66,$3C,$3C,$00,$00
    db $0C,$0C,$1C,$1C,$3C,$3C,$6C,$6C,$7E,$7E,$0C,$0C,$0C,$0C,$00,$00
    db $7E,$7E,$60,$60,$7C,$7C,$06,$06,$06,$06,$66,$66,$3C,$3C,$00,$00
    db $3C,$3C,$60,$60,$7C,$7C,$66,$66,$66,$66,$66,$66,$3C,$3C,$00,$00
    db $7E,$7E,$06,$06,$0C,$0C,$18,$18,$30,$30,$30,$30,$30,$30,$00,$00
    db $3C,$3C,$66,$66,$66,$66,$3C,$3C,$66,$66,$66,$66,$3C,$3C,$00,$00
    db $3C,$3C,$66,$66,$66,$66,$3E,$3E,$06,$06,$0C,$0C,$38,$38,$00,$00
    db $3C,$3C,$66,$66,$66,$66,$7E,$7E,$66,$66,$66,$66,$66,$66,$00,$00
    db $7C,$7C,$66,$66,$66,$66,$7C,$7C,$66,$66,$66,$66,$7C,$7C,$00,$00
    db $3C,$3C,$66,$66,$60,$60,$60,$60,$60,$60,$66,$66,$3C,$3C,$00,$00
    db $78,$78,$6C,$6C,$66,$66,$66,$66,$66,$66,$6C,$6C,$78,$78,$00,$00
    db $7E,$7E,$60,$60,$60,$60,$7C,$7C,$60,$60,$60,$60,$7E,$7E,$00,$00
    db $7E,$7E,$60,$60,$60,$60,$7C,$7C,$60,$60,$60,$60,$60,$60,$00,$00
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00
HexTilesEnd:

SECTION "OSData", WRAM0[$C000]
wTick:      ds 2             ; $C000 OSの時刻(16ビット)
wCurTask:   ds 1             ; $C002
wInputEdge: ds 1             ; $C003 メールボックス
wPrevPad:   ds 1             ; $C004
wShow:      ds 4             ; $C005 表示スロット
wSPSave:    ds 2             ; $C009
wZom:       ds 1             ; $C00B
SECTION "TaskTable", WRAM0[$C010]
wTasks:     ds 24            ; 3タスク×8バイト(SP2,alive1,wake2,予備3)

SECTION "Stacks", WRAMX[$D100], BANK[1]
    ds 128                   ; タスク0(時計) $D100〜 天井$D180
    ds 128                   ; タスク1(カウンタ) 天井$D200
    ds 128                   ; タスク2(ゾンビ) 天井$D280
