`timescale 1ns/1ps
`include "defines.vh"
// =============================================================================
// Testbench   : tb_if_id_reg
// Description : Self-checking unit test for if_id_reg.
//               Checks: reset -> NOP, latch when en=1, hold when en=0,
//               flush -> NOP, flush has priority over en=0 (stall).
// Run         : iverilog -g2012 -I rtl -o simulation/build/tb_if_id_reg.vvp \
//                   rtl/if_id_reg.v testbench/unit/tb_if_id_reg.v
//               vvp simulation/build/tb_if_id_reg.vvp
// =============================================================================
module tb_if_id_reg;

    reg         clk = 0;
    reg         rst, en, flush;
    reg  [31:0] if_pc, if_instr;
    wire [31:0] id_pc, id_instr;

    integer pass_count = 0;
    integer fail_count = 0;

    if_id_reg dut (
        .clk(clk), .rst(rst), .en(en), .flush(flush),
        .if_pc(if_pc), .if_instr(if_instr),
        .id_pc(id_pc), .id_instr(id_instr)
    );

    always #5 clk = ~clk;

    task check(input [31:0] exp_pc, input [31:0] exp_instr, input [255:0] name);
        begin
            if (id_pc === exp_pc && id_instr === exp_instr) begin
                $display("PASS: %0s (id_pc = 0x%08h, id_instr = 0x%08h)", name, id_pc, id_instr);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s (id_pc = 0x%08h, id_instr = 0x%08h, expected 0x%08h / 0x%08h)",
                         name, id_pc, id_instr, exp_pc, exp_instr);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("simulation/build/tb_if_id_reg.vcd");
        $dumpvars(0, tb_if_id_reg);

        // 1. Reset
        rst = 1; en = 1; flush = 0;
        if_pc = 32'h0000_0010; if_instr = 32'h002081b3;
        @(posedge clk); #1;
        check(32'h0, `NOP, "reset gives NOP");

        // 2. Latch
        rst = 0;
        @(posedge clk); #1;
        check(32'h0000_0010, 32'h002081b3, "latch when en=1");

        // 3. Hold (stall)
        en = 0; if_pc = 32'h0000_0014; if_instr = 32'h40118233;
        @(posedge clk); #1;
        check(32'h0000_0010, 32'h002081b3, "hold when en=0");

        // 4. Latch again
        en = 1;
        @(posedge clk); #1;
        check(32'h0000_0014, 32'h40118233, "latch after stall");

        // 5. Flush
        flush = 1; if_pc = 32'h0000_0018; if_instr = 32'h00302023;
        @(posedge clk); #1;
        check(32'h0, `NOP, "flush gives NOP");

        // 6. Flush has priority over stall
        en = 0; flush = 1;
        @(posedge clk); #1;
        check(32'h0, `NOP, "flush overrides en=0");

        // 7. Normal again
        en = 1; flush = 0;
        @(posedge clk); #1;
        check(32'h0000_0018, 32'h00302023, "normal latch after flush");

        $display("--------------------------------------------");
        $display("tb_if_id_reg SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("RESULT: PASS");
        else                 $display("RESULT: FAIL");
        $finish;
    end

endmodule
