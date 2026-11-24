# MeijinOS（ゲームボーイ）── ビルド。必要なもの: RGBDS（rgbasm / rgblink / rgbfix）
TARGETS = hello.gb move.gb coop.gb preempt.gb selfish.gb meijin10.gb smash.gb alloctest.gb

all: $(TARGETS)

%.o: %.asm hardware.inc
	rgbasm -o $@ $<

%.gb: %.o
	rgblink -o $@ -n $*.sym $<
	rgbfix -v -p 0xFF $@

clean:
	rm -f *.o *.gb *.sym

.PHONY: all clean
