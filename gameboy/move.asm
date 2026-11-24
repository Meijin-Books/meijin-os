; =============================================
; move.asm：第11章「動くものを作る」完全版
; 十字キーでキャラクター（スプライト）を動かす
; ビルド:
;   rgbasm -o move.o move.asm
;   rgblink -o move.gb move.o
;   rgbfix -v -p 0xFF move.gb
; =============================================

INCLUDE "hardware.inc"

; --- 割り込みベクタ（第9章4節の定石どおり、jp一行だけを置く） ---
SECTION "VBlankVector", ROM0[$0040]
    jp VBlankHandler

SECTION "Header", ROM0[$100]
    jp EntryPoint
    ds $150 - @, 0       ; ヘッダ領域を空ける

SECTION "MainCode", ROM0

; --- VBlankハンドラ（計算済みの座標をOAMへ反映する） ---
; ※本書では学習のため OAM へ直接書込み。実戦では OAM DMA が定石（第11章4節参照）
VBlankHandler:
    push af              ; 使うレジスタを退避
    ld a, [wPlayerY]
    ld [$FE00], a        ; Y座標をOAMへ
    ld a, [wPlayerX]
    ld [$FE01], a        ; X座標をOAMへ
    pop af               ; 退避した値を戻す
    reti                 ; 元の処理へ復帰

EntryPoint:
    ld sp, $FFFE         ; スタックを設定（第8章1節参照／call・push の土台）
    ld a, 0
    ld [rNR52], a        ; サウンドを止める

WaitVBlank:
    ld a, [rLY]
    cp 144
    jp c, WaitVBlank     ; VBlankを待つ

    ld a, 0
    ld [rLCDC], a        ; LCDを消す（消えているあいだに初期化する）

    ; --- OAMの掃除（第11章2節：ゴミ値のスプライトを消す） ---
    ld hl, $FE00         ; OAMの先頭
    ld b, 160            ; 40体 × 4バイト
    xor a                ; A = 0
ClearOAM:
    ld [hli], a          ; 0 を書いて HL を進める
    dec b
    jp nz, ClearOAM

    ; --- 背景の初期化（ブートROMが残したロゴを消す） ---
    ld hl, $9000           ; 背景タイル0 を空白にする（16バイト）
    ld b, 16
    xor a
ClearBlankTile:
    ld [hli], a
    dec b
    jp nz, ClearBlankTile

    ld hl, $9800           ; タイルマップ全体をタイル0で埋める
    ld bc, 32 * 32
ClearMap:
    xor a
    ld [hli], a
    dec bc
    ld a, b
    or c
    jp nz, ClearMap

    ; --- スプライト用タイルをVRAMへ転送（スプライトは $8000 から） ---
    ld de, SpriteTile
    ld hl, $8000
    ld bc, SpriteTileEnd - SpriteTile
CopyTiles:
    ld a, [de]
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or c
    jp nz, CopyTiles

    ; --- 座標の初期値（画面のほぼ中央） ---
    ld a, 80
    ld [wPlayerY], a
    ld a, 80
    ld [wPlayerX], a

    ; --- スプライト1体ぶんのOAMを設定（第11章2節） ---
    ld a, 80
    ld [$FE00], a        ; Y座標（表示位置+16）
    ld a, 80
    ld [$FE01], a        ; X座標（表示位置+8）
    ld a, 0
    ld [$FE02], a        ; タイル番号
    ld a, 0
    ld [$FE03], a        ; 属性

    ; --- パレット設定 ---
    ld a, %11100100
    ld [rBGP], a         ; 背景パレット
    ld a, %11100100
    ld [rOBP0], a        ; スプライトパレット

    ; --- LCDを点ける（背景に加えてスプライトも表示） ---
    ld a, LCDCF_ON | LCDCF_BGON | LCDCF_OBJON
    ld [rLCDC], a

    ; --- 割り込みの準備（第9章3節：スイッチ二つと掲示板一つ） ---
    xor a
    ld [rIF], a          ; 掲示板（IF）を空にしてから
    ld a, %00000001      ; 一番下のビット = VBlank

    ld [rIE], a          ; 個別スイッチ（IE）を入れて
    ei                   ; 大元のスイッチ（IME）を入れる

; =============================================
; メインループ（第9章6節の骨格）
; =============================================
Main:
    call ReadDPad        ; 方向キーを読む（結果はBに、押下=0）

    bit 0, b             ; 右
    jr nz, .notRight
    ld a, [wPlayerX]
    inc a
    ld [wPlayerX], a
.notRight:
    bit 1, b             ; 左
    jr nz, .notLeft
    ld a, [wPlayerX]
    dec a
    ld [wPlayerX], a
.notLeft:
    bit 2, b             ; 上
    jr nz, .notUp
    ld a, [wPlayerY]
    dec a
    ld [wPlayerY], a
.notUp:
    bit 3, b             ; 下
    jr nz, .notDown
    ld a, [wPlayerY]
    inc a
    ld [wPlayerY], a
.notDown:

    halt                 ; 割り込み（VBlank）が来るまで休む
    jp Main              ; ループ

; --- 方向キーの読み取り（第10章3節） ---
ReadDPad:
    ld a, %00100000      ; ビット4=0で方向キーを選択
    ld [$FF00], a
    nop                  ; 信号が安定するまで少し待つ
    nop
    ld a, [$FF00]        ; 状態を読む
    and %00001111        ; 下位4ビットだけ取り出す
    ld b, a              ; 結果をBに保存
    ret

; =============================================
; データ部
; =============================================
SECTION "TileData", ROM0
; キャラクターの絵（8×8・2BPP形式、丸いかたまり）
SpriteTile:

    db $3C,$3C,$7E,$7E,$FF,$DB,$FF,$FF,$FF,$FF,$FF,$E7,$7E,$7E,$3C,$3C
SpriteTileEnd:

SECTION "Variables", WRAM0
wPlayerX: ds 1           ; プレイヤーのX座標（1バイト確保）
wPlayerY: ds 1           ; プレイヤーのY座標
