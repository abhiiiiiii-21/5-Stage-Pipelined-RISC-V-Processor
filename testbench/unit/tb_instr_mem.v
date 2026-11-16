`timescale 1ns/1ps
`include "defines.vh"
// =============================================================================
// Testbench   : tb_instr_mem
// Description : Self-checking unit test for instr_mem.
//               Loads testbench/programs/smoke.hex and checks that words are
//               read at the correct byte addresses, that the low two address
//               bits are ignored, and that unused locations contain NOP.
// Run (from repository root):
//               iverilog -g2012 -I rtl -o simulation/build/tb_instr_mem.vvp \
//                   rtl/instr_mem.v testbench/unit/tb_instr_mem.v
//               vvp simulation/build/tb_instr_mem.vvp
// =============================================================================
module tb_instr_mem;

    reg  [31:0] addr;
    wire [31:0] instr;

    integer pass_count = 0;
    integer fail_count = 0;

    instr_mem #(
        .MEM_FILE("testbench/programs/smoke.hex"),
        .DEPTH(1024)
    ) dut (
        .addr(addr), .instr(instr)
    );

    task check(input [31:0] a, input [31:0] expected, input [255:0] name);
        begin
            addr = a;
            #1;
            if (instr === expected) begin
                $display("PASS: %0s (addr 0x%08h -> 0x%08h)", name, a, instr);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s (addr 0x%08h -> 0x%08h, expected 0x%08h)", name, a, instr, expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("simulation/build/tb_instr_mem.vcd");
        $dumpvars(0, tb_instr_mem);
        #1;

        check(32'h0000_0000, 32'h00500093, "word 0: addi x1,x0,5");
        check(32'h0000_0004, 32'h00300113, "word 1: addi x2,x0,3");
        check(32'h0000_0008, 32'h002081b3, "word 2: add x3,x1,x2");
        check(32'h0000_001C, 32'h0000006f, "word 7: jal x0,0");
        check(32'h0000_0006, 32'h00300113, "low 2 address bits ignored");
        check(32'h0000_0100, `NOP,         "unused location is NOP");
        check(32'h0000_0FFC, `NOP,         "last word (index 1023) is NOP");

        $display("--------------------------------------------");
        $display("tb_instr_mem SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("RESULT: PASS");
        else                 $display("RESULT: FAIL");
        $finish;
    end

endmodule
