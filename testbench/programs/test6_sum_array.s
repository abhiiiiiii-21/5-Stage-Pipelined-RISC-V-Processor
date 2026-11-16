addi x1, x0, 1
addi x2, x0, 2
addi x3, x0, 3
addi x4, x0, 4
addi x5, x0, 5
sw x1, 0(x0)
sw x2, 4(x0)
sw x3, 8(x0)
sw x4, 12(x0)
sw x5, 16(x0)
addi x6, x0, 0
addi x7, x0, 5
addi x8, x0, 0
lw x9, 0(x6)
add x8, x8, x9
addi x6, x6, 4
addi x7, x7, -1
bne x7, x0, -16
sw x8, 20(x0)
jal x0, 0
