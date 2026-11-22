`timescale 1ns/1ps
// =============================================================================
// Testbench   : tb_bench
// Description : Runs one benchmark program (testbench/programs/bench_*.hex) on
//               either design and checks its results in data memory.
//                 default   : riscv_pipeline_top (5-stage pipeline)
//                 -DSINGLE  : riscv_single_cycle_top (single-cycle baseline)
//               The program runs for a fixed MAX_CYCLES; the cycle in which the
//               final "jal x0,0" halt is reached is recorded. If the halt is
//               never reached the result is FAIL.
//
//               Counters (testbench only, same definitions as tb_riscv_top and
//               tb_single_cycle so the numbers match Phase I):
//                 pipeline : instr  = instructions that leave ID for EX
//                                     (valid IF/ID, not bubbled), up to and
//                                     including the halt
//                            stalls = cycles with pc_write low and no pc_src
//                            taken  = cycles with pc_src before the halt
//                            cycles = halt cycle (halt leaves ID) + 3
//                 single   : instr  = cycles = instructions executed up to and
//                                     including the halt; stalls = taken = 0
//
//               Output: exactly one line
//                 BENCH name=<n> design=<pipeline|single> instr=<N> cycles=<C>
//                       stalls=<S> taken=<T> result=<PASS|FAIL>
//               +VERBOSE prints each failing check, +VCD=<file> dumps a VCD.
//
// Run         : iverilog -g2012 -I rtl -s tb_bench \
//                   -DPROG='"testbench/programs/bench_sort.hex"' -DNAME='"sort"' \
//                   -o simulation/build/bench_sort_pipeline.vvp rtl/*.v testbench/tb_bench.v
//               vvp simulation/build/bench_sort_pipeline.vvp
//               (add -DSINGLE for the single-cycle baseline;
//                simulation/run_bench.sh runs all six on both designs)
// =============================================================================
module tb_bench;
`ifndef PROG
    `define PROG "testbench/programs/bench_fib.hex"
`endif
`ifndef NAME
    `define NAME "fib"
`endif

    localparam MAX_CYCLES = 30000;
    localparam HALT       = 32'h0000006f;   // jal x0, 0

    reg clk = 1'b0;
    reg rst = 1'b1;
    integer cycle;
    integer i;
    integer fail_count = 0;
    reg [8*16-1:0] name = `NAME;
    reg [1023:0]   vcd_file;
    reg            verbose;

    reg     halted = 1'b0;
    integer n_instr = 0;
    integer n_stall = 0;
    integer n_taken = 0;
    integer halt_cycle = 0;
    integer total_cycles = 0;

    wire [31:0] dbg_out;

`ifdef SINGLE
    localparam DESIGN = "single";
    riscv_single_cycle_top #(.IMEM_FILE(`PROG)) dut (.clk(clk), .rst(rst), .dbg_out(dbg_out));
`else
    localparam DESIGN = "pipeline";
    // v_ifid marks whether IF/ID holds a real program instruction
    reg v_ifid = 1'b0;
    reg v_next;
    riscv_pipeline_top #(.IMEM_FILE(`PROG)) dut (.clk(clk), .rst(rst), .dbg_out(dbg_out));
`endif

    always #5 clk = ~clk;

    // Compare one data-memory word (word index) with its expected value
    task check_mem(input integer index, input [31:0] expected);
        begin
            if (dut.u_dmem.mem[index] !== expected) begin
                fail_count = fail_count + 1;
                if (verbose)
                    $display("FAIL: mem[%0d] (byte 0x%0h) = %08h, expected %08h",
                             index, 4 * index, dut.u_dmem.mem[index], expected);
            end
        end
    endtask

    initial begin
        verbose = $test$plusargs("VERBOSE");
        if ($value$plusargs("VCD=%s", vcd_file)) begin
            $dumpfile(vcd_file);
            $dumpvars(0, tb_bench);
        end
        repeat (2) @(posedge clk);
        rst = 1'b0;
        for (cycle = 0; cycle < MAX_CYCLES; cycle = cycle + 1) begin
            #1;  // signals of cycle (cycle + 1) have settled
`ifdef SINGLE
            if (!halted) begin
                n_instr = n_instr + 1;   // this instruction executes at the next edge
                if (dut.instr == HALT) begin
                    halted     = 1'b1;
                    halt_cycle = cycle + 1;
                end
            end
            @(posedge clk);
