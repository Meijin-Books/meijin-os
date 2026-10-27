; =============================================
; selfish.asm ── 行儀の悪いタスクの実演（第13章1節）
; タスクBが、絶対に譲らなくなったら何が起きるか
; =============================================
INCLUDE "hardware.inc"

; --- システムコールの玄関（rst $10 = Yield）---
SECTION "RST10", ROM0[$10]
    jp Yield

; --- VBlankベクタ（画面の反映はOSの仕事）---
SECTION "VBlankVector", ROM0[$0040]
    jp VBlankHandler

SECTION "Header", ROM0[$100]
    jp EntryPoint
    ds $150 - @, 0

SECTION "MainCode", ROM0

; =============================================
; OS本体
; =============================================

; --- Yield: いま動いているタスクが、CPUを譲る ---
; これが「コンテキストスイッチ」の心臓部（全体で32命令）
Yield:
    push af              ; ① いまの世界（レジスタ4組）をスタックへ
    push bc
    push de
    push hl

    ld [wSPSave], sp     ; ② いまのSPを作業領域へ書き出す
    ld a, [wCurTask]     ;    保存先 = タスク表 + 番号×2
    add a
    ld c, a
    ld b, 0
    ld hl, wTaskSP
    add hl, bc
    ld a, [wSPSave]
    ld [hli], a          ;    SPの下位
    ld a, [wSPSave + 1]
    ld [hl], a           ;    SPの上位 ── 世界を保存した

    ld a, [wCurTask]     ; ③ 次のタスクを選ぶ（0と1を行き来）
    xor 1
    ld [wCurTask], a

    add a                ; ④ 選んだタスクの保存済みSPを取り出す
    ld c, a
    ld b, 0
    ld hl, wTaskSP
    add hl, bc
    ld a, [hli]
    ld h, [hl]
    ld l, a
    ld sp, hl            ; ⑤ SPを差し替える ＝ 世界の切り替え

    pop hl               ; ⑥ 切り替わった先の世界を復元
    pop de
    pop bc
    pop af
    ret                  ; ⑦ 「向こうの世界」の続きへ帰る

; --- VBlank: 二つのカウンタを画面に映す（OSが画面を支配する）---
VBlankHandler:
    push af
    push hl
    ld a, [wCntA]        ; タスクAのカウンタ → 上の行に16進2桁
    ld hl, $9800 + 2*32 + 2
    call DrawHexByte
    ld a, [wCntB]        ; タスクBのカウンタ → 下の行に16進2桁
    ld hl, $9800 + 4*32 + 2
    call DrawHexByte
    pop hl
    pop af
    reti

; Aの値を、HLの位置に16進2桁で描く（タイル0〜15 = 0〜F）
DrawHexByte:
    push af
    swap a
    and $0F
    ld [hli], a          ; 上位4ビット
    pop af
    and $0F
    ld [hl], a           ; 下位4ビット
    ret

; =============================================
; 起動と初期化
; =============================================
EntryPoint:
    ld sp, $FFFE
    ld a, 0
    ld [rNR52], a
.wait:
    ld a, [rLY]
    cp 144
    jp c, .wait
    ld a, 0
    ld [rLCDC], a

    ; 16進数字のタイル（0〜F）をVRAMへ
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

    ; 画面を空白で埋める（タイル0は「0」なので、空白はタイル16を使う）
    ld hl, $9800
    ld bc, 32 * 32
.clear:
    ld a, 16
    ld [hli], a
    dec bc
    ld a, b
    or c
    jp nz, .clear

    xor a
    ld [wCntA], a
    ld [wCntB], a
    ld [wCurTask], a     ; タスク0から始める

    ; --- タスクBの「偽の履歴」を作る（初期スタックの偽造）---
    ; Yieldが復元する順（hl,de,bc,af,戻り先PC）どおりに積んでおく
    ld hl, wStackB_Top - 10
    ld a, l
    ld [wTaskSP + 2], a
    ld a, h
    ld [wTaskSP + 3], a
    ld hl, wStackB_Top - 2
    ld a, LOW(TaskB)
    ld [hli], a
    ld a, HIGH(TaskB)    ; 「戻り先」＝タスクBの入り口
    ld [hl], a

    ld a, %11100100
    ld [rBGP], a
    ld a, LCDCF_ON | LCDCF_BGON
    ld [rLCDC], a
    xor a
    ld [rIF], a
    ld a, %00000001      ; VBlank割り込み
    ld [rIE], a
    ei

    ; そのままタスクAになる
    jp TaskA

