# bench_sum: sum of a 32-element array.
# Fills a[i] = 13*i + 5 (i = 0..31) at byte 0x200 with a running value, then
# sums the array in a second loop and stores the sum (6608) at byte 0x100 and
# the element count (32) at byte 0x104.
# Hazards: load-use stall on every element (lw followed by a dependent add),
# forwarding of the running sum and pointer, a taken BNE per iteration.
# Registers: x5 pointer, x6 counter, x7 value, x8 sum, x9 loaded element.
        addi x5, x0, 0x200      # array base
        addi x6, x0, 32         # element count
        addi x7, x0, 5          # a[0] = 5
fill:   sw   x7, 0(x5)
        addi x7, x7, 13         # next value
        addi x5, x5, 4
        addi x6, x6, -1
        bne  x6, x0, fill

        addi x5, x0, 0x200
        addi x6, x0, 32
        addi x8, x0, 0          # sum
sum:    lw   x9, 0(x5)
        add  x8, x8, x9         # load-use: needs x9 from the lw above
        addi x5, x5, 4
        addi x6, x6, -1
        bne  x6, x0, sum

        sw   x8, 0x100(x0)      # sum
        addi x10, x0, 32
        sw   x10, 0x104(x0)     # count
        jal  x0, 0
