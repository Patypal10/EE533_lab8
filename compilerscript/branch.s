.text
main:
mov r1, #2
mov r2, #3
add r3, r1, r2
cmp r1, r2
b .L2
mov sp, #4
mov lr, #6
.L2:
mov r0, #1
