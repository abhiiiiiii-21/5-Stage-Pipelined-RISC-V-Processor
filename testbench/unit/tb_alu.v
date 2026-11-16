`timescale 1ns/1ps
`include "defines.vh"
// =============================================================================
// Testbench   : tb_alu
// Description : Self-checking unit test for alu.
//               Covers all 10 operations including negative operands,
//               SLT vs SLTU on the same inputs, SRA sign fill vs SRL zero
//               fill, shifts by 0 and 31 (only b[4:0] used), the zero flag
//               and an unknown alu_ctrl code (result 0).
// Run         : iverilog -g2012 -I rtl -o simulation/build/tb_alu.vvp \
//                   rtl/alu.v testbench/unit/tb_alu.v
//               vvp simulation/build/tb_alu.vvp
// =============================================================================
module tb_alu;

    reg  [31:0] a, b;
    reg  [3:0]  alu_ctrl;
    wire [31:0] result;
    wire        zero;

    integer pass_count = 0;
    integer fail_count = 0;

    alu dut (
        .a(a), .b(b), .alu_ctrl(alu_ctrl),
        .result(result), .zero(zero)
    );

    task check(input [3:0] ctrl, input [31:0] in_a, input [31:0] in_b,
               input [31:0] exp, input exp_zero, input [511:0] name);
        begin
            a = in_a; b = in_b; alu_ctrl = ctrl; #1;
            if (result === exp && zero === exp_zero) begin
                $display("PASS: %0s (a=%h b=%h -> %h, zero=%b)", name, a, b, result, zero);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s (a=%h b=%h -> %h zero=%b, expected %h zero=%b)",
                         name, a, b, result, zero, exp, exp_zero);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("simulation/build/tb_alu.vcd");
        $dumpvars(0, tb_alu);

        // ADD
        check(`ALU_ADD, 32'd5,        32'd7,        32'd12,       0, "ADD 5+7");
        check(`ALU_ADD, 32'hFFFFFFFF, 32'd1,        32'd0,        1, "ADD -1+1 = 0 (wrap, zero=1)");
        check(`ALU_ADD, 32'hFFFFFFF6, 32'd3,        32'hFFFFFFF9, 0, "ADD -10+3 = -7");
        // SUB
        check(`ALU_SUB, 32'd20,       32'd8,        32'd12,       0, "SUB 20-8");
        check(`ALU_SUB, 32'd3,        32'd5,        32'hFFFFFFFE, 0, "SUB 3-5 = -2");
        check(`ALU_SUB, 32'd42,       32'd42,       32'd0,        1, "SUB equal -> zero");
        // Bitwise
        check(`ALU_AND, 32'hF0F0F0F0, 32'hFF00FF00, 32'hF000F000, 0, "AND");
        check(`ALU_OR,  32'hF0F0F0F0, 32'h0F0F0F0F, 32'hFFFFFFFF, 0, "OR");
        check(`ALU_XOR, 32'hAAAA5555, 32'hFFFF0000, 32'h55555555, 0, "XOR");
        check(`ALU_XOR, 32'h12345678, 32'h12345678, 32'd0,        1, "XOR same -> zero");
        // Shifts
        check(`ALU_SLL, 32'd1,        32'd4,        32'd16,       0, "SLL 1<<4");
        check(`ALU_SLL, 32'd1,        32'd31,       32'h80000000, 0, "SLL by 31");
        check(`ALU_SLL, 32'd1,        32'd33,       32'd2,        0, "SLL uses b[4:0] only (33 -> 1)");
        check(`ALU_SRL, 32'h80000000, 32'd4,        32'h08000000, 0, "SRL zero fill");
        check(`ALU_SRL, 32'h80000000, 32'd31,       32'd1,        0, "SRL by 31");
        check(`ALU_SRA, 32'h80000000, 32'd4,        32'hF8000000, 0, "SRA sign fill");
        check(`ALU_SRA, 32'h80000000, 32'd31,       32'hFFFFFFFF, 0, "SRA by 31 (negative)");
        check(`ALU_SRA, 32'h70000000, 32'd4,        32'h07000000, 0, "SRA positive (zero fill)");
        check(`ALU_SRA, 32'hF0000000, 32'd0,        32'hF0000000, 0, "SRA by 0");
        // Set-less-than: signed vs unsigned on the same inputs
        check(`ALU_SLT,  32'hFFFFFFFF, 32'd1,       32'd1,        0, "SLT  -1 < 1 (signed) = 1");
        check(`ALU_SLTU, 32'hFFFFFFFF, 32'd1,       32'd0,        1, "SLTU 0xFFFFFFFF < 1 (unsigned) = 0");
        check(`ALU_SLT,  32'd5,        32'd3,       32'd0,        1, "SLT  5 < 3 = 0");
        check(`ALU_SLTU, 32'd3,        32'd5,       32'd1,        0, "SLTU 3 < 5 = 1");
        check(`ALU_SLT,  32'hFFFFFFF6, 32'hFFFFFFFB, 32'd1,       0, "SLT  -10 < -5 = 1");
        check(`ALU_SLT,  32'd7,        32'd7,       32'd0,        1, "SLT  equal = 0");
        // Unknown code
        check(4'd15,    32'd123,      32'd456,      32'd0,        1, "unknown alu_ctrl -> 0");

        $display("--------------------------------------------");
        $display("tb_alu SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("RESULT: PASS");
        else                 $display("RESULT: FAIL");
        $finish;
    end

endmodule
