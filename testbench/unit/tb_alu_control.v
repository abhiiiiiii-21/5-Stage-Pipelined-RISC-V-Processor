`timescale 1ns/1ps
`include "defines.vh"
// =============================================================================
// Testbench   : tb_alu_control
// Description : Self-checking unit test for alu_control.
//               Checks the alu_ctrl code for every instruction of the ISA
//               subset: LW/SW/LUI/JAL/JALR (alu_op 00), branches (01),
//               all R-type (10) and I-type ALU (11) instructions.
//               Special cases: ADD vs SUB, ADDI with instr[30]=1 must stay
//               ADD (negative immediate), SRAI vs SRLI, SRA vs SRL.
// Run         : iverilog -g2012 -I rtl -o simulation/build/tb_alu_control.vvp \
//                   rtl/alu_control.v testbench/unit/tb_alu_control.v
//               vvp simulation/build/tb_alu_control.vvp
// =============================================================================
module tb_alu_control;

    reg  [1:0] alu_op;
    reg  [2:0] funct3;
    reg        funct7b5;
    wire [3:0] alu_ctrl;

    integer pass_count = 0;
    integer fail_count = 0;

    alu_control dut (
        .alu_op(alu_op), .funct3(funct3), .funct7b5(funct7b5),
        .alu_ctrl(alu_ctrl)
    );

    task check(input [1:0] op, input [2:0] f3, input f7b5,
               input [3:0] exp, input [511:0] name);
        begin
            alu_op = op; funct3 = f3; funct7b5 = f7b5; #1;
            if (alu_ctrl === exp) begin
                $display("PASS: %0s (alu_op=%b f3=%b f7b5=%b -> %0d)",
                         name, op, f3, f7b5, alu_ctrl);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s (alu_op=%b f3=%b f7b5=%b -> %0d, expected %0d)",
                         name, op, f3, f7b5, alu_ctrl, exp);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("simulation/build/tb_alu_control.vcd");
        $dumpvars(0, tb_alu_control);

        // alu_op 00: address / LUI -> ADD regardless of funct fields
        check(`ALUOP_ADD,    3'b010, 1'b0, `ALU_ADD,  "LW  (address add)");
        check(`ALUOP_ADD,    3'b010, 1'b0, `ALU_ADD,  "SW  (address add)");
        check(`ALUOP_ADD,    3'b101, 1'b1, `ALU_ADD,  "LUI (random funct bits) -> ADD");

        // alu_op 01: branch -> SUB
        check(`ALUOP_BRANCH, 3'b000, 1'b0, `ALU_SUB,  "BEQ");
        check(`ALUOP_BRANCH, 3'b001, 1'b0, `ALU_SUB,  "BNE");
        check(`ALUOP_BRANCH, 3'b100, 1'b0, `ALU_SUB,  "BLT");
        check(`ALUOP_BRANCH, 3'b101, 1'b0, `ALU_SUB,  "BGE");

        // alu_op 10: R-type
        check(`ALUOP_RTYPE,  3'b000, 1'b0, `ALU_ADD,  "ADD");
        check(`ALUOP_RTYPE,  3'b000, 1'b1, `ALU_SUB,  "SUB");
        check(`ALUOP_RTYPE,  3'b001, 1'b0, `ALU_SLL,  "SLL");
        check(`ALUOP_RTYPE,  3'b010, 1'b0, `ALU_SLT,  "SLT");
        check(`ALUOP_RTYPE,  3'b011, 1'b0, `ALU_SLTU, "SLTU");
        check(`ALUOP_RTYPE,  3'b100, 1'b0, `ALU_XOR,  "XOR");
        check(`ALUOP_RTYPE,  3'b101, 1'b0, `ALU_SRL,  "SRL");
        check(`ALUOP_RTYPE,  3'b101, 1'b1, `ALU_SRA,  "SRA");
        check(`ALUOP_RTYPE,  3'b110, 1'b0, `ALU_OR,   "OR");
        check(`ALUOP_RTYPE,  3'b111, 1'b0, `ALU_AND,  "AND");

        // alu_op 11: I-type ALU
        check(`ALUOP_ITYPE,  3'b000, 1'b0, `ALU_ADD,  "ADDI");
        check(`ALUOP_ITYPE,  3'b000, 1'b1, `ALU_ADD,  "ADDI with instr[30]=1 stays ADD");
        check(`ALUOP_ITYPE,  3'b001, 1'b0, `ALU_SLL,  "SLLI");
        check(`ALUOP_ITYPE,  3'b010, 1'b0, `ALU_SLT,  "SLTI");
        check(`ALUOP_ITYPE,  3'b011, 1'b0, `ALU_SLTU, "SLTIU");
        check(`ALUOP_ITYPE,  3'b100, 1'b0, `ALU_XOR,  "XORI");
        check(`ALUOP_ITYPE,  3'b101, 1'b0, `ALU_SRL,  "SRLI");
        check(`ALUOP_ITYPE,  3'b101, 1'b1, `ALU_SRA,  "SRAI");
        check(`ALUOP_ITYPE,  3'b110, 1'b0, `ALU_OR,   "ORI");
        check(`ALUOP_ITYPE,  3'b111, 1'b0, `ALU_AND,  "ANDI");

        $display("--------------------------------------------");
        $display("tb_alu_control SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("RESULT: PASS");
        else                 $display("RESULT: FAIL");
        $finish;
    end

endmodule
