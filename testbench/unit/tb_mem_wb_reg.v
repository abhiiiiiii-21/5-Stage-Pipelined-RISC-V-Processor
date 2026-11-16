`timescale 1ns/1ps
// Self-checking unit test for mem_wb_reg.
// Run: iverilog -g2012 -I rtl -o simulation/build/tb_mem_wb_reg.vvp rtl/mem_wb_reg.v testbench/unit/tb_mem_wb_reg.v
//      vvp simulation/build/tb_mem_wb_reg.vvp
module tb_mem_wb_reg;
    reg clk = 0, rst;
    reg mem_reg_write, mem_mem_to_reg;
    reg [31:0] mem_result, mem_mem_rdata;
    reg [4:0] mem_rd;
    wire wb_reg_write, wb_mem_to_reg;
    wire [31:0] wb_result, wb_mem_rdata;
    wire [4:0] wb_rd;
    integer pass_count = 0, fail_count = 0;

    mem_wb_reg dut (.clk(clk), .rst(rst),
        .mem_reg_write(mem_reg_write), .mem_mem_to_reg(mem_mem_to_reg),
        .mem_result(mem_result), .mem_mem_rdata(mem_mem_rdata), .mem_rd(mem_rd),
        .wb_reg_write(wb_reg_write), .wb_mem_to_reg(wb_mem_to_reg),
        .wb_result(wb_result), .wb_mem_rdata(wb_mem_rdata), .wb_rd(wb_rd));
    always #5 clk = ~clk;

    task check(input exp_rw, input exp_m2r, input [31:0] exp_res, input [31:0] exp_rd_data,
               input [4:0] exp_rd, input [255:0] name);
        begin
            if (wb_reg_write === exp_rw && wb_mem_to_reg === exp_m2r && wb_result === exp_res &&
                wb_mem_rdata === exp_rd_data && wb_rd === exp_rd) begin
                $display("PASS: %0s", name);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s (rw=%b m2r=%b res=0x%08h rdata=0x%08h rd=%0d)", name,
                         wb_reg_write, wb_mem_to_reg, wb_result, wb_mem_rdata, wb_rd);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("simulation/build/tb_mem_wb_reg.vcd");
        $dumpvars(0, tb_mem_wb_reg);
        rst = 1; mem_reg_write = 1; mem_mem_to_reg = 1;
        mem_result = 32'hAAAA_0001; mem_mem_rdata = 32'hBBBB_0002; mem_rd = 5'd7;
        @(posedge clk); #1;
        check(0, 0, 32'h0, 32'h0, 5'd0, "reset clears all outputs");

        rst = 0;
        @(posedge clk); #1;
        check(1, 1, 32'hAAAA_0001, 32'hBBBB_0002, 5'd7, "pass-through load values");

        mem_reg_write = 1; mem_mem_to_reg = 0; mem_result = 32'h0000_0010;
        mem_mem_rdata = 32'h0; mem_rd = 5'd31;
        @(posedge clk); #1;
        check(1, 0, 32'h0000_0010, 32'h0, 5'd31, "pass-through ALU values");

        mem_reg_write = 0; mem_rd = 5'd3;
        @(posedge clk); #1;
        check(0, 0, 32'h0000_0010, 32'h0, 5'd3, "reg_write=0 propagates");

        rst = 1;
        @(posedge clk); #1;
        check(0, 0, 32'h0, 32'h0, 5'd0, "reset while running");

        $display("--------------------------------------------");
        $display("tb_mem_wb_reg SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
        $finish;
    end
endmodule
