`timescale 1ns/1ps
// =============================================================================
// Module      : id_ex_reg
// Stage       : ID/EX pipeline register
// Description : Carries the decoded instruction from the ID stage to the EX
//               stage: control signals, PC, register values, immediate,
//               register addresses (used by the forwarding and hazard units)
//               and the funct3 / funct7[5] fields (used by alu_control and
//               branch_unit).
//               - rst or flush : every output becomes 0. All-zero control
//                 signals form a "bubble" (no register write, no memory
//                 access, no branch/jump), so the instruction is cancelled.
//                 flush is raised by the hazard unit for a load-use stall
//                 and for a taken branch/jump.
//               - otherwise    : latch all id_* inputs on the rising edge.
//               There is no enable: during a stall the ID instruction is
//               held in IF/ID and a bubble is inserted here instead.
// Ports       : clk, rst - clock, synchronous active-high reset
//               flush    - insert bubble (id_ex_flush from hazard_unit)
//               id_*     - values from the ID stage
//               ex_*     - same values for the EX stage
// =============================================================================
module id_ex_reg (
    input             clk,
    input             rst,
    input             flush,
    // control in
    input             id_reg_write,
    input             id_mem_read,
    input             id_mem_write,
    input             id_mem_to_reg,
    input             id_alu_src,
    input      [1:0]  id_alu_op,
    input             id_branch,
    input             id_jump,
    input             id_jalr,
    input             id_lui,
    // data in
    input      [31:0] id_pc,
    input      [31:0] id_rd1,
    input      [31:0] id_rd2,
    input      [31:0] id_imm,
    input      [4:0]  id_rs1,
    input      [4:0]  id_rs2,
    input      [4:0]  id_rd,
    input      [2:0]  id_funct3,
    input             id_funct7b5,
    // control out
    output reg        ex_reg_write,
    output reg        ex_mem_read,
    output reg        ex_mem_write,
    output reg        ex_mem_to_reg,
    output reg        ex_alu_src,
    output reg [1:0]  ex_alu_op,
    output reg        ex_branch,
    output reg        ex_jump,
    output reg        ex_jalr,
    output reg        ex_lui,
    // data out
    output reg [31:0] ex_pc,
    output reg [31:0] ex_rd1,
    output reg [31:0] ex_rd2,
    output reg [31:0] ex_imm,
    output reg [4:0]  ex_rs1,
    output reg [4:0]  ex_rs2,
    output reg [4:0]  ex_rd,
    output reg [2:0]  ex_funct3,
    output reg        ex_funct7b5
);

    always @(posedge clk) begin
        if (rst || flush) begin
            // Bubble: all control and data cleared
            ex_reg_write  <= 1'b0;
            ex_mem_read   <= 1'b0;
            ex_mem_write  <= 1'b0;
            ex_mem_to_reg <= 1'b0;
            ex_alu_src    <= 1'b0;
            ex_alu_op     <= 2'b00;
            ex_branch     <= 1'b0;
            ex_jump       <= 1'b0;
            ex_jalr       <= 1'b0;
            ex_lui        <= 1'b0;
            ex_pc         <= 32'd0;
            ex_rd1        <= 32'd0;
            ex_rd2        <= 32'd0;
            ex_imm        <= 32'd0;
            ex_rs1        <= 5'd0;
            ex_rs2        <= 5'd0;
            ex_rd         <= 5'd0;
            ex_funct3     <= 3'd0;
            ex_funct7b5   <= 1'b0;
        end else begin
            ex_reg_write  <= id_reg_write;
            ex_mem_read   <= id_mem_read;
            ex_mem_write  <= id_mem_write;
            ex_mem_to_reg <= id_mem_to_reg;
            ex_alu_src    <= id_alu_src;
            ex_alu_op     <= id_alu_op;
            ex_branch     <= id_branch;
            ex_jump       <= id_jump;
            ex_jalr       <= id_jalr;
            ex_lui        <= id_lui;
            ex_pc         <= id_pc;
            ex_rd1        <= id_rd1;
            ex_rd2        <= id_rd2;
            ex_imm        <= id_imm;
            ex_rs1        <= id_rs1;
            ex_rs2        <= id_rs2;
            ex_rd         <= id_rd;
            ex_funct3     <= id_funct3;
            ex_funct7b5   <= id_funct7b5;
        end
    end

endmodule
