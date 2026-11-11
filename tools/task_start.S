    .section .text.start,"ax",@progbits
    .globl _start
    .type _start, @function
_start:
    la sp, __stack_top
    li a0, 13
    li a1, 5
    li a2, 3
    call call_task
    .globl task_return
task_return:
    j task_return
    .size _start, .-_start
    .section .note.GNU-stack,"",@progbits
