[日本語](README.md) | English

# Part 4: GBA — MeijinOS/ARM (ARM7TDMI)

Source code for Part 4 (Chapters 27–36) and Appendix H of the book _Build a Tiny Operating System on a Game Boy: Four Kernels in a Few Hundred Lines — Game Boy, Mega Drive, GBA, and RISC-V_.
On the GBA, where the BIOS owns both the interrupt entry and the `swi` entry, it builds up from cooperative to preemptive to a v1.0 with a shell.

> **Note:** Comments in the source files are written in Japanese.

## Files

| File | What it is | Chapter |
|---|---|---|
| `gba.ld` | Linker script (three regions: rom / iwram / ewram) | Chapter 28 section 3, Appendix H-1 |
| `crt0.s` | Startup. Jumps over the header, sets up two stacks, copies .data, clears .bss and .ewram, then calls main | Chapter 28 section 4, Appendix H-1 |
| `gba.h` | Names for the I/O registers (DISPCNT / IE / IF / IME / TM0CNT / KEYINPUT / the mGBA log port) | Chapter 27 section 4, Chapter 29 |
| `reddot.c` | One red dot on the screen: proof that the foundation works | Chapter 28 section 5 |
| `switch.s` | `switch_context` (cooperative, 4 instructions), `irq_handler_preempt` (repacks what the BIOS wrapped), `svc_halt` | Chapter 30 sections 2 and 6, Appendix H-2 |
| `task.c` | TCBs, the fake history (`task_create` / `task_create_p`), `schedule_pick_next`, `yield`, and the `svc_*` entry points | Chapter 30, Chapter 32 section 4, Chapter 33 section 6 |
| `irq.c` | The order in which IME/IE/IF are set, the C dispatcher for the cooperative version, and the roughly 1 ms tick on timer 0 | Chapter 29 |
| `sync.c` | Mutex and semaphore | Chapter 33 sections 2 and 4 |
| `mem.c` | Bump allocator | Chapter 34 section 2 |
| `console.c` / `font.c` | Display driver (mode 0, BG0, tile = character code) and input driver (edges go into a queue) | Chapter 35 sections 2–4 |
| `kprintf.c` | A minimal printf that writes to the mGBA log port | Chapter 36 sections 1–2 |
| `main_coop.c` | **coop.gba** — two tasks hand the CPU to each other with `yield` (`A = B`) | Chapter 30 section 4 |
| `main_preempt.c` | **preempt.gba** — nobody yields and both still advance. The clock sleeps with `svc_sleep` | Chapter 30 sections 5–6 |
| `main_meijin.c` | **meijin.gba** — v1.0. The shell waits for input and starts or kills clock / draw / count | Chapter 35 section 6 |
| `tools/gbafix.py` | A minimal stand-in for devkitPro's `gbafix` (it does not write the logo; use the real one for hardware) | Chapter 28 section 2 |
| `tools/run_mgba.c` | A verification harness that runs headless on libmgba and extracts the log and the screen | Appendix A |
| `tools/mkfont.py` | Generates `font.c` | — |

## Build

All you need is `arm-none-eabi-gcc` (devkitARM or the GNU Arm Embedded Toolchain).
If `gbafix` is not on your PATH, `tools/gbafix.py` is used instead.

```sh
make                 # reddot.gba coop.gba preempt.gba meijin.gba
make clean
```

