`timescale 1ns/1ps
// =============================================================================
// Module      : data_mem
// Stage       : MEM
// Description : Word-addressed data memory (Harvard). Word index = addr[11:2].
//               Write is synchronous (posedge clk, when mem_write).
//               Read is combinational and gated by mem_read (0 when not reading).
// Parameters  : DEPTH - number of 32-bit words (default 1024)
// Ports       : clk, mem_read, mem_write, addr (byte address), wdata, rdata
// =============================================================================
module data_mem #(
    parameter DEPTH = 1024
) (
    input             clk,
    input             mem_read,
    input             mem_write,
    input      [31:0] addr,
    input      [31:0] wdata,
    output     [31:0] rdata
);

    reg [31:0] mem [0:DEPTH-1];
    integer i;

    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'd0;
    end

    always @(posedge clk) begin
        if (mem_write)
            mem[addr[11:2]] <= wdata;
    end

    assign rdata = mem_read ? mem[addr[11:2]] : 32'd0;

endmodule
