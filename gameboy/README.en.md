[日本語](README.md) | English

# Part 2: Game Boy — MeijinOS (LR35902)

Source code for Part 2 (Chapters 8–17) and Appendix G of the book _Build a Tiny Operating System on a Game Boy: Four Kernels in a Few Hundred Lines — Game Boy, Mega Drive, GBA, and RISC-V_.
On an 8-bit machine with 8 KB of RAM and no protection, it grows an OS with a 32-instruction core from v0.1 to v0.2 to v1.0.

> **Note:** Comments in the source files are written in Japanese.

## Files

| File | What it is | Chapter |
|---|---|---|
| `hardware.inc` | Constant definitions, v4.9.1 (distributed by gbdev). **Use the v4 series.** The v5 series renamed the constants and is not compatible | — |
| `hello.asm` | The first program: prints HELLO WORLD on the screen | — (see the "Learn Assembly" table below) |
| `move.asm` | Moves a sprite with the D-pad | — (same) |
| `coop.asm` | **v0.1** Cooperative multitasking (`rst $10` = Yield) | Chapter 12, Appendix G-1 |
| `preempt.asm` | **v0.2** Preemptive (timer interrupt at 16 Hz) | Chapter 13 |
| `selfish.asm` | Demo: one task that never yields freezes the world | Chapter 13, section 1 |
| `meijin10.asm` | **v1.0** The finished version (clock + counter + hog + taskbar). A = count, SELECT+START = kill the hog | Chapters 14–17, Appendix G-2 |
| `smash.asm` | Demo: stomping on the neighbor's stack (about 60 laps, the world collapses within seconds) | Chapter 16, section 5 |
| `alloctest.asm` | Test of the fixed-block allocator (16 bytes × 4 rooms) | Chapter 16, sections 3–4 |

## Using this folder with _Learn Assembly and Build a Tiny OS on a Game Boy_

This folder also holds the source code for the book _Learn Assembly and Build a Tiny OS on a Game Boy_ (Meijin Series). Read the chapter numbers as follows. (Chapter numbers in the source comments follow _Learn Assembly_ for `hello.asm` and `move.asm`, and the four-machine book above for the rest.)

| File | Chapter in _Learn Assembly and Build a Tiny OS on a Game Boy_ |
|---|---|
| `hello.asm` | Chapter 6, Appendix B section 1 |
| `move.asm` | Chapter 11, Appendix B section 2 |
| `coop.asm` | Chapter 17, Appendix B section 3 |
| `selfish.asm` | Chapter 18, section 1 |
| `preempt.asm` | Chapter 18 |
| `meijin10.asm` | Chapters 19–22, Appendix B section 5 |
| `alloctest.asm` | Chapter 21, sections 3–4 |
| `smash.asm` | Chapter 21, section 5 |

## Build (verified with RGBDS 0.9; the same three lines work with 1.0)

```sh
rgbasm  -o coop.o  coop.asm
rgblink -o coop.gb -n coop.sym coop.o   # -n writes a symbol file (BGB loads it automatically)
rgbfix  -v -p 0xFF coop.gb
```

If you have `make`, a single `make` builds everything (`Makefile`).

## Run

Drag and drop the `.gb` file onto BGB (Windows), SameBoy, or Emulicious (macOS / Linux / Windows).
`coop.gb` and `preempt.gb` show two hexadecimal counters in the upper left. In the cooperative version they stay equal, as in `171 = 171`;
in the preemptive version they do not (Chapter 13, section 5).