Open the resulting `.gba` in [mGBA](https://mgba.io/). Output from `kprintf` appears under **Tools → View logs** in mGBA.

## What you should see

**coop.gba** — After 300 frames, around `A = 00002100` / `B = 000020FF` (it shifts a little with the length of startup). The two tasks count in turn and stay within 1 of each other.

**preempt.gba** — Neither `A` nor `B` calls `yield`. Both still advance, and the numbers do not match (`A=2225E B=21B8`).
It is the same sight as "48A1 vs. 3FBA" in Chapter 20, section 7. The `tick` on the third row advances about once per millisecond.

**meijin.gba** — The shell is waiting. Choose an entry with D-pad up/down, start it with A, and kill the most recently started app with B.
`clock` (one count per second), `draw` (cycles a pattern), and `count` (counts to five, then ends itself with `svc_exit`).
The `tasks:` row shows the state of every task (R=READY W=WAITING B=BLOCKED F=FINISHED).

## About the parts the book gives "in outline only"

The code in the text (Chapters 27–36), the code in Appendix H, and the code in this folder share the same skeleton: how the fake history is stacked, the steps of the switch, and the entry-point numbers. To show the principle, the text simplifies function arguments and the shape of the wait queues in places. This folder fills in the following.

| What was filled in | Where in the book |
|---|---|
| Three things in `irq_handler_preempt`: `input_poll` on VBlank; `bl on_tick` (`on_tick` in `task.c` advances `g_tick` and counts a slice as `SLICE_LEN` = 10 ticks); and skipping the switch when the SPSR mode is Supervisor (in the middle of a BIOS swi) | Chapter 30 section 6, Chapter 32 section 4, Appendix H-2 |
| `task_create` / `task_create_p` take only `(entry)`, choose a free slot (TCB and stack) themselves, and return its number | Chapter 30 sections 3 and 6, Chapter 34 section 4 |
| `stack_bottom` in the TCB (where the sentinel goes). Waiters are held as a 32-bit bitmask, and there are four states: READY / WAITING (waiting for a time) / BLOCKED (waiting for a lock or a token) / FINISHED | Chapter 33 sections 2 and 6, Chapter 34 section 4 |
| Input is a 16-entry ring buffer. `input_getkey()` returns 0 without waiting, and the shell sleeps one frame before asking again | Chapter 33 section 5, Chapter 35 section 4 |
| `schedule_pick_next` (wake-up checks for waiting tasks, the round, and the fallback to idle) | Chapter 33 section 6 |
| The bodies of `svc_sleep` / `svc_exit` / `svc_getkey` | Chapter 32 section 4, Chapter 35 section 4 |
| The console font (`font.c`) and scrolling | Chapter 35 sections 2–3 |
| The shell itself (menu, spawn, kill, the sentinel patrol) | Chapter 35 section 6, Chapter 36 section 3 |
| The whole build (Makefile, `tools/gbafix.py`) | Chapter 28 section 2, Appendix A |

For the record, here are three points where the implementation follows the policy stated in the text.

1. **Everything is built in ARM state (`-marm`).** As Chapter 27 section 2 and Chapter 30 section 2 explain, `ldm … pc` on the ARM7TDMI does not change the T bit, so it cannot return into a Thumb task. Mixing in Thumb is an exercise for after you have written the switch by hand once.
2. **Only the idle task calls the BIOS Halt (`swi 0x02`).** As Chapter 32 section 4 explains, BIOS swi handling uses the SVC stack shared by all tasks, so switching in the middle of it breaks things. `switch.s` skips the switch when the SPSR mode is Supervisor. Other tasks that are waiting simply wait to be preempted at the next tick.
3. **`irq_init` clears the I bit in CPSR at the very end.** As Chapter 29 section 4 explains, `crt0` arrives at `main` with interrupts disabled, so IME alone is not enough.

The following two are covered in the book but are not included in this folder (they are left as exercises).

- **Sound** (DirectSound A + DMA1 + timer 1, Chapter 35 section 5). The text shows the design only.
- **Reclaiming the slot of a task that ended with `svc_exit`.** The state just becomes FINISHED; the TCB and stack are not reused except by the shell's B-kill (which resets `sp` to 0).

In one place the code goes a step beyond the text. `console_print_at` / `console_hex_at`, which write to the screen, disable interrupts and write in one go. That is the race shown in Chapter 33 section 1 (two tasks writing to the same row and their characters mixing) carried straight into the implementation. If you want to see the race with your own eyes, remove this `irq_disable` / `irq_restore`.

## Verification (headless)

```sh
cd tools && gcc -O2 -o run_mgba run_mgba.c -lmgba && cd ..       # needs libmgba-dev
./tools/run_mgba preempt.gba 300 out.ppm                           # run 300 frames, dump the log and the screen
./tools/run_mgba meijin.gba 900 out.ppm "60:0x1,90:0x80,120:0x1"   # A at frame 60, DOWN at frame 90, A at frame 120
```

The GBA part of this repository was verified this way on mGBA 0.10 (it has not been tested on real hardware).
