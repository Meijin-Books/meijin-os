#!/usr/bin/env python3
"""gbafix.py -- devkitPro の gbafix の最小代用（第28章2節: ROM ヘッダ 192 バイト）

  使い方: python3 tools/gbafix.py foo.gba [-t TITLE]

  書き込むもの: タイトル(0xA0-0xAB) / 固定値 0x96(0xB2) / 補数チェック(0xBD)
  書き込まないもの: 任天堂ロゴ(0x04-0x9F)。mGBA など多くのエミュレータはロゴを検査しないが、
  実機とロゴを検査するエミュレータでは devkitPro の gbafix を使うこと。
"""
import sys

def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__); sys.exit(1)
    path = args[0]
    title = "MEIJINOS"
    if "-t" in args:
        title = args[args.index("-t") + 1]
    rom = bytearray(open(path, "rb").read())
    if len(rom) < 0xC0:
        rom += b"\0" * (0xC0 - len(rom))
    t = title.upper().encode("ascii", "replace")[:12].ljust(12, b"\0")
    rom[0xA0:0xAC] = t
    rom[0xAC:0xB0] = b"MOS\0"[:4].ljust(4, b"\0")   # ゲームコード
    rom[0xB0:0xB2] = b"01"                          # メーカーコード
    rom[0xB2] = 0x96                                # 固定値
    rom[0xB3] = 0x00                                # 本体コード
    rom[0xB4] = 0x00                                # デバイスタイプ
    rom[0xBC] = 0x00                                # バージョン
    chk = 0
    for b in rom[0xA0:0xBD]:
        chk = (chk - b) & 0xFF
    rom[0xBD] = (chk - 0x19) & 0xFF                 # 補数チェック
    # 256 バイト単位に切り上げ（末尾は 0xFF で埋める）
    pad = (-len(rom)) % 256
    rom += b"\xFF" * pad
    open(path, "wb").write(rom)
    print(f"{path}: header fixed (title={title})")

if __name__ == "__main__":
    main()
