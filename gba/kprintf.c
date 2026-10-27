/* kprintf.c -- カーネルにも、口が要る（第36章1〜2節）
   mGBA のログ窓口（0x04FFF780 / 0x04FFF700 / 0x04FFF600）へ流す。
   実機では存在しない番地への書き込みになり、何も起きない。 */
#include <stdarg.h>
#include "os.h"

static char buf[256];               /* mGBA のバッファは 256 バイトまで */
static int  n;

static void out(char c)
{
    if (n < 255) buf[n++] = c;
}

static void flush(void)
{
    buf[n] = 0;
    for (int i = 0; i <= n; i++) MGBA_BUF[i] = buf[i];
    MGBA_FLAGS = 0x0100 | 2;        /* 合図を送ると mGBA に表示される（2 = warn） */
    n = 0;
}

void kprintf_init(void)
{
    MGBA_ENABLE = 0xC0DE;           /* ログ機能を有効にする */
}

void kprintf(const char *fmt, ...)
{
    /* buf と n は全タスクで一本。途中で切り替わると文字が混ざるので、
       書き終えて合図を送るまで割り込みを止める（第36章2節） */
    unsigned s = irq_disable();
    va_list ap;
    va_start(ap, fmt);
    for (; *fmt; fmt++) {
        if (*fmt != '%') { if (*fmt == '\n') flush(); else out(*fmt); continue; }
        switch (*++fmt) {
        case 'd': {
            int v = va_arg(ap, int);
            if (v < 0) { out('-'); v = -v; }
            char t[12]; int k = 0;
            do { t[k++] = '0' + v % 10; v /= 10; } while (v);
            while (k--) out(t[k]);
            break;
        }
        case 'x': {
            u32 v = va_arg(ap, u32);
            static const char hex[] = "0123456789abcdef";
            for (int i = 28; i >= 0; i -= 4) out(hex[(v >> i) & 0xF]);
            break;
        }
        case 's': { const char *s = va_arg(ap, const char *); while (*s) out(*s++); break; }
        default:  out(*fmt);
        }
    }
    va_end(ap);
    irq_restore(s);
}
