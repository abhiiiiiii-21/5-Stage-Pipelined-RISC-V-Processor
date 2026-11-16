addi x1, x0, 1
addi x2, x0, 1
beq  x1, x2, 8
addi x3, x0, 99
beq  x0, x0, 8
addi x4, x0, 7
blt  x1, x2, 8
addi x5, x0, 8
blt  x2, x1, 8
addi x6, x0, 9
jal  x7, 8
addi x8, x0, 99
jalr x9, 0(x7)
jal  x0, 0
