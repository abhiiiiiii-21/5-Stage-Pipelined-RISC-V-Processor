`timescale 1ns/1ps
// =============================================================================
// Module      : reg_file
// Stage       : ID (Instruction Decode)
// Description : 32 x 32-bit integer register file (x0..x31) of the RV32I core.
//               - Two combinational read ports (rs1 -> rd1, rs2 -> rd2), used
//                 by the instruction in the ID stage.
//               - One synchronous write port (rd, wd, we) driven by the WB
//                 stage, written on the rising edge of clk.
//               - x0 is hard-wired to zero: writes to x0 are ignored and a
//                 read of x0 always returns 0.
//               - Synchronous active-high reset clears every register.
//               - Write-first bypass: if WB writes register rd in the same
//                 cycle that ID reads it (we && rd != 0 && rd == rs), the read
//                 port returns the new value wd instead of the old stored
//                 value. This removes the WB -> ID data hazard without an
//                 extra forwarding path.
// Ports       : clk, rst   - clock, synchronous active-high reset
//               we         - write enable (wb_reg_write)
//               rs1, rs2   - source register addresses (from ID instruction)
//               rd, wd     - destination register address / data (from WB)
//               rd1, rd2   - read data for rs1 / rs2
// Debug       : the system testbench reads dut.u_reg_file.regs[i]
// =============================================================================
module reg_file (
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

    // ---------------------------------------------------------------------
    // Write port (synchronous). x0 is never written.
    // ---------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else if (we && (rd != 5'd0)) begin
            regs[rd] <= wd;
        end
    end

    // ---------------------------------------------------------------------
    // Read ports (combinational) with write-first bypass.
    // Priority: x0 -> 0, then same-cycle WB write -> wd, else stored value.
    // ---------------------------------------------------------------------
    assign rd1 = (rs1 == 5'd0)                ? 32'd0 :
                 (we && (rd == rs1))          ? wd    :
                                                regs[rs1];

    assign rd2 = (rs2 == 5'd0)                ? 32'd0 :
                 (we && (rd == rs2))          ? wd    :
                                                regs[rs2];

endmodule
