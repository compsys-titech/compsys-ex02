ENTRY(_start)
MEMORY
{
    RAM (rwx) : ORIGIN = 0x80000000, LENGTH = 128K
}
PHDRS
{
    code PT_LOAD FLAGS(5);
    data PT_LOAD FLAGS(6);
}
SECTIONS
{
    .text : { *(.text.start) *(.text .text.*) } > RAM :code
    .rodata : { *(.rodata .rodata.*) } > RAM :code
    .data : { *(.data .data.*) *(.sdata .sdata.*) } > RAM :data
    .bss (NOLOAD) : { *(.bss .bss.*) *(.sbss .sbss.*) *(COMMON) } > RAM :data
    __image_end = .;
    __stack_top = ORIGIN(RAM) + LENGTH(RAM);
    __stack_bottom = __stack_top - 4K;
    ASSERT(__image_end <= __stack_bottom, "Code/data overlaps the stack")
    ASSERT((__stack_top & 15) == 0, "Stack must be 16-byte aligned")
}
