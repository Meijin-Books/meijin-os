/* gba.ld -- GBA リンカスクリプト（第28章3節・付録H-1）
   三つの領域（rom / iwram / ewram）と、四つの区画（.text / .data / .bss / スタック） */

OUTPUT_ARCH(arm)
ENTRY(_start)

MEMORY {
    rom   (rx)  : ORIGIN = 0x08000000, LENGTH = 32M
    iwram (rwx) : ORIGIN = 0x03000000, LENGTH = 32K
    ewram (rwx) : ORIGIN = 0x02000000, LENGTH = 256K
}

SECTIONS {
    .text : { *(.crt0) *(.text*) *(.rodata*) . = ALIGN(4); } > rom   /* 命令と定数は ROM へ */

    .data : {
        __data_start = .;
        *(.data*)
        *(.iwram*)
        . = ALIGN(4);
        __data_end = .;
    } > iwram AT> rom          /* 置き場所は IWRAM、焼く先は ROM */
    __data_lma = LOADADDR(.data);

    .bss (NOLOAD) : {
        __bss_start = .;
        *(.bss*)
        *(COMMON)
        . = ALIGN(4);
        __bss_end = .;
    } > iwram                  /* 0 で埋める領域。ROM は消費しない */

    /* タスクのスタックなど、大きな配列は EWRAM へ（__attribute__((section(".ewram")))） */
    .ewram (NOLOAD) : {
        __ewram_start = .;
        *(.ewram*)
        . = ALIGN(4);
        __ewram_end = .;
    } > ewram

    __sp_irq = 0x03007FA0;     /* IRQ モードのスタック先頭（BIOS の既定値と同じ） */
    __sp_usr = 0x03007F00;     /* System/User モードのスタック先頭 */

    /DISCARD/ : { *(.ARM.exidx*) *(.ARM.attributes) *(.comment) }
}
