`timescale 1ns/1ps
`include "defines.vh"
// =============================================================================
// Testbench   : tb_imm_gen
// Description : Self-checking unit test for imm_gen.
//               Uses real RV32I machine-code words (positive and negative
//               immediates) for every format: I (ALU, load, JALR, shift),
//               S, B (forward and backward), U and J, plus an R-type word
//               that must give 0.
// Run         : iverilog -g2012 -I rtl -o simulation/build/tb_imm_gen.vvp \
//                   rtl/imm_gen.v testbench/unit/tb_imm_gen.v
//               vvp simulation/build/tb_imm_gen.vvp
// =============================================================================
module tb_imm_gen;

    reg  [31:0] instr;
    wire [31:0] imm;

    integer pass_count = 0;
    integer fail_count = 0;

    imm_gen dut (
        .instr(instr),
        .imm(imm)
    );

    task check(input [31:0] word, input [31:0] exp, input [511:0] name);
        begin
            instr = word; #1;
            if (imm === exp) begin
                $display("PASS: %0s (instr 0x%08h -> imm 0x%08h)", name, word, imm);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s (instr 0x%08h -> imm 0x%08h, expected 0x%08h)",
                         name, word, imm, exp);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("simulation/build/tb_imm_gen.vcd");
        $dumpvars(0, tb_imm_gen);

        // I-type (ALU)
        check(32'hFFB00093, 32'hFFFF_FFFB, "I  addi x1,x0,-5");
        check(32'h06400113, 32'h0000_0064, "I  addi x2,x0,100");
        check(32'h4030D213, 32'h0000_0403, "I  srai x4,x1,3 (shamt in [4:0])");
        // I-type (load, JALR)
        check(32'h0080A183, 32'h0000_0008, "I  lw x3,8(x1)");
        check(32'hFFC100E7, 32'hFFFF_FFFC, "I  jalr x1,-4(x2)");
        // S-type
        check(32'h00512623, 32'h0000_000C, "S  sw x5,12(x2)");
        check(32'hFE512C23, 32'hFFFF_FFF8, "S  sw x5,-8(x2)");
        // B-type
        check(32'h00209863, 32'h0000_0010, "B  bne x1,x2,+16 (forward)");
        check(32'hFE208CE3, 32'hFFFF_FFF8, "B  beq x1,x2,-8 (backward)");
        // U-type
        check(32'h123452B7, 32'h1234_5000, "U  lui x5,0x12345");
        check(32'hFFFFF337, 32'hFFFF_F000, "U  lui x6,0xFFFFF");
        // J-type
        check(32'h008000EF, 32'h0000_0008, "J  jal x1,+8");
        check(32'hFFDFF06F, 32'hFFFF_FFFC, "J  jal x0,-4 (backward)");
        // R-type and NOP
        check(32'h002081B3, 32'h0000_0000, "R  add x3,x1,x2 -> 0");
        check(`NOP,         32'h0000_0000, "I  nop (addi x0,x0,0)");

        $display("--------------------------------------------");
        $display("tb_imm_gen SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("RESULT: PASS");
        else                 $display("RESULT: FAIL");
        $finish;
    end

endmodule
