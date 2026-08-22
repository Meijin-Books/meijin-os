/* mem.c -- いちばん単純な配り方 ― バンプ（第34章2節） */
#include "os.h"

#define HEAP_SIZE (64 * 1024)
static unsigned char  heap[HEAP_SIZE] EWRAM_BSS;
static unsigned char *hp = heap;            /* 次に渡す位置の目印 */

void *bump_alloc(unsigned size)
{
    size = (size + 3) & ~3u;                /* 4 バイト境界へ丸める */
    if (hp + size > heap + HEAP_SIZE)
        return 0;                           /* 足りなければ諦める */
    void *p = hp;
    hp += size;                             /* 目印を進める */
    return p;
}
