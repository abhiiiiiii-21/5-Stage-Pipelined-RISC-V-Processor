`timescale 1ns/1ps
// =============================================================================
// Module      : pc_reg
// Stage       : IF (Instruction Fetch)
// Description : 32-bit Program Counter register.
//               - Synchronous active-high reset sets PC to 0 (first instruction).
//               - When en = 1 the PC loads pc_next on the rising clock edge.
//               - When en = 0 the PC holds its value (used by the hazard unit
//                 to stall the pipeline on a load-use hazard).
// Ports       : clk     - system clock
//               rst     - synchronous reset, active high
//               en      - write enable (pc_write from hazard_unit)
//               pc_next - next PC value (PC+4 or branch/jump target)
//               pc      - current PC, drives instruction memory address
// =============================================================================
module pc_reg (
    input             clk,
    input             rst,
    input             en,
    input      [31:0] pc_next,
    output reg [31:0] pc
);

    always @(posedge clk) begin
        if (rst)
            pc <= 32'd0;
        else if (en)
            pc <= pc_next;
        // else: hold current value (stall)
    end

endmodule
