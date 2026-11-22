# bench_mul: shift-and-add multiplication (the subset has no MUL).
# For each pair computes the low 32 bits of a * b: while b != 0 { if (b & 1)
# p += a; a <<= 1; b >>= 1 (logical) }. A negative b runs all 32 bits, so the
# result is still the correct product modulo 2^32. Results at byte 0x100..0x114:
#   12345 * 6789 = 83810205        65535 * 65537 = 0xffffffff
#   -25 * 40 = -1000               7 * -3 = -21
#   0x1234 * 0 = 0                 1000 * 1000 = 1000000
# Hazards: ALU chain (andi then beq on its result: forwarding into the branch
# unit), data-dependent branches, LUI + ADDI constant building, JAL/JALR calls.
# Registers: x1 link, x10 a / product, x11 b, x12 product, x13 bit,
#            x20 result pointer.
        addi x20, x0, 0x100
        lui  x10, 0x3
        addi x10, x10, 0x039    # 12345
        lui  x11, 0x2
        addi x11, x11, -1403    # 6789
        jal  x1, mul
        sw   x10, 0(x20)
        lui  x10, 0x10
        addi x10, x10, -1       # 65535
        lui  x11, 0x10
        addi x11, x11, 1        # 65537
        jal  x1, mul
        sw   x10, 4(x20)
        addi x10, x0, -25
        addi x11, x0, 40
        jal  x1, mul
        sw   x10, 8(x20)
        addi x10, x0, 7
        addi x11, x0, -3
        jal  x1, mul
        sw   x10, 12(x20)
        lui  x10, 0x1
        addi x10, x10, 0x234    # 0x1234
        addi x11, x0, 0
        jal  x1, mul
        sw   x10, 16(x20)
        addi x10, x0, 1000
        addi x11, x0, 1000
        jal  x1, mul
        sw   x10, 20(x20)
        jal  x0, 0

# mul(a = x10, b = x11): product in x10
mul:    addi x12, x0, 0
mul_lp: beq  x11, x0, mul_end
        andi x13, x11, 1
        beq  x13, x0, skip
        add  x12, x12, x10
skip:   slli x10, x10, 1
        srli x11, x11, 1
        jal  x0, mul_lp
mul_end:
        addi x10, x12, 0
        jalr x0, 0(x1)
