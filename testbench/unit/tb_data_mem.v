`timescale 1ns/1ps
// Self-checking unit test for data_mem.
// Run: iverilog -g2012 -I rtl -o simulation/build/tb_data_mem.vvp rtl/data_mem.v testbench/unit/tb_data_mem.v
//      vvp simulation/build/tb_data_mem.vvp
module tb_data_mem;
    reg clk = 0, mem_read, mem_write;
    reg [31:0] addr, wdata;
    wire [31:0] rdata;
    integer pass_count = 0, fail_count = 0;

    data_mem #(.DEPTH(1024)) dut (.clk(clk), .mem_read(mem_read), .mem_write(mem_write),
                                  .addr(addr), .wdata(wdata), .rdata(rdata));
    always #5 clk = ~clk;

    task check(input [31:0] expected, input [255:0] name);
        begin
            if (rdata === expected) begin
                $display("PASS: %0s (rdata = 0x%08h)", name, rdata);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s (rdata = 0x%08h, expected 0x%08h)", name, rdata, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task write(input [31:0] a, input [31:0] d);
        begin
            addr = a; wdata = d; mem_write = 1; mem_read = 0;
            @(posedge clk); #1; mem_write = 0;
        end
    endtask

    initial begin
        $dumpfile("simulation/build/tb_data_mem.vcd");
        $dumpvars(0, tb_data_mem);
        mem_read = 0; mem_write = 0; addr = 0; wdata = 0;
        #1;

        write(32'h0, 32'hDEADBEEF);
        write(32'h4, 32'h12345678);
        write(32'hFFC, 32'hCAFEF00D);

        mem_read = 1; addr = 32'h0;   #1; check(32'hDEADBEEF, "read addr 0x0");
        addr = 32'h4;                 #1; check(32'h12345678, "read addr 0x4");
        addr = 32'hFFC;               #1; check(32'hCAFEF00D, "read last word 0xFFC");
        addr = 32'h8;                 #1; check(32'h0,        "unwritten word is 0");

        mem_read = 0; addr = 32'h0;   #1; check(32'h0, "mem_read=0 gives 0");

        // mem_write=0: data must not change
        addr = 32'h0; wdata = 32'hFFFFFFFF; mem_write = 0; mem_read = 1;
        @(posedge clk); #1; check(32'hDEADBEEF, "no write when mem_write=0");

        // overwrite
        write(32'h0, 32'h0000_00AA);
        mem_read = 1; addr = 32'h0;   #1; check(32'h0000_00AA, "overwrite word 0");

        $display("--------------------------------------------");
        $display("tb_data_mem SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
        $finish;
    end
endmodule
