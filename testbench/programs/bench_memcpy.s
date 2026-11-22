# bench_memcpy: copy 64 words, then checksum the copy.
# Fills src[i] (byte 0x200..0x2FC) with v(0) = 1, v(i+1) = 5*v(i) + 0x3039
# (5*v computed as (v << 2) + v, mod 2^32), copies the 64 words to dst
# (byte 0x400..0x4FC), then sums and XORs the destination words and stores
# sum at byte 0x100 and xor at byte 0x104.
# Hazards: load/store heavy; every copied word is stored right after its load
# (load-use stall on the store data), every checksum step uses the word loaded
# just before (load-use stall), pointer updates forwarded to the next access.
# Registers: x5 src pointer, x6 dst pointer, x7 counter, x8 value / loaded word,
#            x9 temp, x10 sum, x11 xor, x12 constant 0x3039.
        addi x5, x0, 0x200
        addi x7, x0, 64
        addi x8, x0, 1          # v(0)
        lui  x12, 0x3
        addi x12, x12, 0x039    # 0x3039
fill:   sw   x8, 0(x5)
        slli x9, x8, 2
        add  x8, x9, x8         # 5 * v
        add  x8, x8, x12        # + 0x3039
        addi x5, x5, 4
        addi x7, x7, -1
        bne  x7, x0, fill

        addi x5, x0, 0x200      # src
        addi x6, x0, 0x400      # dst
        addi x7, x0, 64
copy:   lw   x8, 0(x5)
        sw   x8, 0(x6)          # load-use: store data comes from the lw
        addi x5, x5, 4
        addi x6, x6, 4
        addi x7, x7, -1
        bne  x7, x0, copy

        addi x6, x0, 0x400
        addi x7, x0, 64
        addi x10, x0, 0         # sum
        addi x11, x0, 0         # xor
check:  lw   x8, 0(x6)
        add  x10, x10, x8       # load-use
        xor  x11, x11, x8
        addi x6, x6, 4
        addi x7, x7, -1
        bne  x7, x0, check

        sw   x10, 0x100(x0)
        sw   x11, 0x104(x0)
        jal  x0, 0
