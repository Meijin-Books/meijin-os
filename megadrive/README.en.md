[日本語](README.md) | English

# Part 3: Mega Drive — MeijinOS68k (MC68000)

Source code for Part 3 (Chapters 18–26) and Appendix G of the book _Build a Tiny Operating System on a Game Boy: Four Kernels in a Few Hundred Lines — Game Boy, Mega Drive, GBA, and RISC-V_.
On top of the 68000's two privilege levels, supervisor and user, it builds an OS with a 13-instruction core.

> **Note:** Comments in the source files, and the messages printed by `tools/verify.py`, are written in Japanese.

```asm
Yield:
    ori.w   #$0700,sr           ; (0) mask interrupts (nobody may touch us mid-switch)
    movem.l d0-d7/a0-a6,-(sp)   ; (1) seal the world
    lea     TaskTable,a0        ; (2) record the current SP in the task table
    move.w  CurTask,d1
    move.w  d1,d0
    lsl.w   #3,d0
    move.l  sp,(a0,d0.w)
    bsr     SelectNext          ; (3) pick the next task
    move.w  d0,CurTask          ; (4) look it up in the task table
    lsl.w   #3,d0
    move.l  (a0,d0.w),sp        ; (5) swap SP = switch worlds
    movem.l (sp)+,d0-d7/a0-a6   ; (6) restore the world
    rte                         ; (7) return into the other world
```

Step (0) is there because a 68000 `trap` does not raise the interrupt mask (Chapter 20, section 5).

## Files

| File | What it is | Chapter |
|---|---|---|
| `coop.asm` | **v0.1** Cooperative multitasking | Chapter 20, Appendix G-3 |
| `preempt.asm` | **v0.2** Preemptive (the only differences from v0.1: vector 30 is re-pointed, and the tasks' `trap #0` is removed) | Chapter 20, section 7 |
| `meijin10.asm` | **v1.0** The finished version (user mode + system calls + exceptions + Alloc/Free) | Chapters 21–26, Appendix G-4 |
| `trace.asm` | Demo of the trace mechanism: a minimal profiler | Chapter 25, section 4 |
| `crash.asm` | Demo: killing the neighbor (protection is only half there) | Chapter 26, section 3 |
| `vdp.asm` | Screen routines (`ShowHex` / `VDPRegs`, shared by all versions) | Chapters 19 and 24 |
| `font.asm` | Tile data for the hexadecimal digits | — |
| `tools/emu68k.py` | A small 68000 emulator for verification (only the instructions the book's code uses) | — |
| `tools/verify.py` | Mechanically checks the claims made in the text | — |

## Build

All you need is [vasm](http://sun.hasenbraten.de/vasm/) (m68k / Motorola syntax).

```sh
make            # build everything
make coop.bin   # build just one
vasmm68k_mot -Fbin -o coop.bin coop.asm     # by hand
```

On Windows without `make`, use `build.bat` (`build.bat coop` / `build.bat clean` / `build.bat verify`).

Load the resulting `.bin` into [BlastEm](https://www.retrodev.com/blastem/) or a similar emulator. It also runs on real hardware.

## What you should see

**`coop.asm`** — The same value climbs on the upper and lower rows (`2A = 2A`).

**`preempt.asm`** — Neither task calls `trap #0`, and both still run (`48A1` vs. `3FBA`; Chapter 20, section 7).

**`meijin10.asm`** — Three residents share the machine: a clock, an A-button counter, and a hog that never yields. Start+A kills the hog (Chapter 25, section 6).

**`crash.asm`** — Task 0 gets an array size wrong and stomps on its neighbor, task 1. The CPU says nothing (Chapter 26, section 3).

**`trace.asm`** — Set the T bit in task 1's SR and an exception fires after every instruction. This is what a debugger's "single step" really is (Chapter 25, section 4).

## Verification (no vasm needed, only Python 3)

```sh
python3 tools/verify.py      # or: make verify / build.bat verify
```

Excerpt (16 checks in all; the script prints its messages in Japanese, translated here):

```
[ 2] Ch.20 s.5: Yield is 13 instructions (the core)
     [OK  ] measured: 13 instructions
[ 6] Ch.20: cooperative multitasking (2A = 2A)
     [OK  ] A=149 B=149 (diff=0)
[ 7] Ch.20 s.7: preemptive (nobody yields, both still run)
     [OK  ] A=8320 B=8616
[10] Ch.25: catching a privilege violation (only the culprit dies)
     [OK  ] alive=[1, 1, 0] ErrCode=$008E
[12] Ch.26 s.3: killing the neighbor (protection is only half there)
     [OK  ] alive=[1, 0, 1] ErrCode=$001C
[14] Ch.25 s.6: the hotkey (Start+A) kills the hog
     [OK  ] alive=[1, 1, 0]
[15] Ch.26 s.2: the allocator (Alloc / Free) never lends the same room twice
     [OK  ] lent=[$FF8000, $FF8100, $FF8200] re-lent after free=$FF8100
----------------------------------------------------------------
Result: 16 / 16 checks OK
```

> The error code recorded by `crash.asm` depends on where the corrupted PC happens to land
> (sometimes an address error, `$008C`; sometimes an illegal instruction, `$001C`). The one thing that never changes is that task 1 dies.

## Homework (Chapter 26, section 6)

- Add a fourth task (increase `NUM_TASKS` and add one more ShowHex to VBlankPreempt; rows 13 and 15 are used by the exception display)
- Expose `Alloc` / `Free` as system calls (add `trap #5`)
- Write a profiler with the trace mechanism
- **Prevent the incident of Chapter 26, section 3, using only the 68000's hardware** … you probably can't. Confirming that you can't is also learning.
