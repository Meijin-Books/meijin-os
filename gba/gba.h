/* gba.h -- I/O レジスタという操作卓（第27章4節）
   番地に名前を付けて、変数のように書く */
#ifndef GBA_H
#define GBA_H

typedef unsigned char  u8;
typedef unsigned short u16;
typedef unsigned int   u32;

#define REG16(a) (*(volatile u16*)(a))
#define REG32(a) (*(volatile u32*)(a))

/* 画面 */
#define REG_DISPCNT   REG16(0x04000000)
#define REG_DISPSTAT  REG16(0x04000004)
#define REG_VCOUNT    REG16(0x04000006)
#define REG_BG0CNT    REG16(0x04000008)
#define PALETTE       ((volatile u16*)0x05000000)
#define VRAM          ((volatile u16*)0x06000000)
#define TILES         ((volatile u32*)0x06000000)   /* キャラクタベース 0 */
#define MAP           ((volatile u16*)0x0600F800)   /* スクリーンベース 31 */

/* 入力 */
#define REG_KEYINPUT  REG16(0x04000130)
#define KEY_A      0x0001
#define KEY_B      0x0002
#define KEY_SELECT 0x0004
#define KEY_START  0x0008
#define KEY_RIGHT  0x0010
#define KEY_LEFT   0x0020
#define KEY_UP     0x0040
#define KEY_DOWN   0x0080

/* タイマ */
#define REG_TM0CNT_L  REG16(0x04000100)
#define REG_TM0CNT_H  REG16(0x04000102)

/* 割り込み（第29章2節: IME・IE・IF） */
#define REG_IE        REG16(0x04000200)
#define REG_IF        REG16(0x04000202)
#define REG_IME       REG16(0x04000208)
#define REG_IFBIOS    REG16(0x03007FF8)
#define IRQ_VBLANK    0x0001
#define IRQ_TIMER0    0x0008

typedef void (*irq_fn)(void);
#define IRQ_VECTOR    (*(volatile irq_fn*)0x03007FFC)   /* 第29章3節 */

/* mGBA のログ窓口（第36章1節） */
#define MGBA_ENABLE   REG16(0x04FFF780)
#define MGBA_FLAGS    REG16(0x04FFF700)
#define MGBA_BUF      ((volatile char*)0x04FFF600)

#define RGB15(r,g,b)  ((r) | ((g) << 5) | ((b) << 10))

/* IWRAM に置き、ARM 状態でコンパイルする（割り込みハンドラ用） */
#define IWRAM_ARM __attribute__((section(".iwram"), target("arm")))
#define EWRAM_BSS __attribute__((section(".ewram")))

#endif
