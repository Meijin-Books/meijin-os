#!/usr/bin/env python3
"""mkfont.py -- font.c を生成する（Pillow の既定ビットマップフォントを 8x8 / 4bpp タイルに切り出す）
   python3 tools/mkfont.py > font.c
"""
from PIL import Image, ImageDraw, ImageFont
f = ImageFont.load_default()
print('/* font.c -- 8x8 / 4bpp のフォント（ASCII 0-127、タイル番号＝文字コード）')
print('   tools/mkfont.py が生成。第35章2節「タイル・マップ・パレット」 */')
print('const unsigned int font_tiles[128][8] = {')
for c in range(128):
    im = Image.new('1', (8, 12), 0)
    if c >= 32:
        ImageDraw.Draw(im).text((0, 0), chr(c), font=f, fill=1)
    words = []
    for y in range(3, 11):
        v = 0
        for x in range(8):
            if im.getpixel((x, y)):
                v |= 1 << (4 * x)          # 4bpp: 1 ピクセル = 1 ニブル、パレット 1 番
        words.append(v)
    tail = f' /* {chr(c)!r} */' if c >= 32 else ''
    print('  {' + ','.join(f'0x{v:08x}' for v in words) + '},' + tail)
print('};')
