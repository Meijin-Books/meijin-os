# 第4部　GBA 編 ── MeijinOS/ARM（ARM7TDMI）

書籍『OS の基本実装概要 ― 四つの機械で、同じ骨格を四度つくる』第4部（第27〜36章）・付録H のソースコードです。
BIOS が割り込みの入口と swi の入口を握っている GBA の上で、協調 → プリエンプティブ → シェル付きの v1.0 まで組み上げます。

## ファイル

| ファイル | 内容 | 対応する章 |
|---|---|---|
| `gba.ld` | リンカスクリプト（rom / iwram / ewram の三領域） | 第28章3節・付録H-1 |
| `crt0.s` | 起動処理。ヘッダを飛び越し、二本のスタックを立て、.data を写し、.bss を消して main へ | 第28章4節・付録H-1 |
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

**coop.gba** ── `A = 000020FB` / `B = 000020FC`。二つのタスクが交互に数え、差は 1 以内に収まります。

**preempt.gba** ── `A` も `B` も `yield` を呼びません。それでも両方が進み、数は揃いません（`A=2225E B=21B8`）。
第20章7節の「48A1 対 3FBA」と同じ光景です。三行目の `tick` が約 1ms ごとに進みます。

**meijin.gba** ── シェルが待っています。十字キー上下で候補を選び、A で起動、B で最後に起動したアプリを殺します。
`clock`（1 秒に 1 つ）、`draw`（模様を回す）、`count`（五つ数えて `svc_exit` で自分から終わる）。
`tasks:` の行に全タスクの状態（R=READY W=WAITING B=BLOCKED F=FINISHED）が出ます。

## 本文と違うところ（読んでから動かす人へ）

1. **全コードを ARM 状態（`-marm`）でビルドしています。** 本文の `switch_context` は `ldmfd sp!, {r4-r11, pc}` で戻り、
   偽の履歴の CPSR は `0x1F`（T ビットなし）です。ARM7TDMI（ARMv4T）の `ldm` は T ビットを変えないので、
   この書き方のまま Thumb のタスクへは戻れません。本文どおりのコードを本文どおりに動かすため、Thumb は使っていません。
2. **BIOS の Halt（`swi 0x02`）を呼ぶのはアイドルタスク（タスク 0 ＝ `main` の残り）だけです。**
   BIOS の swi 処理は SVC スタックに r11/r12/lr を積んだまま System モードへ降りて走ります。
   その最中にタイマで別のタスクへ切り替わり、そのタスクも swi を呼ぶと、全タスク共有の SVC スタックが壊れます
   （第32章4節「玄関は借り物」の、もう一つの代償）。`svc_sleep` / `svc_yield` は次のティックで取り上げられるのを待ちます。
3. `irq_init` の最後で CPSR の I ビットを落としています。`crt0` は「禁止のまま」main へ来るので、IME だけでは割り込みは届きません。
4. 画面に書くときは `console_print_at` / `console_hex_at` で割り込みを止めています。
   止めずに二つのタスクが同じ行へ書くと、文字が混ざります。第33章1節の競合を、実際に見たい人は外してみてください。

## 検証（ヘッドレス）

```sh
cd tools && gcc -O2 -o run_mgba run_mgba.c -lmgba && cd ..       # libmgba-dev が必要
./tools/run_mgba preempt.gba 300 out.ppm                           # 300 フレーム走らせ、ログと画面を出す
./tools/run_mgba meijin.gba 900 out.ppm "60:0x1,90:0x80,120:0x1"   # 60 フレーム目に A、90 に DOWN、120 に A
```

このリポジトリの GBA 編は、この方法で mGBA 0.10 上で動作を確認しています（実機では未確認です）。
