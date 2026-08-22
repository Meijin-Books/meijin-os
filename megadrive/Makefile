# =================================================
# MeijinOS68k ── ビルド
#   必要なもの： vasm (m68k / Motorola syntax)
#
#   make          … 全部ビルド
#   make verify   … 実際に走らせて検証（vasm 不要。Python3 だけで動きます）
#   make clean    … .bin を消す
#
#   Windowsで make が無い場合は、build.bat を使ってください。
# =================================================

VASM   ?= vasmm68k_mot
VFLAGS ?= -Fbin

TARGETS = coop.bin preempt.bin meijin10.bin trace.bin crash.bin
DEPS    = vdp.asm font.asm

all: $(TARGETS)

%.bin: %.asm $(DEPS)
	$(VASM) $(VFLAGS) -o $@ $<

# 検証は vasm を必要としません（tools/emu68k.py がソースを直接読みます）
verify:
	python3 tools/verify.py

clean:
	rm -f $(TARGETS) *.lst

.PHONY: all verify clean
