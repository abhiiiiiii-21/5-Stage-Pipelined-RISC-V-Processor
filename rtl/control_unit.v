`timescale 1ns/1ps
`include "defines.vh"
// =============================================================================
// Module      : control_unit
// Stage       : ID (Instruction Decode)
// Description : Main control unit. Decodes the 7-bit opcode into the control
//               signals that travel down the pipeline with the instruction.
//               Purely combinational. Every output defaults to 0, so an
//               unsupported opcode behaves like a NOP (writes nothing).
//
//   Opcode | reg_write mem_read mem_write mem_to_reg alu_src alu_op branch jump jalr lui
//   R      |     1        0        0         0         0      10     0     0    0    0
//   I-ALU  |     1        0        0         0         1      11     0     0    0    0
//   LOAD   |     1        1        0         1         1      00     0     0    0    0
//   STORE  |     0        0        1         0         1      00     0     0    0    0
//   BRANCH |     0        0        0         0         0      01     1     0    0    0
//   JAL    |     1        0        0         0         0      00     0     1    0    0
//   JALR   |     1        0        0         0         1      00     0     0    1    0
//   LUI    |     1        0        0         0         1      00     0     0    0    1
//   other  |     0        0        0         0         0      00     0     0    0    0
//
// Signal meaning:
//   reg_write  - write the result into register rd in WB
//   mem_read   - read data memory in MEM (LW); also used by hazard_unit
//   mem_write  - write data memory in MEM (SW)
//   mem_to_reg - WB selects loaded data instead of ALU result
//   alu_src    - ALU operand B is the immediate (1) or rs2 (0)
//   alu_op     - class of ALU operation, decoded further by alu_control
//   branch     - conditional branch (BEQ/BNE/BLT/BGE), resolved in EX
//   jump       - JAL (target = pc + imm, writes pc + 4)
//   jalr       - JALR (target = (rs1 + imm) & ~1, writes pc + 4)
//   lui        - forces ALU operand A to 0 so result = imm
// =============================================================================
module control_unit (
    input      [6:0] opcode,
    output reg       reg_write,
    output reg       mem_read,
    output reg       mem_write,
    output reg       mem_to_reg,
    output reg       alu_src,
    output reg [1:0] alu_op,
    output reg       branch,
    output reg       jump,
    output reg       jalr,
    output reg       lui
);

    always @(*) begin
        // Safe defaults: behave like a NOP
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        alu_src    = 1'b0;
        alu_op     = `ALUOP_ADD;
        branch     = 1'b0;
        jump       = 1'b0;
        jalr       = 1'b0;
        lui        = 1'b0;

        case (opcode)
            `OP_RTYPE: begin
                reg_write = 1'b1;
                alu_op    = `ALUOP_RTYPE;
            end
            `OP_ITYPE: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = `ALUOP_ITYPE;
            end
            `OP_LOAD: begin
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
                alu_src    = 1'b1;
                alu_op     = `ALUOP_ADD;
            end
            `OP_STORE: begin
                mem_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = `ALUOP_ADD;
            end
            `OP_BRANCH: begin
                alu_op = `ALUOP_BRANCH;
                branch = 1'b1;
            end
            `OP_JAL: begin
                reg_write = 1'b1;
                jump      = 1'b1;
            end
            `OP_JALR: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                jalr      = 1'b1;
            end
            `OP_LUI: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                lui       = 1'b1;
            end
            default: ; // keep safe defaults
        endcase
    end

endmodule
