`timescale 1ns/1ps
`include "defines.vh"
// =============================================================================
// Module      : riscv_single_cycle_top
// Description : Single-cycle RV32I (subset) processor. It is the baseline the
//               5-stage pipeline is compared against. Every instruction is
//               fetched, decoded, executed, accesses memory and writes back
//               in ONE clock cycle, so CPI = 1 by construction, but the clock
//               period must cover the whole path:
//                 pc -> instr_mem -> reg_file -> alu -> data_mem -> reg_file
//
//               It reuses the pipeline's modules unchanged (pc_reg, instr_mem,
//               control_unit, imm_gen, alu_control, alu, branch_unit,
//               data_mem). The register file is reg_file_nobypass: the same
//               32 x 32 array without the write-first bypass, which is only
//               needed by the pipeline and would create a combinational loop
//               here. There are no pipeline registers, no forwarding unit and
//               no hazard unit: with one instruction in flight there are no
//               hazards.
//
// Parameters  : IMEM_FILE - hex program loaded into instruction memory
// Ports       : clk     - system clock
//               rst     - synchronous active-high reset
//               dbg_out - write-back data, an observation output so that
//                         synthesis tools keep the design (unused in simulation)
// Debug       : testbenches read dut.u_reg_file.regs[i] and dut.u_dmem.mem[i]
//               (same instance names as riscv_pipeline_top)
// =============================================================================
module riscv_single_cycle_top #(
    parameter IMEM_FILE = ""
) (
    input         clk,
    input         rst,
    output [31:0] dbg_out
);

    // ---- fetch ----
    wire [31:0] pc;
    wire [31:0] pc_next;
    wire [31:0] instr;

    // ---- instruction fields ----
    wire [6:0]  opcode   = instr[6:0];
    wire [4:0]  rd       = instr[11:7];
    wire [2:0]  funct3   = instr[14:12];
    wire [4:0]  rs1      = instr[19:15];
    wire [4:0]  rs2      = instr[24:20];
    wire        funct7b5 = instr[30];

    // ---- control ----
    wire        reg_write, mem_read, mem_write, mem_to_reg, alu_src;
    wire [1:0]  alu_op;
    wire        branch, jump, jalr, lui;

    // ---- datapath ----
    wire [31:0] imm;
    wire [31:0] rd1, rd2;
    wire [31:0] alu_a, alu_b, alu_result;
    wire [3:0]  alu_ctrl;
    wire        alu_zero;
    wire        pc_src;
    wire [31:0] branch_target;
    wire [31:0] mem_rdata;
    wire [31:0] wb_data;

    // Next PC: branch/jump target when taken, otherwise pc + 4
    assign pc_next = pc_src ? branch_target : (pc + 32'd4);

    pc_reg u_pc (
        .clk     (clk),
        .rst     (rst),
        .en      (1'b1),
        .pc_next (pc_next),
        .pc      (pc)
    );

    instr_mem #(
        .MEM_FILE (IMEM_FILE),
        .DEPTH    (1024)
    ) u_imem (
        .addr  (pc),
        .instr (instr)
    );

    control_unit u_control (
        .opcode     (opcode),
        .reg_write  (reg_write),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .mem_to_reg (mem_to_reg),
        .alu_src    (alu_src),
        .alu_op     (alu_op),
        .branch     (branch),
        .jump       (jump),
        .jalr       (jalr),
        .lui        (lui)
    );

    imm_gen u_imm_gen (
        .instr (instr),
        .imm   (imm)
    );

    // No write-first bypass here: see reg_file_nobypass.v for the reason
    reg_file_nobypass u_reg_file (
        .clk (clk),
        .rst (rst),
        .we  (reg_write),
        .rs1 (rs1),
        .rs2 (rs2),
        .rd  (rd),
        .wd  (wb_data),
        .rd1 (rd1),
        .rd2 (rd2)
    );

    // ALU operands: LUI forces operand A to 0 so the ALU computes 0 + imm
    assign alu_a = lui     ? 32'd0 : rd1;
    assign alu_b = alu_src ? imm   : rd2;

    alu_control u_alu_ctrl (
        .alu_op   (alu_op),
        .funct3   (funct3),
        .funct7b5 (funct7b5),
        .alu_ctrl (alu_ctrl)
    );

    alu u_alu (
        .a        (alu_a),
        .b        (alu_b),
        .alu_ctrl (alu_ctrl),
        .result   (alu_result),
        .zero     (alu_zero)
    );

    // Branch/jump decision uses the raw register values (no forwarding needed)
    branch_unit u_branch (
        .branch        (branch),
        .jump          (jump),
        .jalr          (jalr),
        .funct3        (funct3),
        .rs1_val       (rd1),
        .rs2_val       (rd2),
        .pc            (pc),
        .imm           (imm),
        .pc_src        (pc_src),
        .branch_target (branch_target)
    );

    data_mem #(
        .DEPTH (1024)
    ) u_dmem (
        .clk       (clk),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .addr      (alu_result),
        .wdata     (rd2),
        .rdata     (mem_rdata)
    );

    // Write-back: loaded data, link address (pc + 4) for JAL/JALR, or ALU result
    assign wb_data = mem_to_reg      ? mem_rdata :
                     (jump | jalr)   ? (pc + 32'd4) :
                                       alu_result;

    assign dbg_out = wb_data;

endmodule
