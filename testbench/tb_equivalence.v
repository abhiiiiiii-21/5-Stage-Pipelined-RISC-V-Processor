`timescale 1ns/1ps
// =============================================================================
// Testbench   : tb_equivalence
// Description : Differential verification of the pipeline and single-cycle
//               designs using the same instruction image.
// Run         : iverilog -g2012 -I rtl -DPROG="bench.hex" -DNAME="bench"
//               -s tb_equivalence -o build/tb_equivalence.vvp
//               rtl/*.v testbench/tb_equivalence.v
// =============================================================================
module tb_equivalence;
`ifndef PROG
    `define PROG "testbench/programs/test1_arith.hex"
`endif
`ifndef NAME
    `define NAME "test1_arith"
`endif

    reg clk = 1'b0;
    reg rst = 1'b1;
    integer cycle;
    integer i;
    integer mismatch_count = 0;
    reg mismatch_reported = 1'b0;
    wire [31:0] pipeline_dbg;
    wire [31:0] single_dbg;

    riscv_pipeline_top #(.IMEM_FILE(`PROG)) pipeline_dut (
        .clk(clk),
        .rst(rst),
        .dbg_out(pipeline_dbg)
    );
    riscv_single_cycle_top #(.IMEM_FILE(`PROG)) single_dut (
        .clk(clk),
        .rst(rst),
        .dbg_out(single_dbg)
    );

    always #5 clk = ~clk;

    task report_mismatch;
        input [127:0] kind;
        input integer index;
        input [31:0] pipeline_value;
        input [31:0] single_value;
        begin
            mismatch_count = mismatch_count + 1;
            if (!mismatch_reported) begin
                $display("EQUIV name=%0s mismatch kind=%0s index=%0d pipeline=%08h single=%08h",
                         `NAME, kind, index, pipeline_value, single_value);
                mismatch_reported = 1'b1;
            end
        end
    endtask

    initial begin
        repeat (2) @(posedge clk);
        rst = 1'b0;

        for (cycle = 0; cycle < 30000; cycle = cycle + 1)
            @(posedge clk);

        for (i = 1; i < 32; i = i + 1) begin
            if (pipeline_dut.u_reg_file.regs[i] !== single_dut.u_reg_file.regs[i])
                report_mismatch("register", i,
                                pipeline_dut.u_reg_file.regs[i],
                                single_dut.u_reg_file.regs[i]);
        end

        for (i = 0; i < 512; i = i + 1) begin
            if (pipeline_dut.u_dmem.mem[i] !== single_dut.u_dmem.mem[i])
                report_mismatch("memory", i,
                                pipeline_dut.u_dmem.mem[i],
                                single_dut.u_dmem.mem[i]);
        end

        if (mismatch_count == 0)
            $display("EQUIV name=%0s result=PASS", `NAME);
        else
            $display("EQUIV name=%0s result=FAIL mismatches=%0d",
                     `NAME, mismatch_count);
        $finish;
    end
endmodule
