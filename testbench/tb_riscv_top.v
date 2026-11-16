`timescale 1ns/1ps

module tb_riscv_top;
`ifndef TEST
    `define TEST 1
`endif

    localparam PROGRAM = (`TEST == 1) ? "testbench/programs/test1_arith.hex" :
                         (`TEST == 2) ? "testbench/programs/test2_loadstore.hex" :
                         (`TEST == 3) ? "testbench/programs/test3_forwarding.hex" :
                         (`TEST == 4) ? "testbench/programs/test4_loaduse.hex" :
                         (`TEST == 5) ? "testbench/programs/test5_branch_jump.hex" :
                                        "testbench/programs/test6_sum_array.hex";

    reg clk = 1'b0;
    reg rst = 1'b1;
    integer cycle;
    integer pass_count = 0;
    integer fail_count = 0;
    reg [1023:0] vcd_file;

    // Performance counters (testbench only, no effect on the design).
    // v_ifid marks whether IF/ID holds a real program instruction.
    // An instruction counts as executed when it leaves ID for EX.
    // Every program ends with "jal x0,0"; counting stops when it leaves ID.
    reg     v_ifid = 1'b0;
    reg     v_next;
    reg     halted = 1'b0;
    integer n_instr = 0;
    integer n_stall = 0;
    integer n_taken = 0;
    integer halt_cycle = 0;
    integer total_cycles;

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
        if (!$value$plusargs("VCD=%s", vcd_file))
            vcd_file = "simulation/build/tb_riscv_top.vcd";
        $dumpfile(vcd_file);
        $dumpvars(0, tb_riscv_top);
        repeat (2) @(posedge clk);
        rst = 1'b0;
        for (cycle = 0; cycle < 300; cycle = cycle + 1) begin
            #1;  // signals of cycle (cycle + 1) have settled
            if (!halted) begin
                if (v_ifid && !dut.id_ex_flush) begin
                    n_instr = n_instr + 1;
                    if (dut.id_instr == 32'h0000006f) begin
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
        end

        case (`TEST)
            1: begin
                check_reg(1, 32'h12345000, "x1 LUI");
                check_reg(4, 32'd8, "x4 ADD");
                check_reg(5, 32'd2, "x5 SUB");
                check_reg(6, 32'd1, "x6 AND");
                check_reg(7, 32'd7, "x7 OR");
                check_reg(8, 32'd6, "x8 XOR");
                check_reg(9, 32'd40, "x9 SLL");
                check_reg(10, 32'd0, "x10 SRL");
                check_reg(11, 32'd0, "x11 SRA");
                check_reg(12, 32'd0, "x12 SLT");
                check_reg(13, 32'd0, "x13 SLTU");
                check_reg(14, 32'd3, "x14 ADDI");
                check_reg(15, 32'd5, "x15 ANDI");
                check_reg(16, 32'd15, "x16 ORI");
                check_reg(17, 32'd10, "x17 XORI");
                check_reg(18, 32'd20, "x18 SLLI");
                check_reg(19, 32'd1, "x19 SRLI");
                check_reg(20, 32'd1, "x20 SRAI");
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
                check_reg(8, 32'd0, "x8 skipped by JAL");
                check_reg(9, 32'd52, "x9 JALR link");
            end
            6: begin
                check_mem(5, 32'd15, "mem word 5 (byte 20) sum");
                check_reg(8, 32'd15, "x8 sum");
            end
            default: begin
                $display("FAIL: unsupported TEST=%0d", `TEST);
                fail_count = fail_count + 1;
            end
        endcase

        // The halt instruction leaves ID in halt_cycle and completes WB
        // three cycles later, so the program takes halt_cycle + 3 cycles.
        total_cycles = halt_cycle + 3;
        if (halted)
            $display("PERF: instructions=%0d cycles=%0d load_use_stalls=%0d taken_branches_jumps=%0d CPI=%0.3f",
                     n_instr, total_cycles, n_stall, n_taken, total_cycles * 1.0 / n_instr);
        else
            $display("PERF: halt instruction not reached");

        $display("TEST %0d: %s (%0d cycles, %0d passed, %0d failed)",
                 `TEST, (fail_count == 0) ? "PASS" : "FAIL",
                 cycle, pass_count, fail_count);
        $finish;
    end
endmodule
