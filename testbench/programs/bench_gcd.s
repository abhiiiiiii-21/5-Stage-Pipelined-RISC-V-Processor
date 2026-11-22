# bench_gcd: subtraction-based greatest common divisor.
# Computes gcd(a, b) by repeated subtraction (while a != b: subtract the smaller
# from the larger) for six pairs and stores the results at byte 0x100..0x114:
#   gcd(48, 18) = 6, gcd(1071, 462) = 21, gcd(270, 192) = 6,
#   gcd(144, 89) = 1, gcd(1000, 7) = 1, gcd(1764, 1260) = 252.
# Hazards: branch heavy (BEQ and BLT every iteration, both directions taken),
# branch operands produced by the instruction just before (forwarding into the
# branch unit in EX), JAL/JALR calls.
# Registers: x1 link, x10 a / result, x11 b, x20 result pointer.
        addi x20, x0, 0x100
        addi x10, x0, 48
        addi x11, x0, 18
        jal  x1, gcd
        sw   x10, 0(x20)
        addi x10, x0, 1071
        addi x11, x0, 462
        jal  x1, gcd
        sw   x10, 4(x20)
        addi x10, x0, 270
        addi x11, x0, 192
        jal  x1, gcd
        sw   x10, 8(x20)
        addi x10, x0, 144
        addi x11, x0, 89
        jal  x1, gcd
        sw   x10, 12(x20)
        addi x10, x0, 1000
        addi x11, x0, 7
        jal  x1, gcd
        sw   x10, 16(x20)
        addi x10, x0, 1764
        addi x11, x0, 1260
        jal  x1, gcd
        sw   x10, 20(x20)
        jal  x0, 0

# gcd(a, b) for a, b > 0, result in x10
gcd:    beq  x10, x11, gcd_end
        blt  x10, x11, b_big
        sub  x10, x10, x11      # a > b: a = a - b
        jal  x0, gcd
b_big:  sub  x11, x11, x10      # b > a: b = b - a
        jal  x0, gcd
gcd_end:
        jalr x0, 0(x1)
