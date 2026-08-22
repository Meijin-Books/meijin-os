/* reddot.c -- 自作の土台の上で動く最初のプログラム（第28章5節: 画面に赤い点を一つ） */
#include "gba.h"

#define MODE3   0x0003   /* 表示方式: モード 3 */
#define BG2_ON  0x0400   /* 背景 2 を表示する */

int main(void)
{
    REG_DISPCNT = MODE3 | BG2_ON;        /* モード 3 で表示開始 */
    VRAM[80 * 240 + 120] = RGB15(31, 0, 0); /* 中央に赤い点 */
    while (1) { }                        /* 表示を保つ */
    return 0;
}
