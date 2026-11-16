`timescale 1ns/1ps
// =============================================================================
// Module      : mem_wb_reg
// Stage       : MEM/WB pipeline register
// Description : Carries reg_write, mem_to_reg, ALU result, loaded data and rd
//               from MEM to WB. Synchronous reset clears every output.
// Ports       : clk, rst; mem_* inputs; wb_* outputs
// =============================================================================
module mem_wb_reg (
    input             clk,
    input             rst,
    input             mem_reg_write,
    input             mem_mem_to_reg,
    input      [31:0] mem_result,
    input      [31:0] mem_mem_rdata,
    input      [4:0]  mem_rd,
    output reg        wb_reg_write,
    output reg        wb_mem_to_reg,
    output reg [31:0] wb_result,
    output reg [31:0] wb_mem_rdata,
    output reg [4:0]  wb_rd
);

    always @(posedge clk) begin
        if (rst) begin
            wb_reg_write  <= 1'b0;
            wb_mem_to_reg <= 1'b0;
            wb_result     <= 32'd0;
            wb_mem_rdata  <= 32'd0;
            wb_rd         <= 5'd0;
        end else begin
            wb_reg_write  <= mem_reg_write;
            wb_mem_to_reg <= mem_mem_to_reg;
            wb_result     <= mem_result;
            wb_mem_rdata  <= mem_mem_rdata;
            wb_rd         <= mem_rd;
        end
    end

endmodule
