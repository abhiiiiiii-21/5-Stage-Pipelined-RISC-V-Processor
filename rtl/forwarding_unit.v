`timescale 1ns/1ps
// =============================================================================
// Module      : forwarding_unit
// Stage       : EX (hazard logic)
// Description : Selects ALU operand sources to resolve RAW data hazards.
//               2'b10 = forward from EX/MEM, 2'b01 = forward from MEM/WB,
//               2'b00 = use register-file value. EX/MEM has priority (newest).
//               x0 is never forwarded; no forwarding if reg_write is 0.
// Ports       : ex_rs1/ex_rs2, mem_rd/mem_reg_write, wb_rd/wb_reg_write,
//               forward_a, forward_b
// =============================================================================
module forwarding_unit (
    input  [4:0] ex_rs1,
    input  [4:0] ex_rs2,
    input  [4:0] mem_rd,
    input        mem_reg_write,
    input  [4:0] wb_rd,
    input        wb_reg_write,
    output [1:0] forward_a,
    output [1:0] forward_b
);

    assign forward_a = (mem_reg_write && mem_rd != 5'd0 && mem_rd == ex_rs1) ? 2'b10 :
                       (wb_reg_write  && wb_rd  != 5'd0 && wb_rd  == ex_rs1) ? 2'b01 : 2'b00;

    assign forward_b = (mem_reg_write && mem_rd != 5'd0 && mem_rd == ex_rs2) ? 2'b10 :
                       (wb_reg_write  && wb_rd  != 5'd0 && wb_rd  == ex_rs2) ? 2'b01 : 2'b00;

endmodule
