    .section .text.start,"ax",@progbits
    .globl _start
    .type _start, @function
_start:
    la sp, __stack_top
    li s0, 0x13579bdf
    li a0, 13
    li a1, 5
    li a2, 3
    call add_then_sub
    .globl example_return
example_return:
    j example_return
    .size _start, .-_start
    .section .note.GNU-stack,"",@progbits
