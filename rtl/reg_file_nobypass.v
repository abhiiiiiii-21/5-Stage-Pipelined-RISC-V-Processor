`timescale 1ns/1ps
// =============================================================================
// Module      : reg_file_nobypass
// Used by     : riscv_single_cycle_top (the single-cycle baseline)
// Description : 32 x 32-bit register file, same ports as reg_file but WITHOUT
//               the write-first bypass.
//
//               Why a separate module: the pipeline's reg_file returns the
//               write-back value when WB writes the register that ID reads in
//               the same cycle. That is needed in the pipeline (WB -> ID
//               hazard). In a single-cycle processor the write data depends on
//               the very read data, so with the bypass an instruction such as
//               "add x8, x8, x9" would form a combinational loop
//               (rd1 -> alu -> wb_data -> bypass -> rd1) and never settle.
//               Without the bypass the read returns the old value during the
//               cycle and the new value is stored on the clock edge, which is
//               the correct single-cycle behaviour.
//
// Ports       : clk, rst (synchronous, active high), we, rs1, rs2, rd, wd,
//               rd1, rd2. Array name is "regs" like reg_file, so testbenches
//               can read dut.u_reg_file.regs[i].
// =============================================================================
module reg_file_nobypass (
    input         clk,
    input         rst,
    input         we,
    input  [4:0]  rs1,
    input  [4:0]  rs2,
    input  [4:0]  rd,
    input  [31:0] wd,
    output [31:0] rd1,
    output [31:0] rd2
);

    reg [31:0] regs [0:31];
    integer i;

    // Write port (synchronous). x0 is never written.
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else if (we && (rd != 5'd0)) begin
            regs[rd] <= wd;
        end
    end

    // Read ports (combinational). x0 always reads 0.
    assign rd1 = (rs1 == 5'd0) ? 32'd0 : regs[rs1];
    assign rd2 = (rs2 == 5'd0) ? 32'd0 : regs[rs2];

endmodule
