# 第4部　GBA 編 ── MeijinOS/ARM（ARM7TDMI）

書籍『OS の基本実装概要 ― ゲームボーイ・メガドライブ・GBA・RISC-V ― 四つの機械で、同じ骨格を四度つくる』第4部（第27〜36章）・付録H のソースコードです。
BIOS が割り込みの入口と swi の入口を握っている GBA の上で、協調 → プリエンプティブ → シェル付きの v1.0 まで組み上げます。

## ファイル

| ファイル | 内容 | 対応する章 |
|---|---|---|
| `gba.ld` | リンカスクリプト（rom / iwram / ewram の三領域） | 第28章3節・付録H-1 |
| `crt0.s` | 起動処理。ヘッダを飛び越し、二本のスタックを立て、.data を写し、.bss と .ewram を消して main へ | 第28章4節・付録H-1 |
| `gba.h` | I/O レジスタの名前（DISPCNT / IE / IF / IME / TM0CNT / KEYINPUT / mGBA ログ窓口） | 第27章4節・第29章 |
| `reddot.c` | 画面に赤い点を一つ。土台が動いた証拠 | 第28章5節 |
| `switch.s` | `switch_context`（協調版・4命令）、`irq_handler_preempt`（BIOS の包みを詰め替える）、`svc_halt` | 第30章2節・6節・付録H-2 |
| `task.c` | TCB・偽の履歴（`task_create` / `task_create_p`）・`schedule_pick_next`・`yield`・窓口 `svc_*` | 第30章・第32章4節・第33章6節 |
| `irq.c` | IME/IE/IF の設定順序、協調版の C ディスパッチャ、タイマ0 の約 1ms ティック | 第29章 |
| `sync.c` | ミューテックス・セマフォ | 第33章2節・4節 |
| `mem.c` | バンプアロケータ | 第34章2節 |
| `console.c` / `font.c` | 表示ドライバ（モード0・BG0・タイル＝文字コード）と入力ドライバ（エッジをキューへ） | 第35章2〜4節 |
| `kprintf.c` | mGBA のログ窓口へ流す最小 printf | 第36章1〜2節 |
| `main_coop.c` | **coop.gba** ── 二つのタスクが `yield` で譲り合う（`A = B`） | 第30章4節 |
| `main_preempt.c` | **preempt.gba** ── 誰も譲らないのに両方進む。時計は `svc_sleep` で眠る | 第30章5〜6節 |
| `main_meijin.c` | **meijin.gba** ── v1.0。シェルが入力を待ち、clock / draw / count を起動・kill する | 第35章6節 |
| `tools/gbafix.py` | devkitPro `gbafix` の最小代用（ロゴは書かない。実機向けには本物を） | 第28章2節 |
| `tools/run_mgba.c` | libmgba でヘッドレスに走らせ、ログと画面を取り出す検証ハーネス | 付録A |
| `tools/mkfont.py` | `font.c` の生成 | ── |

## ビルド

必要なのは `arm-none-eabi-gcc`（devkitARM または GNU Arm Embedded Toolchain）だけです。
`gbafix` が PATH に無ければ `tools/gbafix.py` が使われます。

```sh
make                 # reddot.gba coop.gba preempt.gba meijin.gba
make clean
```

