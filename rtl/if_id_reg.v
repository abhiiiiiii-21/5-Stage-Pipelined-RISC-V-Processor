`timescale 1ns/1ps
`include "defines.vh"
// =============================================================================
// Module      : if_id_reg
// Stage       : IF/ID pipeline register
// Description : Holds the fetched instruction and its PC between the IF and
//               ID stages.
//               - rst or flush : instruction becomes NOP and PC becomes 0.
//                 flush is raised by the hazard unit when a branch/jump is
//                 taken in EX, so the wrongly fetched instruction is discarded.
//               - en = 1       : latch new values from IF.
//               - en = 0       : hold (load-use stall).
//               flush has priority over en.
// Ports       : clk, rst         - clock, synchronous active-high reset
//               en               - write enable (if_id_write from hazard_unit)
//               flush            - insert NOP (if_id_flush from hazard_unit)
//               if_pc, if_instr  - values from IF stage
//               id_pc, id_instr  - values to ID stage
// =============================================================================
module if_id_reg (
    input             clk,
    input             rst,
    input             en,
    input             flush,
    input      [31:0] if_pc,
    input      [31:0] if_instr,
    output reg [31:0] id_pc,
    output reg [31:0] id_instr
);

    always @(posedge clk) begin
        if (rst || flush) begin
            id_pc    <= 32'd0;
            id_instr <= `NOP;
        end else if (en) begin
            id_pc    <= if_pc;
            id_instr <= if_instr;
        end
        // else: hold (stall)
    end

endmodule
