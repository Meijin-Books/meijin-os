[日本語](README.md) | English

# meijin-os

Sample code for the book **_Build a Tiny Operating System on a Game Boy: Four Kernels in a Few Hundred Lines — Game Boy, Mega Drive, GBA, and RISC-V_** (Meijin Series).
The book builds a small OS with the same skeleton four times, on four machines: the Game Boy, the Mega Drive (Genesis), the Game Boy Advance, and RISC-V (QEMU).

| Folder | Part | Machine / CPU | Theme |
|---|---|---|---|
| [`gameboy/`](gameboy/README.en.md)     | Part 2 (Chapters 8–17)  | Game Boy / LR35902 (8-bit, no protection)        | A 32-instruction core. A world without walls |
| [`megadrive/`](megadrive/README.en.md) | Part 3 (Chapters 18–26) | Mega Drive / MC68000 (two privilege levels)      | A 13-instruction core. Where privilege separation begins |
| [`gba/`](gba/README.en.md)             | Part 4 (Chapters 27–36) | GBA / ARM7TDMI (modes and banked registers)      | Coming to terms with the BIOS |
| [`riscv/`](riscv/README.en.md)         | Part 5 (Chapters 37–46) | QEMU virt / RV32 (virtual memory)                | The wall finally goes up |

Each folder's README lists which file belongs to which chapter, how to build, and what you should see when you run it.
The complete code printed in Appendix G (Game Boy / Mega Drive) and Appendix H (GBA / RISC-V) lives here.
One exception: `riscv/kernel.c` is a verification kernel used to measure the logs shown in the book, so some function names and its layout differ from Appendix H (see Appendix H, section 4, and `riscv/README.en.md`).

The `gameboy/` folder also serves the book **_Learn Assembly and Build a Tiny OS on a Game Boy_**. See [`gameboy/README.en.md`](gameboy/README.en.md) for its chapter mapping.

> **Note:** Comments in the source files are written in Japanese. The instructions themselves are identical to the listings in the English editions.

## What you need

| Machine | Assembler / compiler | Emulator |
|---|---|---|
| Game Boy | [RGBDS](https://rgbds.gbdev.io/) 0.9 or later | BGB / SameBoy / Emulicious |
| Mega Drive | [vasm](http://sun.hasenbraten.de/vasm/) (`vasmm68k_mot`) | BlastEm |
| GBA | [devkitARM](https://devkitpro.org/) or `arm-none-eabi-gcc` | [mGBA](https://mgba.io/) |
| RISC-V | `riscv64-unknown-elf-gcc` 13 or later | `qemu-system-riscv32` 8 or later |

For details, see Appendix A of the book (build environments and tools for the four machines).

## Getting the code

```sh
git clone https://github.com/Meijin-Books/meijin-os.git
```

If you don't use Git, click the green **Code** button at the top of the page and choose **Download ZIP**.

## Verified environments

| Machine | How it was checked |
|---|---|
| Game Boy | Built with RGBDS 0.9.4; run on libmgba (mGBA 0.10) to check the counters and the task table |
| Mega Drive | `tools/verify.py` (with the bundled 68000 emulator): 16 / 16 checks OK |
| GBA | Built with arm-none-eabi-gcc 13.2; run on mGBA 0.10 (libmgba) and the screen checked |
| RISC-V | Run with riscv64-unknown-elf-gcc 13.2 / QEMU 8.2.2; output matches `riscv/measured_log.txt` |

## License

MIT License ([LICENSE](LICENSE)). You are free to modify it and to use it commercially.
If you build something with what you learned here, that is the best reward we could ask for.

- X: [@Meijin_Books](https://x.com/Meijin_Books)
