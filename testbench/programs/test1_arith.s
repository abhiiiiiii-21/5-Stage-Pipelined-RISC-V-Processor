# Arithmetic and logical RV32I coverage.
lui  x1, 0x12345
addi x2, x0, 5
addi x3, x0, 3
add  x4, x2, x3
sub  x5, x2, x3
and  x6, x2, x3
or   x7, x2, x3
xor  x8, x2, x3
sll  x9, x2, x3
srl  x10, x2, x3
sra  x11, x2, x3
slt  x12, x2, x3
sltu x13, x2, x3
addi x14, x2, -2
andi x15, x2, 15
ori  x16, x2, 15
xori x17, x2, 15
slli x18, x2, 2
srli x19, x2, 2
srai x20, x2, 2
jal  x0, 0
