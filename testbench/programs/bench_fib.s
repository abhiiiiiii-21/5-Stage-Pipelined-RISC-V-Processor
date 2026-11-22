# bench_fib: iterative Fibonacci.
# Computes fib(n) for n = 1, 10, 20, 30, 40, 46 (fib(0) = 0, fib(1) = 1) with a
# subroutine called through JAL and returning through JALR, and stores the six
# results at byte 0x100..0x114. fib(46) = 1836311903 is the largest value that
# fits in a signed 32-bit word.
# Hazards: back-to-back ALU dependences in the loop body (EX/MEM and MEM/WB
# forwarding), a taken BNE every iteration, JAL/JALR on every call (flushes).
# Registers: x1 link, x10 argument n / result, x11 a, x12 b, x13 temp,
#            x20 result pointer.
        addi x20, x0, 0x100     # result pointer
        addi x10, x0, 1
        jal  x1, fib
        sw   x10, 0(x20)
        addi x10, x0, 10
        jal  x1, fib
        sw   x10, 4(x20)
        addi x10, x0, 20
        jal  x1, fib
        sw   x10, 8(x20)
        addi x10, x0, 30
        jal  x1, fib
        sw   x10, 12(x20)
        addi x10, x0, 40
        jal  x1, fib
        sw   x10, 16(x20)
        addi x10, x0, 46
        jal  x1, fib
        sw   x10, 20(x20)
halt:   jal  x0, 0

# fib(n): a = 0, b = 1; repeat n times { t = a + b; a = b; b = t }; return a
fib:    addi x11, x0, 0
        addi x12, x0, 1
        beq  x10, x0, fib_end
fib_lp: add  x13, x11, x12
        addi x11, x12, 0
        addi x12, x13, 0
        addi x10, x10, -1
        bne  x10, x0, fib_lp
fib_end:
        addi x10, x11, 0
        jalr x0, 0(x1)
