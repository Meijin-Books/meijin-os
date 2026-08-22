# 第5部　RISC-V 編 ── MeijinOSrv（RV32 / QEMU virt）

書籍『OS の基本実装概要 ― 四つの機械で、同じ骨格を四度つくる』第5部（第37〜46章）・付録H のソースコードです。
M-mode から S-mode へ降り、トラップと `ecall` を作り、Sv32 ページングで「壁」を建て、隣のプロセスを侵せないことを確かめます。

## ファイル

| ファイル | 内容 | 対応する章 |
|---|---|---|
| `boot.S` | `_start`。hart 0 だけ残し、BSS を消し、PMP と委譲を設定して `mret` で S-mode へ | 第38章・付録H-3 |
| `trap.S` | `trap_entry`。`sscratch` の交換、32 語の退避領域、C の `trap_handler` へ、`sret` | 第40章・付録H-3 |
| `kernel.c` | UART・`kprintf`・ページテーブル（`map_page`）・プロセス・スケジューラ・システムコール・IPC・四つの実験 | 第37章・第41〜45章・付録H-4 |
| `user.S` | U-mode で走るプロセス A / B（`ecall` で `putc` / `yield` / `exit` / `send` / `recv`） | 第41章・第43〜45章 |
| `kernel.ld` | リンカスクリプト（0x80000000 起点、ヒープ 4MB、二本のスタック） | 付録A |
| `measured_log.txt` | 本書掲載のログはこの実測値 | 第43〜45章 |

## システムコール番号（`a7`）

| 番号 | 名前 | 章 |
|---|---|---|
| 1 | `SYS_PUTC` | 第41章 |
| 2 | `SYS_EXIT` | 第43章 |
| 3 | `SYS_YIELD` | 第43章 |
| 4 | `SYS_SEND` | 第45章 |
| 5 | `SYS_RECV` | 第45章 |
| 6 | `SYS_PUTHEX` | 第44章 |

## ビルドと実行

```sh
riscv64-unknown-elf-gcc -march=rv32ima_zicsr -mabi=ilp32 \
    -nostdlib -ffreestanding -O1 -T kernel.ld \
    -o kernel.elf boot.S trap.S user.S kernel.c

qemu-system-riscv32 -machine virt -bios none -kernel kernel.elf -nographic
```

`make` / `make run` でも同じです。`-bios none` を忘れると OpenSBI が M-mode に居座り、カーネルは S-mode・0x80200000 から始まってしまいます（第38章の前提が崩れます）。QEMU を抜けるのは `Ctrl-A X`。

検証環境: QEMU 8.2.2 / riscv64-unknown-elf-gcc 13.2.0 / Ubuntu 24.04。GCC 13 では `-march` に `_zicsr` が必須です。

## 動かすと、何が見えるか

```
[BOOT] M-mode -> S-mode. Now in supervisor.
[MMU] after : pc runs on VIRTUAL address.
--- EXP1: interleave ---            第43章5節  A/B 交互（協調型 yield）
ABABABABABABABAB
--- EXP2: same VA, different place  第44章2節  同じ 0x2000 が別の物理ページ
--- EXP3: the summit (page fault) --- 第44章3節  越境 → Store page fault（本書の頂上）
[TRAP] scause=15 (Store page fault)
[TRAP] stval=0x00005000  sepc=0x00001024
  -> killing pid=1.
--- EXP4: IPC ---                   第45章4節  カーネル経由の IPC
[IPC] pid=2 received 0x00001234 from pid=1
```

全文は `measured_log.txt`。
