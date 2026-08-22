# MeijinOSrv（RISC-V / QEMU virt）── ビルド
PREFIX ?= riscv64-unknown-elf-
CC      = $(PREFIX)gcc
CFLAGS  = -march=rv32ima_zicsr -mabi=ilp32 -nostdlib -ffreestanding -O1
QEMU   ?= qemu-system-riscv32

kernel.elf: boot.S trap.S user.S kernel.c kernel.ld
	$(CC) $(CFLAGS) -T kernel.ld -o $@ boot.S trap.S user.S kernel.c

run: kernel.elf
	$(QEMU) -machine virt -bios none -kernel kernel.elf -nographic

debug: kernel.elf
	$(QEMU) -machine virt -bios none -kernel kernel.elf -nographic -s -S

clean:
	rm -f kernel.elf

.PHONY: run debug clean
