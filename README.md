# meijin-os

書籍『**OS の基本実装概要 ― 四つの機械で、同じ骨格を四度つくる**』（Meijin シリーズ）のサンプルコードです。
ゲームボーイ・メガドライブ・ゲームボーイアドバンス・RISC-V（QEMU）の四つの機械で、同じ骨格の小さな OS を四度作ります。

| フォルダ | 部 | 機械 / CPU | 主題 |
|---|---|---|---|
| [`gameboy/`](gameboy/)     | 第2部（第8〜17章）  | ゲームボーイ / LR35902（8 ビット・保護なし） | 心臓部 32 命令。壁のない世界 |
| [`megadrive/`](megadrive/) | 第3部（第18〜26章） | メガドライブ / MC68000（二段特権）           | 心臓部 13 命令。特権分離のはじまり |
| [`gba/`](gba/)             | 第4部（第27〜36章） | GBA / ARM7TDMI（モードとバンクレジスタ）     | BIOS と折り合いをつける |
| [`riscv/`](riscv/)         | 第5部（第37〜46章） | QEMU virt / RV32（仮想記憶）                 | ついに壁が建つ |

各フォルダの README に、ファイルと章の対応・ビルド手順・動かすと何が見えるかをまとめています。
付録G（ゲームボーイ／メガドライブ）・付録H（GBA／RISC-V）に載せたコードの全文は、ここにあります。

## 必要なもの

| 機械 | アセンブラ / コンパイラ | エミュレータ |
|---|---|---|
| ゲームボーイ | [RGBDS](https://rgbds.gbdev.io/) 0.9 系以降 | BGB / SameBoy / Emulicious |
| メガドライブ | [vasm](http://sun.hasenbraten.de/vasm/)（`vasmm68k_mot`） | BlastEm |
| GBA | [devkitARM](https://devkitpro.org/) または `arm-none-eabi-gcc` | [mGBA](https://mgba.io/) |
| RISC-V | `riscv64-unknown-elf-gcc` 13 以降 | `qemu-system-riscv32` 8 以降 |

詳しくは本書の付録A「4機種のビルド環境と道具立て」を。

## 入手

```sh
git clone https://github.com/Meijin-Books/meijin-os.git
```

Git を使わない場合は、ページ上部の緑色の **Code** ボタン → **Download ZIP** から一式を入手できます。

## 検証済み環境

| 機械 | 確認方法 |
|---|---|
| ゲームボーイ | RGBDS 0.9.4 でビルド |
| メガドライブ | `tools/verify.py`（付属の 68000 エミュレータ）で 15 / 15 項目 OK |
| GBA | arm-none-eabi-gcc 13.2 でビルド、mGBA 0.10（libmgba）で実行・画面確認 |
| RISC-V | riscv64-unknown-elf-gcc 13.2 / QEMU 8.2.2 で実行、`riscv/measured_log.txt` と一致 |

## ライセンス

MIT License（[LICENSE](LICENSE)）。改変・商用利用ともに自由です。
学んだものを使って何かを作っていただけたら、それが一番うれしい報酬です。

- X: [@Meijin_Books](https://x.com/Meijin_Books)
