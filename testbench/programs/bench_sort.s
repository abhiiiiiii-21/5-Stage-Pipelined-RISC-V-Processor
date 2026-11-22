# bench_sort: bubble sort of 16 signed words.
# Generates 16 pseudo-random words with xorshift32 (x ^= x << 13;
# x ^= x >> 17; x ^= x << 5, seed 0x12345678) directly into byte 0x100..0x13C,
# then sorts them in place in ascending signed order (BLT/BGE compare signed).
# Hazards: load-use stall (lw then a compare on the loaded value), branches that
# are taken or not taken depending on the data, stores right after loads,
# LUI followed by a dependent ADDI, long forwarding chains in the generator.
# Registers: x5 state, x6 temp, x7 pointer, x8 counter, x10 outer limit,
#            x11 inner pointer, x12 end pointer, x13 a[j], x14 a[j+1].
        lui  x5, 0x12345
        addi x5, x5, 0x678      # seed 0x12345678
        addi x7, x0, 0x100      # array base
        addi x8, x0, 16
gen:    slli x6, x5, 13
        xor  x5, x5, x6
        srli x6, x5, 17
        xor  x5, x5, x6
        slli x6, x5, 5
        xor  x5, x5, x6
        sw   x5, 0(x7)
        addi x7, x7, 4
        addi x8, x8, -1
        bne  x8, x0, gen

        # for (end = base + 60; end > base; end -= 4)
        #   for (p = base; p < end; p += 4)
        #     if (a[p] > a[p+4]) swap
        addi x10, x0, 0x100     # base
        addi x12, x0, 0x13c     # address of the last element
outer:  addi x11, x0, 0x100
inner:  lw   x13, 0(x11)
        lw   x14, 4(x11)
        bge  x14, x13, noswap   # load-use: x14 is needed right after its lw
        sw   x14, 0(x11)
        sw   x13, 4(x11)
noswap: addi x11, x11, 4
        blt  x11, x12, inner
        addi x12, x12, -4
        blt  x10, x12, outer
        jal  x0, 0
