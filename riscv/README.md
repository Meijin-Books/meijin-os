# 第5部　RISC-V 編 ── MeijinOSrv（RV32 / QEMU virt）

書籍『OS の基本実装概要 ― ゲームボーイ・メガドライブ・GBA・RISC-V ― 四つの機械で、同じ骨格を四度つくる』第5部（第37〜46章）・付録H のソースコードです。
M-mode から S-mode へ降り、トラップと `ecall` を作り、Sv32 ページングで「壁」を建て、隣のプロセスを侵せないことを確かめます。

## ファイル

| ファイル | 内容 | 対応する章 |
|---|---|---|
| `boot.S` | `_start`。hart 0 だけ残し、BSS を消し、PMP と委譲を設定して `mret` で S-mode へ | 第38章・付録H-3 |
| `trap.S` | `trap_entry`。`sscratch` の交換、32 語の退避領域（[0]=PC、[1..31]=x1..x31）、C の `trap_handler` へ、`sret`。本書付録H-3 のマクロを展開した直書き版 | 第40章・付録H-3 |
| `kernel.c` | 本書のログを実測するための検証カーネル。UART 出力（`uart_puts`／`put_hex`／`put_dec`）・ページテーブル（`map_page`）・プロセス・スケジューラ・システムコール・IPC・第40章7節の不正命令実験と四つの実験 | 第37章・第40〜45章・付録H-4 |
| `user.S` | U-mode で走るプロセス（`ecall` で `putc` / `yield` / `exit` / `send` / `recv`）。`.rodata` にラベルで挟んで直書きし、仮想 0x1000 に写されて走るので位置独立に書く | 第41章・第43〜45章 |
| `kernel.ld` | リンカスクリプト（0x80000000 起点、ヒープ 4MB、二本のスタック） | 付録A |
| `measured_log.txt` | 本書掲載のログはこの実測値 | 第40章・第42〜45章 |

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

`make` / `make run` でも同じです。`-bios none` を忘れると OpenSBI が M-mode に居座り、カーネルは S-mode で（0x80000000 ではない番地から）始まってしまいます（第38章の前提が崩れます）。QEMU を抜けるのは `Ctrl-A X`。

検証環境: QEMU 8.2.2 / riscv64-unknown-elf-gcc 13.2.0 / Ubuntu 24.04。GCC 12 以降では `-march` に `_zicsr` の明示が必須です。

## 動かすと、何が見えるか

```
[BOOT] M-mode -> S-mode. Now in supervisor.
[TRAP] scause=2 (Illegal instruction)    第40章7節  不正命令から生きて戻る
[TRAP] sepc=0x800005a4 stval=0x300022f3
[TRAP] survived.
[MMU] after : pc runs on VIRTUAL address.
--- EXP1: interleave ---            第43章5節  A/B 交互（協調型 yield）
ABABABABABABABAB
--- EXP2: same VA, different place  第44章2節  同じ 0x2000 が別の物理ページ
--- EXP3: the summit (page fault) --- 第44章3節  越境 → Store page fault（本書の頂上）
[TRAP] scause=15 (Store page fault)
[TRAP] stval=0x00005000  sepc=0x00001018
  -> killing pid=1.
--- EXP4: IPC ---                   第45章4節  カーネル経由の IPC
[IPC] pid=2 received 0x00001234 from pid=1
```

全文は `measured_log.txt`。

## 本書（付録H）との名前の対応

`kernel.c` は、本書のログと数値を実測で確定させるために一本にまとめた検証カーネルです。骨格（Sv32 の地図・`create_process`・`sscratch` の差し替え・システムコール・IPC）は付録Hと同じですが、名前と構成が一部違います。

| 本書・付録H | このフォルダ |
|---|---|
| `kprintf()` | `uart_puts()`／`put_hex()`／`put_dec()` |
| `panic()` | なし（`for(;;);` で停止） |
| `switch_page_table()` | `switch_pt()` |
| `alloc_process()` | `create_process()` の冒頭に展開 |
| `pick_next_runnable()` | `schedule()` の中のループ |
| `handle_interrupt()` | なし（`scause` の bit31 が立っていれば何もせず戻る） |
| `trap_frame[32]`／`REG_PC`… | `tf[32]`／`F_PC`… |
| `schedule()` が切り替えて帰り道の `sret` へ戻る | `schedule()` が次の走者を選び `enter_user()` で直接 `sret`。走者が尽きたら次の実験へ進む |
| ユーザプログラムの取り込み | `user.S` の `.rodata` に直書き（ラベルで挟む） |

`handle_syscall()` はどのシステムコールでも `schedule()` を呼ばず、切り替えは `trap_handler()` の帰り道の一回だけです（本書第41章・第43章4節と同じ）。
