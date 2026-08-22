/* console.c -- 表示ドライバと入力ドライバ（第35章2〜4節）
   タイルは 0x06000000（キャラクタベース 0）、マップは 0x0600F800（スクリーンベース 31） */
#include "os.h"

extern const unsigned int font_tiles[128][8];   /* font.c */

static int col, row;                 /* いまの書き込み位置 */
#define COLS 30
#define ROWS 20

void console_init(void)
{
    PALETTE[0] = RGB15(0, 0, 8);     /* 背景: 紺 */
    PALETTE[1] = RGB15(31, 31, 31);  /* 文字: 白 */
    for (int c = 0; c < 128; c++)    /* フォントを VRAM へ。タイル番号 = 文字コード */
        for (int y = 0; y < 8; y++)
            TILES[c * 8 + y] = font_tiles[c][y];
    for (int i = 0; i < 32 * 32; i++) MAP[i] = ' ';
    REG_BG0CNT  = 0x1F00;            /* タイルは 0x06000000、マップは 0x0600F800 */
    REG_DISPCNT = 0x0100;            /* モード 0、背景 0 を表示する */
    col = row = 0;
}

static void scroll(void)
{
    for (int r = 0; r < ROWS - 1; r++)
        for (int c = 0; c < 32; c++)
            MAP[r * 32 + c] = MAP[(r + 1) * 32 + c];
    for (int c = 0; c < 32; c++) MAP[(ROWS - 1) * 32 + c] = ' ';
    row = ROWS - 1;
}

void console_goto(int r, int c) { row = r; col = c; }

void console_putc(char ch)
{
    if (ch == '\n') { col = 0; if (++row >= ROWS) scroll(); return; }
    if (ch == '\r') { col = 0; return; }
    MAP[row * 32 + col] = (u8)ch;    /* 文字をタイル番号として置く */
    if (++col >= COLS) { col = 0; if (++row >= ROWS) scroll(); }
}

void console_puts(const char *s) { while (*s) console_putc(*s++); }

void console_puthex(u32 v)
{
    static const char hex[] = "0123456789ABCDEF";
    for (int i = 28; i >= 0; i -= 4) console_putc(hex[(v >> i) & 0xF]);
}

/* 位置を指定して一気に書く。途中で取り上げられると、別のタスクの文字と混ざる
   （第33章1節「強制的な切り替えが連れてきた、新しい問題」）ので、割り込みを止めて守る */
void console_print_at(int r, int c, const char *s)
{
    unsigned f = irq_disable();
    console_goto(r, c); console_puts(s);
    irq_restore(f);
}
void console_hex_at(int r, int c, const char *label, u32 v)
{
    unsigned f = irq_disable();
    console_goto(r, c); console_puts(label); console_puthex(v);
    irq_restore(f);
}

/* ---- 入力ドライバ: 状態ではなく、出来事を配る（第35章4節） ---- */
static u16 prev;                     /* 前回のボタン状態 */
static u16 queue[16];                /* 押した瞬間のキュー */
static volatile int qhead, qtail;

void input_poll(void)                /* VBlank ごとに割り込みの中で呼ばれる */
{
    u16 keys    = ~REG_KEYINPUT & 0x03FF;   /* 押下 = 1 */
    u16 pressed = keys & ~prev;             /* 押した瞬間 */
    prev = keys;
    if (pressed && ((qtail + 1) & 15) != qhead) {
        queue[qtail] = pressed;
        qtail = (qtail + 1) & 15;
    }
}

u16 input_getkey(void)
{
    if (qhead == qtail) return 0;
    u16 k = queue[qhead];
    qhead = (qhead + 1) & 15;
    return k;
}
