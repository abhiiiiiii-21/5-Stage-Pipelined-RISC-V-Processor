`timescale 1ns/1ps
// =============================================================================
// Module      : ex_mem_reg
// Stage       : EX/MEM pipeline register
// Description : Carries the EX-stage results to the MEM stage: the control
//               signals still needed later (reg_write, mem_read, mem_write,
//               mem_to_reg), the ALU result / link address, the data to
//               store and the destination register.
//               - rst      : every output becomes 0 (no write, no memory access)
//               - otherwise: latch all ex_* inputs on the rising edge.
//               No enable or flush is needed: a stall or flush is handled by
//               inserting a bubble into ID/EX, which then flows through here.
// Ports       : clk, rst - clock, synchronous active-high reset
//               ex_*     - values from the EX stage
//               mem_*    - same values for the MEM stage
//                          (mem_result also feeds the EX/MEM forwarding path)
// =============================================================================
module ex_mem_reg (
    input             clk,
    input             rst,
    // in
    input             ex_reg_write,
    input             ex_mem_read,
    input             ex_mem_write,
    input             ex_mem_to_reg,
    input      [31:0] ex_result,
    input      [31:0] ex_store_data,
    input      [4:0]  ex_rd,
    // out
    output reg        mem_reg_write,
    output reg        mem_mem_read,
    output reg        mem_mem_write,
    output reg        mem_mem_to_reg,
    output reg [31:0] mem_result,
    output reg [31:0] mem_store_data,
    output reg [4:0]  mem_rd
);

    always @(posedge clk) begin
        if (rst) begin
            mem_reg_write  <= 1'b0;
            mem_mem_read   <= 1'b0;
            mem_mem_write  <= 1'b0;
            mem_mem_to_reg <= 1'b0;
            mem_result     <= 32'd0;
            mem_store_data <= 32'd0;
            mem_rd         <= 5'd0;
        end else begin
            mem_reg_write  <= ex_reg_write;
            mem_mem_read   <= ex_mem_read;
            mem_mem_write  <= ex_mem_write;
            mem_mem_to_reg <= ex_mem_to_reg;
            mem_result     <= ex_result;
            mem_store_data <= ex_store_data;
            mem_rd         <= ex_rd;
        end
    end

endmodule
