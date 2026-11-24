[日本語](README.md) | English

# Part 5: RISC-V — MeijinOSrv (RV32 / QEMU virt)

Source code for Part 5 (Chapters 37–46) and Appendix H of the book _Build a Tiny Operating System on a Game Boy: Four Kernels in a Few Hundred Lines — Game Boy, Mega Drive, GBA, and RISC-V_.
It drops from M-mode to S-mode, builds traps and `ecall`, raises the "wall" with Sv32 paging, and confirms that a process can no longer reach into its neighbor.

> **Note:** Comments in the source files are written in Japanese.

## Files

| File | What it is | Chapter |
|---|---|---|
| `boot.S` | `_start`. Keeps only hart 0, clears BSS, sets up PMP and delegation, and drops to S-mode with `mret` | Chapter 38, Appendix H-3 |
| `trap.S` | `trap_entry`. Swaps `sscratch`, saves into a 32-word area ([0]=PC, [1..31]=x1..x31), calls the C `trap_handler`, then `sret`. This is the macro from Appendix H-3 written out by hand | Chapter 40, Appendix H-3 |
| `kernel.c` | A verification kernel used to measure the logs in the book. UART output (`uart_puts` / `put_hex` / `put_dec`), page tables (`map_page`), processes, the scheduler, system calls, IPC, the illegal-instruction experiment of Chapter 40 section 7, and the four experiments | Chapters 37 and 40–45, Appendix H-4 |
| `user.S` | Processes that run in U-mode (`putc` / `yield` / `exit` / `send` / `recv` through `ecall`). Written directly into `.rodata` between labels; because it is mapped at virtual 0x1000 and run there, it is position-independent | Chapters 41 and 43–45 |
| `kernel.ld` | Linker script (origin 0x80000000, a 4 MB heap, two stacks) | Appendix A |
| `measured_log.txt` | The logs printed in the book are these measured values | Chapters 40 and 42–45 |

## System call numbers (`a7`)

| Number | Name | Chapter |
|---|---|---|
| 1 | `SYS_PUTC` | Chapter 41 |
| 2 | `SYS_EXIT` | Chapter 43 |
| 3 | `SYS_YIELD` | Chapter 43 |
| 4 | `SYS_SEND` | Chapter 45 |
| 5 | `SYS_RECV` | Chapter 45 |
| 6 | `SYS_PUTHEX` | Chapter 44 |

## Build and run

```sh
riscv64-unknown-elf-gcc -march=rv32ima_zicsr -mabi=ilp32 \
    -nostdlib -ffreestanding -O1 -T kernel.ld \
    -o kernel.elf boot.S trap.S user.S kernel.c

qemu-system-riscv32 -machine virt -bios none -kernel kernel.elf -nographic
```

`make` / `make run` do the same. If you forget `-bios none`, OpenSBI stays in M-mode and the kernel starts in S-mode (and not at 0x80000000), which breaks the assumptions of Chapter 38. Leave QEMU with `Ctrl-A X`.

Verified with QEMU 8.2.2 / riscv64-unknown-elf-gcc 13.2.0 / Ubuntu 24.04. With GCC 12 or later, `_zicsr` must be spelled out in `-march`.

## What you should see

```
[BOOT] M-mode -> S-mode. Now in supervisor.
[TRAP] scause=2 (Illegal instruction)    Ch.40 s.7  surviving an illegal instruction
[TRAP] sepc=0x800005a4 stval=0x300022f3
[TRAP] survived.
[MMU] after : pc runs on VIRTUAL address.
--- EXP1: interleave ---            Ch.43 s.5  A/B alternate (cooperative yield)
ABABABABABABABAB
--- EXP2: same VA, different place  Ch.44 s.2  the same 0x2000 is a different physical page
--- EXP3: the summit (page fault) --- Ch.44 s.3  crossing the wall -> Store page fault (the summit of the book)
[TRAP] scause=15 (Store page fault)
[TRAP] stval=0x00005000  sepc=0x00001018
  -> killing pid=1.
--- EXP4: IPC ---                   Ch.45 s.4  IPC through the kernel
[IPC] pid=2 received 0x00001234 from pid=1
```

The full log is in `measured_log.txt`.

## How the names map to the book (Appendix H)

`kernel.c` is a verification kernel gathered into a single file so that the logs and numbers in the book could be pinned down by measurement. The skeleton (the Sv32 map, `create_process`, swapping `sscratch`, system calls, IPC) is the same as Appendix H, but some names and the layout differ.

| The book / Appendix H | This folder |
|---|---|
| `kprintf()` | `uart_puts()` / `put_hex()` / `put_dec()` |
| `panic()` | None (halts with `for(;;);`) |
| `switch_page_table()` | `switch_pt()` |
| `alloc_process()` | Inlined at the top of `create_process()` |
| `pick_next_runnable()` | The loop inside `schedule()` |
| `handle_interrupt()` | None (if bit 31 of `scause` is set, it returns without doing anything) |
| `trap_frame[32]` / `REG_PC`… | `tf[32]` / `F_PC`… |
| `schedule()` switches, then returns to the `sret` on the way out | `schedule()` picks the next runner and goes straight to `sret` through `enter_user()`. When no runner is left, it moves on to the next experiment |
| Bringing in the user programs | Written directly into `.rodata` in `user.S` (between labels) |

`handle_syscall()` never calls `schedule()` for any system call; the switch happens exactly once, on the way out of `trap_handler()` (as in Chapter 41 and Chapter 43, section 4, of the book).
