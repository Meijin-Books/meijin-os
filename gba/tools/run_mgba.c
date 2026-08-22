/* run_mgba.c -- libmgba でヘッドレスに ROM を走らせ、ログと画面を取り出す検証用ハーネス
 *
 *   cc -O2 -o run_mgba run_mgba.c -lmgba
 *   ./run_mgba foo.gba FRAMES out.ppm [keys-script] [peek-addrs]
 *
 *   keys-script: "frame:keymask,frame:keymask,..."（例 "120:0x0001" = 120 フレーム目に A を押す）
 *   mGBA のログ（kprintf の出力、BIOS ログ）は標準出力へ流す。
 *   実機・GUI 版 mGBA の代わりではなく、「本当に動いたか」を機械的に確かめるためのもの。
 */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <mgba/core/core.h>
#include <mgba/core/log.h>
#include <mgba/core/interface.h>
#include <mgba/core/config.h>

static void logfn(struct mLogger* l, int cat, enum mLogLevel lv, const char* fmt, va_list args) {
    (void)l; (void)lv;
    const char* name = mLogCategoryName(cat);
    if (strstr(fmt, "SWI: ")) return;           /* Halt は多すぎるので捨てる */
    printf("[%s] ", name ? name : "?");
    vprintf(fmt, args);
    printf("\n");
}

int main(int argc, char** argv) {
    if (argc < 4) { fprintf(stderr, "usage: %s rom frames out.ppm [keys]\n", argv[0]); return 1; }
    struct mLogger logger = { .log = logfn, .filter = NULL };
    mLogSetDefaultLogger(&logger);

    struct mCore* core = mCoreFind(argv[1]);
    if (!core) { fprintf(stderr, "not a rom\n"); return 1; }
    core->init(core);
    mCoreInitConfig(core, NULL);
    unsigned w, h;
    core->desiredVideoDimensions(core, &w, &h);
    color_t* buf = calloc(w * h, sizeof(color_t));
    core->setVideoBuffer(core, buf, w);
    mCoreLoadFile(core, argv[1]);
    core->reset(core);

    int frames = atoi(argv[2]);
    const char* keys = argc > 4 ? argv[4] : "";
    for (int f = 0; f < frames; f++) {
        uint32_t k = 0;
        const char* p = keys;
        while (*p) {                    /* そのフレームに押すキー（1 フレームだけ押す） */
            int fr; unsigned km;
            if (sscanf(p, "%d:%x", &fr, &km) == 2 && fr == f) k |= km;
            p = strchr(p, ','); if (!p) break; p++;
        }
        core->setKeys(core, k);
        core->runFrame(core);
    }
    /* 画面を PPM で書き出す */
    const void* px; size_t stride;
    core->getPixels(core, &px, &stride);
    FILE* o = fopen(argv[3], "wb");
    fprintf(o, "P6\n%u %u\n255\n", w, h);
    const uint32_t* row = px;
    for (unsigned y = 0; y < h; y++)
        for (unsigned x = 0; x < w; x++) {
            uint32_t c = row[y * stride + x];
            fputc(c & 0xFF, o); fputc((c >> 8) & 0xFF, o); fputc((c >> 16) & 0xFF, o);
        }
    fclose(o);
    /* 検証用に、指定された番地を覗く（argv[5] = "addr,addr,..." 16 進） */
    if (argc > 5) {
        const char* p = argv[5];
        while (*p) {
            unsigned a;
            if (sscanf(p, "%x", &a) == 1)
                printf("[%08x] = %08x\n", a, core->busRead32(core, a));
            p = strchr(p, ','); if (!p) break; p++;
        }
    }
    core->deinit(core);
    return 0;
}