できた `.gba` を [mGBA](https://mgba.io/) で開いてください。`kprintf` の出力は mGBA の **Tools → View logs** に出ます。

## 動かすと、何が見えるか

**coop.gba** ── 300 フレーム走らせると `A = 00002100` / `B = 000020FF` 前後（起動処理の長さで少し前後します）。二つのタスクが交互に数え、差は 1 以内に収まります。

**preempt.gba** ── `A` も `B` も `yield` を呼びません。それでも両方が進み、数は揃いません（`A=2225E B=21B8`）。
第20章7節の「48A1 対 3FBA」と同じ光景です。三行目の `tick` が約 1ms ごとに進みます。

**meijin.gba** ── シェルが待っています。十字キー上下で候補を選び、A で起動、B で最後に起動したアプリを殺します。
`clock`（1 秒に 1 つ）、`draw`（模様を回す）、`count`（五つ数えて `svc_exit` で自分から終わる）。
`tasks:` の行に全タスクの状態（R=READY W=WAITING B=BLOCKED F=FINISHED）が出ます。

## 本文が「骨子のみ」とした部分について

本文（第27〜36章）と付録Hのコードと、このフォルダのコードは、骨格（偽の履歴の積み方・切り替えの手順・窓口の番号）が同じです。本文は原理を示すために関数の引数や待ち行列の形を簡略にしている箇所があり、このフォルダでは次の部分を補いました。

| 補ったもの | 対応する本文 |
|---|---|
| `irq_handler_preempt` の三点 ── VBlank なら `input_poll`、`bl on_tick`（`task.c` の `on_tick` が `g_tick` を進め、`SLICE_LEN`=10 ティックでスライスを数える）、SPSR のモードが Supervisor（BIOS の swi の最中）なら切り替えを見送る | 第30章6節・第32章4節・付録H-2 |
| `task_create` / `task_create_p` は `(entry)` だけを取り、空き区画（TCB とスタック）を自分で選んで番号を返す | 第30章3節・6節・第34章4節 |
| TCB に `stack_bottom`（番兵の置き場所）。待ち手は 32 ビットのビットマスクで持ち、状態は READY／WAITING（時刻待ち）／BLOCKED（鍵・札待ち）／FINISHED の四つ | 第33章2節・6節・第34章4節 |
| 入力は 16 要素のリングバッファ。`input_getkey()` は待たずに 0 を返し、シェルは 1 フレーム眠ってから聞き直す | 第33章5節・第35章4節 |
| `schedule_pick_next`（待機の起床判定と巡回、アイドルへのフォールバック） | 第33章6節「三つの状態と、何もしないタスク」 |
| `svc_sleep` / `svc_exit` / `svc_getkey` の中身 | 第32章4節・第35章4節 |
| コンソールのフォント（`font.c`）とスクロール | 第35章2〜3節 |
| シェル本体（メニュー・spawn・kill・番兵の見回り） | 第35章6節・第36章3節 |
| ビルド一式（Makefile・`tools/gbafix.py`） | 第28章2節・付録A |

本文の方針と実装が一致している点を、念のため三つ挙げておきます。

1. **すべて ARM 状態（`-marm`）でビルドします。** 第27章2節・第30章2節のとおり、ARM7TDMI の `ldm … pc` は T ビットを変えないため、Thumb のタスクへは戻れません。Thumb を混ぜるのは、切り替えを一度自分の手で書いたあとの課題です。
2. **BIOS の Halt（`swi 0x02`）を呼ぶのはアイドルタスクだけです。** 第32章4節のとおり、BIOS の swi 処理は全タスク共有の SVC スタックを使うため、その最中に切り替えると壊れます。`switch.s` は SPSR のモードが Supervisor のときは切り替えを見送ります。ほかのタスクの待ちは、次のティックで取り上げられるのを待つ形です。
3. **`irq_init` の最後で CPSR の I ビットを落とします。** 第29章4節のとおり、`crt0` は割り込み禁止のまま `main` へ来るので、IME だけでは届きません。

次の二つは、本書では扱っていても、このフォルダには入れていません（演習として残してあります）。

- **サウンド**（第35章5節の DirectSound A ＋ DMA1 ＋ タイマ1）。本文は設計のみを示しています。
- **`svc_exit` で終わったタスクの区画の回収**。状態を FINISHED にするだけで、TCB とスタックはシェルの B キル（`sp` を 0 に戻す）以外では再利用されません。

一点だけ、本文より一歩進めた箇所があります。画面へ書く `console_print_at` / `console_hex_at` は、割り込みを止めて一気に書いています。第33章1節が見せる競合（二つのタスクが同じ行へ書くと文字が混ざる）を、そのまま実装に反映した結果です。競合を自分の目で見たい方は、この `irq_disable` / `irq_restore` を外してみてください。

## 検証（ヘッドレス）

```sh
cd tools && gcc -O2 -o run_mgba run_mgba.c -lmgba && cd ..       # libmgba-dev が必要
./tools/run_mgba preempt.gba 300 out.ppm                           # 300 フレーム走らせ、ログと画面を出す
./tools/run_mgba meijin.gba 900 out.ppm "60:0x1,90:0x80,120:0x1"   # 60 フレーム目に A、90 に DOWN、120 に A
```

このリポジトリの GBA 編は、この方法で mGBA 0.10 上で動作を確認しています（実機では未確認です）。
