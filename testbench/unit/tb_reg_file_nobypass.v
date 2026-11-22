`timescale 1ns/1ps
// =============================================================================
// Testbench   : tb_reg_file_nobypass
// Description : Self-checking unit test for reg_file_nobypass (register file of
//               the single-cycle baseline, no write-first bypass).
//               Checks: reset clears registers, write then read after the clock
//               edge, two simultaneous reads, write to x0 ignored, x0 reads 0,
//               NO bypass (a read in the write cycle returns the OLD value),
//               no write when we = 0, reset clears written registers.
// Run         : iverilog -g2012 -I rtl -o simulation/build/tb_reg_file_nobypass.vvp \
//                   rtl/reg_file_nobypass.v testbench/unit/tb_reg_file_nobypass.v
//               vvp simulation/build/tb_reg_file_nobypass.vvp
// =============================================================================
module tb_reg_file_nobypass;

    reg         clk = 0;
    reg         rst, we;
    reg  [4:0]  rs1, rs2, rd;
    reg  [31:0] wd;
    wire [31:0] rd1, rd2;

    integer pass_count = 0;
    integer fail_count = 0;

    reg_file_nobypass dut (
        .clk(clk), .rst(rst), .we(we),
        .rs1(rs1), .rs2(rs2), .rd(rd), .wd(wd),
        .rd1(rd1), .rd2(rd2)
    );

    always #5 clk = ~clk;

    task check(input [31:0] got, input [31:0] exp, input [511:0] name);
        begin
            if (got === exp) begin
                $display("PASS: %0s (got 0x%08h)", name, got);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s (got 0x%08h, expected 0x%08h)", name, got, exp);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("simulation/build/tb_reg_file_nobypass.vcd");
        $dumpvars(0, tb_reg_file_nobypass);

        // 1. Reset clears registers
        rst = 1; we = 0; rs1 = 5; rs2 = 6; rd = 0; wd = 0;
        @(posedge clk); #1;
        rst = 0;
        #1; check(rd1, 32'd0, "reset: x5 = 0");
        check(rd2, 32'd0, "reset: x6 = 0");

        // 2. Write x5, visible after the clock edge
        we = 1; rd = 5; wd = 32'hAAAA_0005; rs1 = 5;
        @(posedge clk); #1;
        we = 0;
        check(rd1, 32'hAAAA_0005, "write x5, read after edge");

        // 3. Two simultaneous reads
        we = 1; rd = 6; wd = 32'hBBBB_0006;
        @(posedge clk); #1;
        we = 0; rs1 = 5; rs2 = 6;
        #1; check(rd1, 32'hAAAA_0005, "read1 = x5");
        check(rd2, 32'hBBBB_0006, "read2 = x6");

        // 4. Write to x0 is ignored, x0 reads 0
        we = 1; rd = 0; wd = 32'hFFFF_FFFF; rs1 = 0;
        @(posedge clk); #1;
        we = 0;
        check(rd1, 32'd0, "x0 reads 0 after write attempt");

        // 5. No bypass: while writing x5 the read of x5 still returns the old value
        rs1 = 5; we = 1; rd = 5; wd = 32'h1234_5678;
        #1; check(rd1, 32'hAAAA_0005, "no bypass: same-cycle read returns old x5");
        @(posedge clk); #1;
        we = 0;
        check(rd1, 32'h1234_5678, "x5 updated after the edge");

        // 6. No write when we = 0
        we = 0; rd = 7; wd = 32'hDEAD_BEEF; rs1 = 7;
        @(posedge clk); #1;
        check(rd1, 32'd0, "we = 0: x7 unchanged");

        // 7. Reset clears written registers
        rst = 1; rs1 = 5;
        @(posedge clk); #1;
        rst = 0;
        check(rd1, 32'd0, "reset clears x5");

        $display("--------------------------------------------");
        $display("tb_reg_file_nobypass SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("RESULT: PASS");
        else                 $display("RESULT: FAIL");
        $finish;
    end

endmodule
