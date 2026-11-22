`timescale 1ns/1ps
`include "defines.vh"
// =============================================================================
// Module      : riscv_pipeline_top
// Description : Top level of the 5-stage pipelined RISC-V (RV32I subset)
//               processor. Connects all stage modules, the four pipeline
//               registers, the forwarding unit and the hazard detection unit.
//
//   IF  : pc_reg, instr_mem, next-PC mux             -> if_id_reg
//   ID  : reg_file, control_unit, imm_gen             -> id_ex_reg
//   EX  : ex_stage (fwd muxes, alu_control, alu,
//         branch_unit)                                -> ex_mem_reg
//   MEM : data_mem                                    -> mem_wb_reg
//   WB  : write-back mux -> reg_file write port
//   Hazards: forwarding_unit (EX), hazard_unit (IF/ID control)
//
// Parameters  : IMEM_FILE - hex program loaded into instruction memory
// Ports       : clk - system clock, rst - synchronous active-high reset
//               dbg_out - write-back data, an observation output so that
//               synthesis tools keep the design (unused in simulation)
// Debug       : testbenches read dut.u_reg_file.regs[i] and dut.u_dmem.mem[i]
// =============================================================================
module riscv_pipeline_top #(
    parameter IMEM_FILE = ""
) (
    input clk,
    input rst,
    output [31:0] dbg_out
);

    // =========================================================================
    // Signal declarations
    // =========================================================================

    // ---- IF stage ----
    wire [31:0] if_pc;
    wire [31:0] if_instr;
    wire [31:0] pc_next;

    // ---- ID stage ----
    wire [31:0] id_pc;
    wire [31:0] id_instr;
    wire [4:0]  id_rs1, id_rs2, id_rd;
    wire [2:0]  id_funct3;
    wire        id_funct7b5;
    wire [6:0]  id_opcode;
    wire [31:0] id_rd1, id_rd2, id_imm;
    wire        id_reg_write, id_mem_read, id_mem_write, id_mem_to_reg, id_alu_src;
    wire [1:0]  id_alu_op;
    wire        id_branch, id_jump, id_jalr, id_lui;

    // ---- EX stage ----
    wire        ex_reg_write, ex_mem_read, ex_mem_write, ex_mem_to_reg, ex_alu_src;
    wire [1:0]  ex_alu_op;
    wire        ex_branch, ex_jump, ex_jalr, ex_lui;
    wire [31:0] ex_pc, ex_rd1, ex_rd2, ex_imm;
    wire [4:0]  ex_rs1, ex_rs2, ex_rd;
    wire [2:0]  ex_funct3;
    wire        ex_funct7b5;
    wire [31:0] ex_result, ex_store_data;
    wire        pc_src;
    wire [31:0] branch_target;
    wire [1:0]  forward_a, forward_b;

    // ---- MEM stage ----
    wire        mem_reg_write, mem_mem_read, mem_mem_write, mem_mem_to_reg;
    wire [31:0] mem_result, mem_store_data;
    wire [4:0]  mem_rd;
    wire [31:0] mem_rdata;

    // ---- WB stage ----
    wire        wb_reg_write, wb_mem_to_reg;
    wire [31:0] wb_result, wb_mem_rdata;
    wire [4:0]  wb_rd;
    wire [31:0] wb_data;

    // ---- Hazard control ----
    wire        pc_write, if_id_write, if_id_flush, id_ex_flush;

    // =========================================================================
    // IF stage
    // =========================================================================

    // Next-PC mux: taken branch/jump target from EX, otherwise sequential fetch.
    assign pc_next = pc_src ? branch_target : (if_pc + 32'd4);

    pc_reg u_pc (
        .clk     (clk),
        .rst     (rst),
        .en      (pc_write),
        .pc_next (pc_next),
        .pc      (if_pc)
    );

    instr_mem #(
        .MEM_FILE (IMEM_FILE),
        .DEPTH    (1024)
    ) u_imem (
        .addr  (if_pc),
        .instr (if_instr)
    );

    if_id_reg u_if_id (
        .clk      (clk),
        .rst      (rst),
        .en       (if_id_write),
        .flush    (if_id_flush),
        .if_pc    (if_pc),
        .if_instr (if_instr),
        .id_pc    (id_pc),
        .id_instr (id_instr)
    );

    // =========================================================================
    // ID stage
    // =========================================================================

    // Instruction field extraction
    assign id_opcode   = id_instr[6:0];
    assign id_rd       = id_instr[11:7];
    assign id_funct3   = id_instr[14:12];
    assign id_rs1      = id_instr[19:15];
    assign id_rs2      = id_instr[24:20];
    assign id_funct7b5 = id_instr[30];

    // Register file: read in ID, write from WB (write-first bypass inside).
    reg_file u_reg_file (
        .clk (clk),
        .rst (rst),
        .we  (wb_reg_write),
        .rs1 (id_rs1),
        .rs2 (id_rs2),
        .rd  (wb_rd),
        .wd  (wb_data),
        .rd1 (id_rd1),
        .rd2 (id_rd2)
    );

    control_unit u_control (
        .opcode     (id_opcode),
        .reg_write  (id_reg_write),
        .mem_read   (id_mem_read),
        .mem_write  (id_mem_write),
        .mem_to_reg (id_mem_to_reg),
        .alu_src    (id_alu_src),
        .alu_op     (id_alu_op),
        .branch     (id_branch),
        .jump       (id_jump),
        .jalr       (id_jalr),
        .lui        (id_lui)
    );

    imm_gen u_imm_gen (
        .instr (id_instr),
        .imm   (id_imm)
    );

    id_ex_reg u_id_ex (
        .clk           (clk),
        .rst           (rst),
        .flush         (id_ex_flush),
        // control in
        .id_reg_write  (id_reg_write),
        .id_mem_read   (id_mem_read),
        .id_mem_write  (id_mem_write),
        .id_mem_to_reg (id_mem_to_reg),
        .id_alu_src    (id_alu_src),
        .id_alu_op     (id_alu_op),
        .id_branch     (id_branch),
        .id_jump       (id_jump),
        .id_jalr       (id_jalr),
        .id_lui        (id_lui),
        // data in
        .id_pc         (id_pc),
        .id_rd1        (id_rd1),
        .id_rd2        (id_rd2),
        .id_imm        (id_imm),
        .id_rs1        (id_rs1),
        .id_rs2        (id_rs2),
        .id_rd         (id_rd),
        .id_funct3     (id_funct3),
        .id_funct7b5   (id_funct7b5),
        // control out
        .ex_reg_write  (ex_reg_write),
        .ex_mem_read   (ex_mem_read),
        .ex_mem_write  (ex_mem_write),
        .ex_mem_to_reg (ex_mem_to_reg),
        .ex_alu_src    (ex_alu_src),
        .ex_alu_op     (ex_alu_op),
        .ex_branch     (ex_branch),
        .ex_jump       (ex_jump),
        .ex_jalr       (ex_jalr),
        .ex_lui        (ex_lui),
        // data out
        .ex_pc         (ex_pc),
        .ex_rd1        (ex_rd1),
        .ex_rd2        (ex_rd2),
        .ex_imm        (ex_imm),
        .ex_rs1        (ex_rs1),
        .ex_rs2        (ex_rs2),
        .ex_rd         (ex_rd),
        .ex_funct3     (ex_funct3),
        .ex_funct7b5   (ex_funct7b5)
    );

    // =========================================================================
    // EX stage
    // =========================================================================

    ex_stage u_ex_stage (
        .ex_pc         (ex_pc),
        .ex_rd1        (ex_rd1),
        .ex_rd2        (ex_rd2),
        .ex_imm        (ex_imm),
        .ex_funct3     (ex_funct3),
        .ex_funct7b5   (ex_funct7b5),
        .ex_alu_src    (ex_alu_src),
        .ex_alu_op     (ex_alu_op),
        .ex_branch     (ex_branch),
        .ex_jump       (ex_jump),
        .ex_jalr       (ex_jalr),
        .ex_lui        (ex_lui),
        .forward_a     (forward_a),
        .forward_b     (forward_b),
        .mem_fwd_data  (mem_result),   // EX/MEM forwarding source
        .wb_data       (wb_data),      // MEM/WB forwarding source
        .ex_result     (ex_result),
        .store_data    (ex_store_data),
        .pc_src        (pc_src),
        .branch_target (branch_target)
    );

    ex_mem_reg u_ex_mem (
        .clk            (clk),
        .rst            (rst),
        .ex_reg_write   (ex_reg_write),
        .ex_mem_read    (ex_mem_read),
        .ex_mem_write   (ex_mem_write),
        .ex_mem_to_reg  (ex_mem_to_reg),
        .ex_result      (ex_result),
        .ex_store_data  (ex_store_data),
        .ex_rd          (ex_rd),
        .mem_reg_write  (mem_reg_write),
        .mem_mem_read   (mem_mem_read),
        .mem_mem_write  (mem_mem_write),
        .mem_mem_to_reg (mem_mem_to_reg),
        .mem_result     (mem_result),
        .mem_store_data (mem_store_data),
        .mem_rd         (mem_rd)
    );

    // =========================================================================
    // MEM stage
    // =========================================================================

    data_mem #(
        .DEPTH (1024)
    ) u_dmem (
        .clk       (clk),
        .mem_read  (mem_mem_read),
        .mem_write (mem_mem_write),
        .addr      (mem_result),
        .wdata     (mem_store_data),
        .rdata     (mem_rdata)
    );

    mem_wb_reg u_mem_wb (
        .clk            (clk),
        .rst            (rst),
        .mem_reg_write  (mem_reg_write),
        .mem_mem_to_reg (mem_mem_to_reg),
        .mem_result     (mem_result),
        .mem_mem_rdata  (mem_rdata),
        .mem_rd         (mem_rd),
        .wb_reg_write   (wb_reg_write),
        .wb_mem_to_reg  (wb_mem_to_reg),
        .wb_result      (wb_result),
        .wb_mem_rdata   (wb_mem_rdata),
        .wb_rd          (wb_rd)
    );

    // =========================================================================
    // WB stage
    // =========================================================================

    // Write-back mux: loaded data for LW, otherwise ALU result / PC+4.
    assign wb_data = wb_mem_to_reg ? wb_mem_rdata : wb_result;
    assign dbg_out = wb_data;

    // =========================================================================
    // Hazard handling
    // =========================================================================

    forwarding_unit u_fwd (
        .ex_rs1        (ex_rs1),
        .ex_rs2        (ex_rs2),
        .mem_rd        (mem_rd),
        .mem_reg_write (mem_reg_write),
        .wb_rd         (wb_rd),
        .wb_reg_write  (wb_reg_write),
        .forward_a     (forward_a),
        .forward_b     (forward_b)
    );

    hazard_unit u_hazard (
        .id_rs1      (id_rs1),
        .id_rs2      (id_rs2),
        .ex_rd       (ex_rd),
        .ex_mem_read (ex_mem_read),
        .pc_src      (pc_src),
        .pc_write    (pc_write),
        .if_id_write (if_id_write),
        .if_id_flush (if_id_flush),
        .id_ex_flush (id_ex_flush)
    );

endmodule
