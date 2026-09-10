; alloctest.asm ── 第16章3〜4節: 固定ブロックアロケータの検証
INCLUDE "hardware.inc"
SECTION "Header", ROM0[$100]
    jp EntryPoint
    ds $150 - @, 0
SECTION "MainCode", ROM0
; --- Alloc: 空き部屋を探して貸し出す(HL=部屋の番地、満室ならHL=0) ---
; 注意: Alloc/Free は台帳 wAllocMap を「読んで書き戻す」。このテストは割り込みなしで動くが、
;       v0.2 以降の OS に組み込むときは、読み〜書き戻しを di / ei で挟む（第15章5節・第16章3節）。
Alloc:
    push bc
    ld a, [wAllocMap]        ; 各ビットが1部屋の「使用中」札
    ld b, a
    ld c, 0                  ; 部屋番号
.find:
    bit 0, b
    jr z, .vacant
    srl b
    inc c
    ld a, c
    cp 4
    jr c, .find
    ld hl, 0                 ; 満室
    pop bc
    ret
.vacant:
    call BitOfC              ; B = 1 << C
    ld a, [wAllocMap]
    or b                     ; 札を立てる
    ld [wAllocMap], a
    ld a, c
    swap a                   ; ×16
    ld l, a
    ld h, $D3                ; 部屋 = $D300 + 番号×16
    pop bc
    ret
; --- Free: HLの部屋を返す ---
Free:
    push bc
    ld a, l
    swap a
    and $0F                  ; 部屋番号
    ld c, a
    call BitOfC
    ld a, b
    cpl
    ld b, a
    ld a, [wAllocMap]
    and b                    ; 札を下ろす
    ld [wAllocMap], a
    pop bc
    ret
BitOfC:                      ; B = 1 << C を作る小道具
    ld b, 1
    ld a, c
    or a
    ret z
.sh:
    sla b
    dec a
    jr nz, .sh
    ret
EntryPoint:
    ld sp, $FFFE
    xor a
    ld [wAllocMap], a
    call Alloc
    ld a, l
    ld [$C020], a
    ld a, h
    ld [$C021], a
    push hl
    call Alloc
    ld a, l
    ld [$C022], a
    ld a, h
    ld [$C023], a
    pop hl
    call Free
    call Alloc
    ld a, l
    ld [$C024], a
    ld a, h
    ld [$C025], a
    ld a, [wAllocMap]
    ld [$C026], a
.done:
    jp .done
SECTION "OSData", WRAM0[$C000]
wAllocMap: ds 1