; =============================================
; タスク（住人たち）
; =============================================
TaskA:
    ld a, [wCntA]
    inc a
    ld [wCntA], a        ; 自分の仕事（カウンタを増やす）
    halt                 ; 1フレーム待つ（目で読める速さにする）
    rst $10              ; CPUを譲る（システムコール）
    jp TaskA

TaskB:
    ld a, [wCntB]
    inc a
    ld [wCntB], a
    halt
    jp TaskB             ; ← rst $10 を消した。もう、譲らない

; =============================================
; データ部（16進数字 0〜F + 空白のタイル）
; =============================================
SECTION "TileData", ROM0
HexTiles:
    db $3C,$3C,$66,$66,$6E,$6E,$76,$76,$66,$66,$66,$66,$3C,$3C,$00,$00 ; 0
    db $18,$18,$38,$38,$18,$18,$18,$18,$18,$18,$18,$18,$3C,$3C,$00,$00 ; 1
    db $3C,$3C,$66,$66,$06,$06,$0C,$0C,$30,$30,$60,$60,$7E,$7E,$00,$00 ; 2
    db $3C,$3C,$66,$66,$06,$06,$1C,$1C,$06,$06,$66,$66,$3C,$3C,$00,$00 ; 3
    db $0C,$0C,$1C,$1C,$3C,$3C,$6C,$6C,$7E,$7E,$0C,$0C,$0C,$0C,$00,$00 ; 4
    db $7E,$7E,$60,$60,$7C,$7C,$06,$06,$06,$06,$66,$66,$3C,$3C,$00,$00 ; 5
    db $3C,$3C,$60,$60,$7C,$7C,$66,$66,$66,$66,$66,$66,$3C,$3C,$00,$00 ; 6
    db $7E,$7E,$06,$06,$0C,$0C,$18,$18,$30,$30,$30,$30,$30,$30,$00,$00 ; 7
    db $3C,$3C,$66,$66,$66,$66,$3C,$3C,$66,$66,$66,$66,$3C,$3C,$00,$00 ; 8
    db $3C,$3C,$66,$66,$66,$66,$3E,$3E,$06,$06,$0C,$0C,$38,$38,$00,$00 ; 9
    db $3C,$3C,$66,$66,$66,$66,$7E,$7E,$66,$66,$66,$66,$66,$66,$00,$00 ; A
    db $7C,$7C,$66,$66,$66,$66,$7C,$7C,$66,$66,$66,$66,$7C,$7C,$00,$00 ; B
    db $3C,$3C,$66,$66,$60,$60,$60,$60,$60,$60,$66,$66,$3C,$3C,$00,$00 ; C
    db $78,$78,$6C,$6C,$66,$66,$66,$66,$66,$66,$6C,$6C,$78,$78,$00,$00 ; D
    db $7E,$7E,$60,$60,$60,$60,$7C,$7C,$60,$60,$60,$60,$7E,$7E,$00,$00 ; E
    db $7E,$7E,$60,$60,$60,$60,$7C,$7C,$60,$60,$60,$60,$60,$60,$00,$00 ; F
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; 空白(16)
HexTilesEnd:

; =============================================
; 変数とスタック（メモリマップの取り決め）
; =============================================
SECTION "OSData", WRAM0[$C000]
wCntA:    ds 1           ; $C000 タスクAのカウンタ
wCntB:    ds 1           ; $C001 タスクBのカウンタ
wCurTask: ds 1           ; $C002 いま動いているタスク番号
wTaskSP:  ds 4           ; $C003 タスクごとのSP保存場所（2バイト×2）
wSPSave:  ds 2           ; $C007 SP退避用の作業領域

SECTION "StackB", WRAMX[$D100], BANK[1]
    ds 256
wStackB_Top:             ; タスクBのスタック（$D200から下へ伸びる）
