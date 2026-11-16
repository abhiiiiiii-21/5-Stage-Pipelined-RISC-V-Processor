`timescale 1ns/1ps
// =============================================================================
// Module      : ex_stage
// Stage       : EX
// Description : Execute stage wrapper. Contains:
//               1. Forwarding muxes for both register operands
//                    2'b10 -> mem_fwd_data (EX/MEM result, highest priority)
//                    2'b01 -> wb_data      (MEM/WB write-back value)
//                    2'b00 -> ex_rd1/ex_rd2 (value read in ID)
//               2. ALU operand muxes
//                    alu_a = ex_lui     ? 0      : forwarded rs1  (LUI = 0 + imm)
//                    alu_b = ex_alu_src ? ex_imm : forwarded rs2
//               3. alu_control + alu
//               4. branch_unit (uses the forwarded operands)
//               ex_result is pc+4 for JAL/JALR (the link address written to
//               rd) and the ALU result otherwise. store_data is the
//               forwarded rs2 value (data written by SW).
// Ports       : ex_*                 - values from the ID/EX register
//               forward_a, forward_b - mux selects from forwarding_unit
//               mem_fwd_data         - EX/MEM result (mem_result)
//               wb_data              - write-back value from the WB mux
//               ex_result            - to EX/MEM (ALU result or pc+4)
//               store_data           - to EX/MEM (data for SW)
//               pc_src, branch_target - to the PC mux and hazard unit
// =============================================================================
module ex_stage (
    input  [31:0] ex_pc,
    input  [31:0] ex_rd1,
    input  [31:0] ex_rd2,
    input  [31:0] ex_imm,
    input  [2:0]  ex_funct3,
    input         ex_funct7b5,
    input         ex_alu_src,
    input  [1:0]  ex_alu_op,
    input         ex_branch,
    input         ex_jump,
    input         ex_jalr,
    input         ex_lui,
    input  [1:0]  forward_a,
    input  [1:0]  forward_b,
    input  [31:0] mem_fwd_data,
    input  [31:0] wb_data,
    output [31:0] ex_result,
    output [31:0] store_data,
    output        pc_src,
    output [31:0] branch_target
);

    wire [31:0] op_a_fwd, op_b_fwd;
    wire [31:0] alu_a, alu_b, alu_result;
    wire [3:0]  alu_ctrl;
    wire        alu_zero;

    // Forwarding muxes (EX/MEM has priority over MEM/WB)
    assign op_a_fwd = (forward_a == 2'b10) ? mem_fwd_data :
                      (forward_a == 2'b01) ? wb_data      : ex_rd1;
    assign op_b_fwd = (forward_b == 2'b10) ? mem_fwd_data :
                      (forward_b == 2'b01) ? wb_data      : ex_rd2;

    // ALU operand selection
    assign alu_a = ex_lui     ? 32'd0  : op_a_fwd;
    assign alu_b = ex_alu_src ? ex_imm : op_b_fwd;

    alu_control u_alu_control (
        .alu_op   (ex_alu_op),
        .funct3   (ex_funct3),
        .funct7b5 (ex_funct7b5),
        .alu_ctrl (alu_ctrl)
    );

    alu u_alu (
        .a        (alu_a),
        .b        (alu_b),
        .alu_ctrl (alu_ctrl),
        .result   (alu_result),
        .zero     (alu_zero)
    );

    branch_unit u_branch_unit (
        .branch        (ex_branch),
        .jump          (ex_jump),
        .jalr          (ex_jalr),
        .funct3        (ex_funct3),
        .rs1_val       (op_a_fwd),
        .rs2_val       (op_b_fwd),
        .pc            (ex_pc),
        .imm           (ex_imm),
        .pc_src        (pc_src),
        .branch_target (branch_target)
    );

    assign store_data = op_b_fwd;
    assign ex_result  = (ex_jump | ex_jalr) ? (ex_pc + 32'd4) : alu_result;

endmodule
