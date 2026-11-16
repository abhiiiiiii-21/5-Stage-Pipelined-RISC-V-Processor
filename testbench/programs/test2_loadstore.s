addi x1, x0, 10
addi x2, x0, 20
sw   x1, 0(x0)
sw   x2, 4(x0)
lw   x3, 0(x0)
lw   x4, 4(x0)
jal  x0, 0
