`timescale 1ns/1ps
// =============================================================================
// Testbench   : tb_pc_reg
// Description : Self-checking unit test for pc_reg.
//               Checks: reset value, update when en=1, hold when en=0,
//               reset while running.
// Run         : iverilog -g2012 -I rtl -o simulation/build/tb_pc_reg.vvp \
//                   rtl/pc_reg.v testbench/unit/tb_pc_reg.v
//               vvp simulation/build/tb_pc_reg.vvp
// =============================================================================
module tb_pc_reg;

    reg         clk = 0;
    reg         rst;
    reg         en;
    reg  [31:0] pc_next;
    wire [31:0] pc;

    integer pass_count = 0;
    integer fail_count = 0;

    pc_reg dut (
        .clk(clk), .rst(rst), .en(en), .pc_next(pc_next), .pc(pc)
    );

    always #5 clk = ~clk;   // 10 ns clock

    task check(input [31:0] expected, input [255:0] name);
        begin
            if (pc === expected) begin
                $display("PASS: %0s (pc = 0x%08h)", name, pc);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s (pc = 0x%08h, expected 0x%08h)", name, pc, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("simulation/build/tb_pc_reg.vcd");
        $dumpvars(0, tb_pc_reg);

        // 1. Reset
        rst = 1; en = 1; pc_next = 32'h0000_0040;
        @(posedge clk); #1;
        check(32'h0000_0000, "reset sets pc to 0");

        // 2. Update with en = 1
        rst = 0; pc_next = 32'h0000_0004;
        @(posedge clk); #1;
        check(32'h0000_0004, "pc loads pc_next when en=1");

        pc_next = 32'h0000_0008;
        @(posedge clk); #1;
        check(32'h0000_0008, "pc loads next value");

        // 3. Hold with en = 0 (stall)
        en = 0; pc_next = 32'h0000_00FF;
        @(posedge clk); #1;
        check(32'h0000_0008, "pc holds when en=0 (cycle 1)");
        @(posedge clk); #1;
        check(32'h0000_0008, "pc holds when en=0 (cycle 2)");

        // 4. Resume
        en = 1; pc_next = 32'h0000_0100;
        @(posedge clk); #1;
        check(32'h0000_0100, "pc resumes after stall (branch target)");

        // 5. Reset while running (reset has priority over en)
        rst = 1;
        @(posedge clk); #1;
        check(32'h0000_0000, "reset while running");

        $display("--------------------------------------------");
        $display("tb_pc_reg SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("RESULT: PASS");
        else                 $display("RESULT: FAIL");
        $finish;
    end

endmodule
