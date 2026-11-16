`timescale 1ns/1ps
// =============================================================================
// Testbench   : tb_ex_mem_reg
// Description : Self-checking unit test for ex_mem_reg.
//               - reset clears every output
//               - values pass through on the rising edge only
//               - consecutive cycles latch new values
//               - reset in the middle of operation clears again
//               All outputs are compared as one 73-bit vector:
//               {reg_write, mem_read, mem_write, mem_to_reg,
//                result[31:0], store_data[31:0], rd[4:0]}
// Run         : iverilog -g2012 -I rtl -o simulation/build/tb_ex_mem_reg.vvp \
//                   rtl/ex_mem_reg.v testbench/unit/tb_ex_mem_reg.v
//               vvp simulation/build/tb_ex_mem_reg.vvp
// =============================================================================
module tb_ex_mem_reg;

    reg         clk = 0;
    reg         rst;
    reg         ex_reg_write, ex_mem_read, ex_mem_write, ex_mem_to_reg;
    reg  [31:0] ex_result, ex_store_data;
    reg  [4:0]  ex_rd;
    wire        mem_reg_write, mem_mem_read, mem_mem_write, mem_mem_to_reg;
    wire [31:0] mem_result, mem_store_data;
    wire [4:0]  mem_rd;

    wire [72:0] out = {mem_reg_write, mem_mem_read, mem_mem_write, mem_mem_to_reg,
                       mem_result, mem_store_data, mem_rd};

    integer pass_count = 0;
    integer fail_count = 0;

    always #5 clk = ~clk;

    ex_mem_reg dut (
        .clk(clk), .rst(rst),
        .ex_reg_write(ex_reg_write), .ex_mem_read(ex_mem_read),
        .ex_mem_write(ex_mem_write), .ex_mem_to_reg(ex_mem_to_reg),
        .ex_result(ex_result), .ex_store_data(ex_store_data), .ex_rd(ex_rd),
        .mem_reg_write(mem_reg_write), .mem_mem_read(mem_mem_read),
        .mem_mem_write(mem_mem_write), .mem_mem_to_reg(mem_mem_to_reg),
        .mem_result(mem_result), .mem_store_data(mem_store_data), .mem_rd(mem_rd)
    );

    task drive(input [3:0] ctrl, input [31:0] res, input [31:0] sd, input [4:0] rd);
        begin
            {ex_reg_write, ex_mem_read, ex_mem_write, ex_mem_to_reg} = ctrl;
            ex_result = res; ex_store_data = sd; ex_rd = rd;
        end
    endtask

    task check(input [72:0] exp, input [511:0] name);
        begin
            if (out === exp) begin
                $display("PASS: %0s", name);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s (got %h, expected %h)", name, out, exp);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("simulation/build/tb_ex_mem_reg.vcd");
        $dumpvars(0, tb_ex_mem_reg);

        // Reset with non-zero inputs: outputs must still be 0
        rst = 1;
        drive(4'b1111, 32'hDEADBEEF, 32'hCAFEBABE, 5'd31);
        @(posedge clk); #1;
        check(73'd0, "reset clears all outputs");

        // Load instruction (reg_write, mem_read, mem_to_reg)
        rst = 0;
        drive(4'b1101, 32'h00000100, 32'h00000000, 5'd5);
        #1;
        check(73'd0, "no change before clock edge");
        @(posedge clk); #1;
        check({4'b1101, 32'h00000100, 32'h00000000, 5'd5}, "LW values passed through");

        // Store instruction (mem_write only)
        drive(4'b0010, 32'h00000200, 32'h12345678, 5'd0);
        @(posedge clk); #1;
        check({4'b0010, 32'h00000200, 32'h12345678, 5'd0}, "SW values passed through");

        // R-type / JAL result
        drive(4'b1000, 32'hFFFFFFFE, 32'hAAAAAAAA, 5'd1);
        @(posedge clk); #1;
        check({4'b1000, 32'hFFFFFFFE, 32'hAAAAAAAA, 5'd1}, "ALU result passed through");

        // Synchronous reset in the middle of operation
        rst = 1;
        @(posedge clk); #1;
        check(73'd0, "mid-run reset clears all outputs");

        $display("--------------------------------------------");
        $display("tb_ex_mem_reg SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("RESULT: PASS");
        else                 $display("RESULT: FAIL");
        $finish;
    end

endmodule
