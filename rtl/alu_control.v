`timescale 1ns/1ps
`include "defines.vh"
// =============================================================================
// Module      : alu_control
// Stage       : EX
// Description : Second-level ALU decoder. Converts the 2-bit alu_op from the
//               main control unit plus the instruction's funct3 and funct7[5]
//               into the 4-bit alu_ctrl code used by the ALU.
//                 alu_op 00 (LW/SW/LUI)  -> ADD
//                 alu_op 01 (branch)     -> SUB (decision made in branch_unit)
//                 alu_op 10 (R-type)     -> by funct3; funct7[5] selects
//                                           SUB vs ADD and SRA vs SRL
//                 alu_op 11 (I-type ALU) -> by funct3; funct3=000 is always
//                                           ADDI (bit 30 is part of the
//                                           immediate, never SUB); funct7[5]
//                                           only selects SRAI vs SRLI
// Ports       : alu_op   - from control_unit (via ID/EX)
//               funct3   - instr[14:12]
//               funct7b5 - instr[30]
//               alu_ctrl - operation code for alu
// =============================================================================
module alu_control (
    input      [1:0] alu_op,
    input      [2:0] funct3,
    input            funct7b5,
    output reg [3:0] alu_ctrl
);

    always @(*) begin
        case (alu_op)
            `ALUOP_ADD:    alu_ctrl = `ALU_ADD;
            `ALUOP_BRANCH: alu_ctrl = `ALU_SUB;
            `ALUOP_RTYPE: begin
                case (funct3)
                    3'b000:  alu_ctrl = funct7b5 ? `ALU_SUB : `ALU_ADD;
                    3'b001:  alu_ctrl = `ALU_SLL;
                    3'b010:  alu_ctrl = `ALU_SLT;
                    3'b011:  alu_ctrl = `ALU_SLTU;
                    3'b100:  alu_ctrl = `ALU_XOR;
                    3'b101:  alu_ctrl = funct7b5 ? `ALU_SRA : `ALU_SRL;
                    3'b110:  alu_ctrl = `ALU_OR;
                    default: alu_ctrl = `ALU_AND;   // 3'b111
                endcase
            end
            default: begin // `ALUOP_ITYPE
                case (funct3)
                    3'b000:  alu_ctrl = `ALU_ADD;   // ADDI: ignore funct7b5
                    3'b001:  alu_ctrl = `ALU_SLL;
                    3'b010:  alu_ctrl = `ALU_SLT;
                    3'b011:  alu_ctrl = `ALU_SLTU;
                    3'b100:  alu_ctrl = `ALU_XOR;
                    3'b101:  alu_ctrl = funct7b5 ? `ALU_SRA : `ALU_SRL;
                    3'b110:  alu_ctrl = `ALU_OR;
                    default: alu_ctrl = `ALU_AND;   // 3'b111
                endcase
            end
        endcase
    end

endmodule
