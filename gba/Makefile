# =================================================
# MeijinOS/ARM（GBA）── ビルド
#   必要なもの： arm-none-eabi-gcc（devkitARM または GNU Arm Embedded Toolchain）
#                gbafix（devkitPro gba-tools）。無ければ tools/gbafix.py で代用
#
#   make            … 全部ビルド（reddot.gba coop.gba preempt.gba meijin.gba）
#   make clean
# =================================================

PREFIX ?= arm-none-eabi-
CC      = $(PREFIX)gcc
OBJCOPY = $(PREFIX)objcopy
GBAFIX ?= $(shell command -v gbafix 2>/dev/null || echo python3 tools/gbafix.py)

# 本書のコード（switch_context の ldmfd {..,pc}、偽の履歴の CPSR=0x1F）は ARM 状態を前提にしている。
# ARM7TDMI（ARMv4T）の ldm は T ビットを変えないので、全コードを ARM 状態（-marm）でビルドする。
CFLAGS  = -mcpu=arm7tdmi -marm -mthumb-interwork -O2 -g -Wall -Wextra \
          -ffreestanding -fno-builtin -nostdlib -fno-exceptions -fno-asynchronous-unwind-tables
LDFLAGS = -nostartfiles -nostdlib -T gba.ld -Wl,--gc-sections
LIBS    = -lgcc

KERNEL  = crt0.o switch.o task.o irq.o sync.o mem.o console.o font.o kprintf.o

TARGETS = reddot.gba coop.gba preempt.gba meijin.gba
all: $(TARGETS)

reddot.elf:  crt0.o reddot.o
coop.elf:    $(KERNEL) main_coop.o
preempt.elf: $(KERNEL) main_preempt.o
meijin.elf:  $(KERNEL) main_meijin.o

%.elf: gba.ld
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(filter %.o,$^) $(LIBS)

%.gba: %.elf
	$(OBJCOPY) -O binary $< $@
	$(GBAFIX) $@ -t $(basename $@)

%.o: %.c gba.h os.h
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.s
	$(CC) $(CFLAGS) -x assembler-with-cpp -c -o $@ $<

clean:
	rm -f *.o *.elf *.gba

.PHONY: all clean