`else
            if (!halted) begin
                if (v_ifid && !dut.id_ex_flush) begin
                    n_instr = n_instr + 1;
                    if (dut.id_instr == HALT) begin
                        halted     = 1'b1;
                        halt_cycle = cycle + 1;
                    end
                end
                if (!dut.pc_write && !dut.pc_src) n_stall = n_stall + 1;
                if (dut.pc_src && !halted)        n_taken = n_taken + 1;
            end
            v_next = dut.if_id_flush ? 1'b0 : (dut.if_id_write ? 1'b1 : v_ifid);
            @(posedge clk);
            v_ifid = v_next;
`endif
        end

`ifdef SINGLE
        total_cycles = n_instr;          // one instruction per cycle
`else
        total_cycles = halt_cycle + 3;   // halt leaves ID, completes WB 3 cycles later
`endif

        // Expected results (byte 0x100 = word 64), computed independently in Python
        case (name)
            "fib": begin
                check_mem(64, 32'h00000001);    // fib(1)
                check_mem(65, 32'h00000037);    // fib(10) = 55
                check_mem(66, 32'h00001a6d);    // fib(20) = 6765
                check_mem(67, 32'h000cb228);    // fib(30) = 832040
                check_mem(68, 32'h06197ecb);    // fib(40) = 102334155
                check_mem(69, 32'h6d73e55f);    // fib(46) = 1836311903
            end
            "sum": begin
                check_mem(64, 32'h000019d0);    // sum of 13*i + 5, i = 0..31 = 6608
                check_mem(65, 32'h00000020);    // count = 32
            end
            "sort": begin
                check_mem(64, 32'h81b3ac98);
                check_mem(65, 32'h87985aa5);
                check_mem(66, 32'h89ca4f1d);
                check_mem(67, 32'h8cc6cec6);
                check_mem(68, 32'hc5186e29);
                check_mem(69, 32'hd37862a7);
                check_mem(70, 32'hf6daad69);
                check_mem(71, 32'hfcbe64a0);
                check_mem(72, 32'h155b24a3);
                check_mem(73, 32'h29a8e24d);
                check_mem(74, 32'h3565ea15);
                check_mem(75, 32'h3ab14b11);
                check_mem(76, 32'h4820f4c4);
                check_mem(77, 32'h4e0f25f8);
                check_mem(78, 32'h69bf3df8);
                check_mem(79, 32'h703a0788);
            end
            "gcd": begin
                check_mem(64, 32'd6);           // gcd(48, 18)
                check_mem(65, 32'd21);          // gcd(1071, 462)
                check_mem(66, 32'd6);           // gcd(270, 192)
                check_mem(67, 32'd1);           // gcd(144, 89)
                check_mem(68, 32'd1);           // gcd(1000, 7)
                check_mem(69, 32'd252);         // gcd(1764, 1260)
            end
            "memcpy": begin
                check_mem(64, 32'h581e92a0);    // sum of the 64 copied words
                check_mem(65, 32'hd019ec40);    // xor of the 64 copied words
                check_mem(256, 32'h00000001);   // dst[0]  (byte 0x400)
                check_mem(319, 32'he01ad4e8);   // dst[63] (byte 0x4fc)
                for (i = 0; i < 64; i = i + 1)  // dst must equal src word for word
                    check_mem(256 + i, dut.u_dmem.mem[128 + i]);
            end
            "mul": begin
                check_mem(64, 32'h04fed79d);    // 12345 * 6789 = 83810205
                check_mem(65, 32'hffffffff);    // 65535 * 65537
                check_mem(66, 32'hfffffc18);    // -25 * 40 = -1000
                check_mem(67, 32'hffffffeb);    // 7 * -3 = -21
                check_mem(68, 32'h00000000);    // 0x1234 * 0
                check_mem(69, 32'h000f4240);    // 1000 * 1000 = 1000000
            end
            default: begin
                fail_count = fail_count + 1;
                if (verbose) $display("FAIL: unknown benchmark name %0s", name);
            end
        endcase

        if (!halted) begin
            fail_count = fail_count + 1;
            if (verbose) $display("FAIL: halt not reached in %0d cycles", MAX_CYCLES);
        end

        $display("BENCH name=%0s design=%0s instr=%0d cycles=%0d stalls=%0d taken=%0d result=%0s",
                 name, DESIGN, n_instr, halted ? total_cycles : 0, n_stall, n_taken,
                 (fail_count == 0) ? "PASS" : "FAIL");
        $finish;
    end
endmodule
