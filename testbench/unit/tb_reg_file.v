`timescale 1ns/1ps
// =============================================================================
// Testbench   : tb_reg_file
// Description : Self-checking unit test for reg_file.
//               Checks: reset clears registers, write then read, two
//               simultaneous reads, write to x0 ignored, x0 reads 0,
//               write-first bypass on rd1 and rd2, no bypass when we = 0,
//               reset clears previously written registers.
// Run         : iverilog -g2012 -I rtl -o simulation/build/tb_reg_file.vvp \
//                   rtl/reg_file.v testbench/unit/tb_reg_file.v
//               vvp simulation/build/tb_reg_file.vvp
// =============================================================================
module tb_reg_file;

    reg         clk = 0;
    reg         rst, we;
    reg  [4:0]  rs1, rs2, rd;
    reg  [31:0] wd;
    wire [31:0] rd1, rd2;

    integer pass_count = 0;
    integer fail_count = 0;

    reg_file dut (
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

    // Write one register on the next rising edge, then disable writing.
    task write_reg(input [4:0] addr, input [31:0] data);
        begin
            we = 1; rd = addr; wd = data;
            @(posedge clk); #1;
            we = 0;
        end
    endtask

    initial begin
        $dumpfile("simulation/build/tb_reg_file.vcd");
        $dumpvars(0, tb_reg_file);

        // 1. Reset clears registers
        rst = 1; we = 0; rs1 = 0; rs2 = 0; rd = 0; wd = 0;
        @(posedge clk); #1;
        rst = 0;
        rs1 = 5'd5; rs2 = 5'd31; #1;
        check(rd1, 32'd0, "x5 is 0 after reset");
        check(rd2, 32'd0, "x31 is 0 after reset");

        // 2. Write then read
        write_reg(5'd1, 32'hDEAD_BEEF);
        rs1 = 5'd1; #1;
        check(rd1, 32'hDEAD_BEEF, "write x1 then read on rd1");

        // 3. Two simultaneous reads
        write_reg(5'd2, 32'h1234_5678);
        write_reg(5'd31, 32'hFFFF_FFFB);
        rs1 = 5'd2; rs2 = 5'd31; #1;
        check(rd1, 32'h1234_5678, "simultaneous read rd1 = x2");
        check(rd2, 32'hFFFF_FFFB, "simultaneous read rd2 = x31");
        rs1 = 5'd31; rs2 = 5'd1; #1;
        check(rd1, 32'hFFFF_FFFB, "swapped read rd1 = x31");
        check(rd2, 32'hDEAD_BEEF, "swapped read rd2 = x1");

        // 4. Write to x0 is ignored, x0 always reads 0
        write_reg(5'd0, 32'hFFFF_FFFF);
        rs1 = 5'd0; rs2 = 5'd0; #1;
        check(rd1, 32'd0, "x0 write ignored (rd1)");
        check(rd2, 32'd0, "x0 write ignored (rd2)");

        // 5. x0 is not bypassed even while a write to x0 is pending
        we = 1; rd = 5'd0; wd = 32'hAAAA_AAAA; rs1 = 5'd0; #1;
        check(rd1, 32'd0, "no bypass for x0");
        we = 0;

        // 6. Write-first bypass on rd1: same-cycle write is visible
        we = 1; rd = 5'd3; wd = 32'h0000_0064; rs1 = 5'd3; rs2 = 5'd2; #1;
        check(rd1, 32'h0000_0064, "bypass rd1 (x3 written this cycle)");
        check(rd2, 32'h1234_5678, "rd2 unaffected by bypass");
        @(posedge clk); #1;
        we = 0; #1;
        check(rd1, 32'h0000_0064, "x3 stored after bypass cycle");

        // 7. Write-first bypass on rd2 (overwrite x2)
        we = 1; rd = 5'd2; wd = 32'hCAFE_F00D; rs1 = 5'd1; rs2 = 5'd2; #1;
        check(rd2, 32'hCAFE_F00D, "bypass rd2 (x2 written this cycle)");
        check(rd1, 32'hDEAD_BEEF, "rd1 unaffected by bypass");
        @(posedge clk); #1;
        we = 0;

        // 8. Bypass on both ports when rs1 == rs2 == rd
        we = 1; rd = 5'd7; wd = 32'h7777_7777; rs1 = 5'd7; rs2 = 5'd7; #1;
        check(rd1, 32'h7777_7777, "bypass both ports (rd1)");
        check(rd2, 32'h7777_7777, "bypass both ports (rd2)");
        @(posedge clk); #1;

        // 9. No bypass when we = 0 (old value returned)
        we = 0; rd = 5'd7; wd = 32'h1111_1111; #1;
        check(rd1, 32'h7777_7777, "no bypass when we = 0");

        // 10. Reset clears previously written registers
        rst = 1;
        @(posedge clk); #1;
        rst = 0;
        rs1 = 5'd1; rs2 = 5'd7; #1;
        check(rd1, 32'd0, "x1 cleared by reset");
        check(rd2, 32'd0, "x7 cleared by reset");

        $display("--------------------------------------------");
        $display("tb_reg_file SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("RESULT: PASS");
        else                 $display("RESULT: FAIL");
        $finish;
    end

endmodule
