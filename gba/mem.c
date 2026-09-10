/* mem.c -- いちばん単純な配り方 ― バンプ（第34章2節） */
#include "os.h"

#define HEAP_SIZE (64 * 1024)
/* aligned(4) は必須。size を丸めても、heap の先頭が未整列なら
   配る番地はすべて中途半端になる。ARM7TDMI は未整列の32ビットアクセスで
   例外を出さず、回転した値を黙って返すので、非常に見つけにくい（第34章2節）。 */
static unsigned char  heap[HEAP_SIZE] EWRAM_BSS __attribute__((aligned(4)));
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
