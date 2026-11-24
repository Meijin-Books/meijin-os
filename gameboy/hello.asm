; =============================================
; hello.asm：第6章「はじめてのプログラム」完全版
; 画面に HELLO WORLD と表示する
; ビルド:
;   rgbasm -o hello.o hello.asm
;   rgblink -o hello.gb hello.o
;   rgbfix -v -p 0xFF hello.gb
; =============================================
INCLUDE "hardware.inc"

SECTION "Header", ROM0[$100]
    jp EntryPoint
    ds $150 - @, 0       ; ヘッダ領域を空ける

SECTION "MainCode", ROM0
EntryPoint:
    ld a, 0
    ld [rNR52], a        ; サウンドを止める

WaitVBlank:
    ld a, [rLY]
    cp 144
    jp c, WaitVBlank     ; VBlankを待つ

    ld a, 0
    ld [rLCDC], a        ; LCDを消す

    ; --- タイルデータの転送（文字の絵をVRAMへ） ---
    ld de, Tiles
    ld hl, $9000
    ld bc, TilesEnd - Tiles
CopyTiles:
    ld a, [de]
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or c
    jp nz, CopyTiles

    ; --- タイルマップの転送① 画面全体を空白タイルで埋める ---
    ld hl, $9800
    ld bc, 32 * 32       ; マップ全体（32×32マス）
ClearMap:
    ld a, 0              ; タイル0 = 空白
    ld [hli], a
    dec bc
    ld a, b
    or c
    jp nz, ClearMap

    ; --- タイルマップの転送② メッセージを置く（構造はタイル転送と同一） ---

    ld de, Message
    ld hl, $9800 + 8 * 32 + 4    ; 8行下・4マス右（画面の中央付近）
    ld bc, MessageEnd - Message
CopyMessage:
    ld a, [de]
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or c
    jp nz, CopyMessage

    ld a, LCDCF_ON | LCDCF_BGON
    ld [rLCDC], a        ; LCDを点ける
    ld a, %11100100
    ld [rBGP], a         ; パレット設定

Done:
    jp Done

; =============================================
; データ部
; =============================================
SECTION "TileData", ROM0

; タイル一覧（1タイル = 16バイト、2BPP形式・第7章参照）
; 0:空白 1:H 2:E 3:L 4:O 5:W 6:R 7:D
Tiles:
    db $00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00,$00 ; 空白

    db $66,$66,$66,$66,$66,$66,$7E,$7E,$66,$66,$66,$66,$66,$66,$00,$00 ; H
    db $7E,$7E,$60,$60,$60,$60,$7C,$7C,$60,$60,$60,$60,$7E,$7E,$00,$00 ; E
    db $60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$60,$7E,$7E,$00,$00 ; L
    db $3C,$3C,$66,$66,$66,$66,$66,$66,$66,$66,$66,$66,$3C,$3C,$00,$00 ; O
    db $63,$63,$63,$63,$63,$63,$6B,$6B,$6B,$6B,$7F,$7F,$36,$36,$00,$00 ; W
    db $7C,$7C,$66,$66,$66,$66,$7C,$7C,$6C,$6C,$66,$66,$66,$66,$00,$00 ; R
    db $78,$78,$6C,$6C,$66,$66,$66,$66,$66,$66,$6C,$6C,$78,$78,$00,$00 ; D
TilesEnd:

; メッセージ（タイル番号の並び = HELLO WORLD）
Message:
    db 1, 2, 3, 3, 4, 0, 5, 4, 6, 3, 7
MessageEnd:
