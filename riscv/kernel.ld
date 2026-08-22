OUTPUT_ARCH("riscv")
ENTRY(_start)

SECTIONS
{
    . = 0x80000000;

    .text : {
        *(.text.init)
        *(.text .text.*)
    }

    .rodata : { *(.rodata .rodata.*) }
    .data   : { *(.data .data.*) }

    . = ALIGN(4096);
    .bss : {
        bss_start = .;
        *(.bss .bss.*)
        bss_end = .;
    }

    . = ALIGN(4096);
    heap_start = .;
    . += 0x400000;
    heap_end = .;

    . = ALIGN(16);
    . += 0x4000;
    stack_top = .;

    . = ALIGN(16);
    . += 0x4000;
    kernel_stack_top = .;
}
