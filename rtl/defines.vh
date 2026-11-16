// =============================================================================
// File        : defines.vh
// Project     : 5-Stage Pipelined RISC-V Processor (RV32I subset)
// Description : Shared constants used by every RTL module and testbench.
//               - RV32I opcodes for the supported instruction subset
//               - 4-bit ALU control codes (output of alu_control, input of alu)
//               - 2-bit alu_op codes (output of control_unit, input of alu_control)
//               - NOP encoding used to flush / reset the IF/ID register
// Usage       : `include "defines.vh"   (compile with: iverilog -I rtl ...)
// =============================================================================
`ifndef DEFINES_VH
`define DEFINES_VH

// ---------------------------------------------------------------------------
// Opcodes (instr[6:0])
// ---------------------------------------------------------------------------
`define OP_RTYPE   7'b0110011   // ADD SUB AND OR XOR SLL SRL SRA SLT SLTU
`define OP_ITYPE   7'b0010011   // ADDI ANDI ORI XORI SLTI SLTIU SLLI SRLI SRAI
`define OP_LOAD    7'b0000011   // LW
`define OP_STORE   7'b0100011   // SW
`define OP_BRANCH  7'b1100011   // BEQ BNE BLT BGE
`define OP_JAL     7'b1101111   // JAL
`define OP_JALR    7'b1100111   // JALR
`define OP_LUI     7'b0110111   // LUI

// ---------------------------------------------------------------------------
// ALU control codes (4-bit) : alu_control -> alu
// ---------------------------------------------------------------------------
`define ALU_ADD    4'd0
`define ALU_SUB    4'd1
`define ALU_AND    4'd2
`define ALU_OR     4'd3
`define ALU_XOR    4'd4
`define ALU_SLL    4'd5
`define ALU_SRL    4'd6
`define ALU_SRA    4'd7
`define ALU_SLT    4'd8
`define ALU_SLTU   4'd9

// ---------------------------------------------------------------------------
// alu_op codes (2-bit) : control_unit -> alu_control
// ---------------------------------------------------------------------------
`define ALUOP_ADD    2'b00   // address calculation (LW/SW), LUI
`define ALUOP_BRANCH 2'b01   // branch (ALU does SUB; decision taken in branch_unit)
`define ALUOP_RTYPE  2'b10   // decode from funct3 + funct7[5]
`define ALUOP_ITYPE  2'b11   // decode from funct3 (+ funct7[5] only for SRAI/SRLI)

// ---------------------------------------------------------------------------
// Miscellaneous
// ---------------------------------------------------------------------------
`define NOP        32'h00000013  // addi x0, x0, 0

`endif // DEFINES_VH
