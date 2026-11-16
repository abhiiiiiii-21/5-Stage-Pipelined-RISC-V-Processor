`timescale 1ns/1ps

module tb_riscv_top;
`ifndef TEST
    `define TEST 1
`endif

`ifdef TEST1
    localparam PROGRAM = (`TEST == 1) ? "testbench/programs/test1_arith.hex" :
                         (`TEST == 2) ? "testbench/programs/test2_loadstore.hex" :
                         (`TEST == 3) ? "testbench/programs/test3_forwarding.hex" :
                         (`TEST == 4) ? "testbench/programs/test4_loaduse.hex" :
                         (`TEST == 5) ? "testbench/programs/test5_branch_jump.hex" :
                                        "testbench/programs/test6_sum_array.hex";
`endif

    reg clk = 1'b0;
    reg rst = 1'b1;
    integer cycle;
    integer pass_count = 0;
    integer fail_count = 0;

    riscv_pipeline_top #(.IMEM_FILE(PROGRAM)) dut (.clk(clk), .rst(rst));
    always #5 clk = ~clk;

    task check_reg(input integer index, input [31:0] expected, input [127:0] name);
        begin
            if (dut.u_reg_file.regs[index] === expected) begin
                $display("PASS: %0s = %08h", name, dut.u_reg_file.regs[index]);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s = %08h, expected %08h",
                         name, dut.u_reg_file.regs[index], expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    task check_mem(input integer index, input [31:0] expected, input [127:0] name);
        begin
            if (dut.u_dmem.mem[index] === expected) begin
                $display("PASS: %0s = %08h", name, dut.u_dmem.mem[index]);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s = %08h, expected %08h",
                         name, dut.u_dmem.mem[index], expected);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("simulation/build/tb_riscv_top.vcd");
        $dumpvars(0, tb_riscv_top);
        repeat (2) @(posedge clk);
        rst = 1'b0;
        for (cycle = 0; cycle < 300; cycle = cycle + 1)
            @(posedge clk);

        case (`TEST)
            1: begin
                check_reg(1, 32'h12345000, "x1 LUI");
                check_reg(4, 32'd8, "x4 ADD");
                check_reg(5, 32'd2, "x5 SUB");
                check_reg(15, 32'd5, "x15 ANDI");
            end
            2: begin
                check_mem(0, 32'd10, "mem[0]");
                check_mem(1, 32'd20, "mem[1]");
                check_reg(3, 32'd10, "x3 LW");
                check_reg(4, 32'd20, "x4 LW");
            end
            3: begin
                check_reg(3, 32'd15, "x3 forwarded ADD");
                check_reg(4, 32'd25, "x4 dependent ADD");
                check_reg(5, 32'd26, "x5 dependent ADDI");
            end
            4: begin
                check_mem(0, 32'd42, "mem[0]");
                check_reg(2, 32'd42, "x2 LW");
                check_reg(3, 32'd84, "x3 load-use ADD");
            end
            5: begin
                check_reg(3, 32'd0, "x3 flushed after BEQ");
                check_reg(5, 32'd8, "x5 not-taken BLT");
                check_reg(6, 32'd9, "x6 not-taken BLT");
                check_reg(7, 32'd44, "x7 JAL link");
            end
            6: begin
                check_mem(5, 32'd15, "mem[20] sum");
                check_reg(8, 32'd15, "x8 sum");
            end
            default: begin
                $display("FAIL: unsupported TEST=%0d", `TEST);
                fail_count = fail_count + 1;
            end
        endcase

        $display("TEST %0d: %s (%0d cycles, %0d passed, %0d failed)",
                 `TEST, (fail_count == 0) ? "PASS" : "FAIL",
                 cycle, pass_count, fail_count);
        $finish;
    end
endmodule
