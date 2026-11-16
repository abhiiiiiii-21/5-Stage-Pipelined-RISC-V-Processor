`timescale 1ns/1ps
// =============================================================================
// Testbench   : tb_id_ex_reg
// Description : Self-checking unit test for id_ex_reg.
//               Checks: reset gives all zeros, every id_* signal passes to
//               ex_* on the clock edge, outputs do not change between edges,
//               flush gives all zeros (bubble), normal operation resumes
//               after flush, reset gives all zeros again.
//               All 19 outputs are compared as one packed vector so a wrong
//               connection on any single signal is detected.
// Run         : iverilog -g2012 -I rtl -o simulation/build/tb_id_ex_reg.vvp \
//                   rtl/id_ex_reg.v testbench/unit/tb_id_ex_reg.v
//               vvp simulation/build/tb_id_ex_reg.vvp
// =============================================================================
module tb_id_ex_reg;

    reg clk = 0;
    reg rst, flush;

    // ID-side inputs
    reg        id_reg_write, id_mem_read, id_mem_write, id_mem_to_reg, id_alu_src;
    reg [1:0]  id_alu_op;
    reg        id_branch, id_jump, id_jalr, id_lui;
    reg [31:0] id_pc, id_rd1, id_rd2, id_imm;
    reg [4:0]  id_rs1, id_rs2, id_rd;
    reg [2:0]  id_funct3;
    reg        id_funct7b5;

    // EX-side outputs
    wire        ex_reg_write, ex_mem_read, ex_mem_write, ex_mem_to_reg, ex_alu_src;
    wire [1:0]  ex_alu_op;
    wire        ex_branch, ex_jump, ex_jalr, ex_lui;
    wire [31:0] ex_pc, ex_rd1, ex_rd2, ex_imm;
    wire [4:0]  ex_rs1, ex_rs2, ex_rd;
    wire [2:0]  ex_funct3;
    wire        ex_funct7b5;

    // Packed views: 11 control bits + 128 data bits + 15 reg bits + 3 + 1 = 158
    wire [157:0] id_bus = {id_reg_write, id_mem_read, id_mem_write, id_mem_to_reg,
                           id_alu_src, id_alu_op, id_branch, id_jump, id_jalr, id_lui,
                           id_pc, id_rd1, id_rd2, id_imm, id_rs1, id_rs2, id_rd,
                           id_funct3, id_funct7b5};
    wire [157:0] ex_bus = {ex_reg_write, ex_mem_read, ex_mem_write, ex_mem_to_reg,
                           ex_alu_src, ex_alu_op, ex_branch, ex_jump, ex_jalr, ex_lui,
                           ex_pc, ex_rd1, ex_rd2, ex_imm, ex_rs1, ex_rs2, ex_rd,
                           ex_funct3, ex_funct7b5};

    integer pass_count = 0;
    integer fail_count = 0;

    id_ex_reg dut (
        .clk(clk), .rst(rst), .flush(flush),
        .id_reg_write(id_reg_write), .id_mem_read(id_mem_read),
        .id_mem_write(id_mem_write), .id_mem_to_reg(id_mem_to_reg),
        .id_alu_src(id_alu_src), .id_alu_op(id_alu_op),
        .id_branch(id_branch), .id_jump(id_jump), .id_jalr(id_jalr), .id_lui(id_lui),
        .id_pc(id_pc), .id_rd1(id_rd1), .id_rd2(id_rd2), .id_imm(id_imm),
        .id_rs1(id_rs1), .id_rs2(id_rs2), .id_rd(id_rd),
        .id_funct3(id_funct3), .id_funct7b5(id_funct7b5),
        .ex_reg_write(ex_reg_write), .ex_mem_read(ex_mem_read),
        .ex_mem_write(ex_mem_write), .ex_mem_to_reg(ex_mem_to_reg),
        .ex_alu_src(ex_alu_src), .ex_alu_op(ex_alu_op),
        .ex_branch(ex_branch), .ex_jump(ex_jump), .ex_jalr(ex_jalr), .ex_lui(ex_lui),
        .ex_pc(ex_pc), .ex_rd1(ex_rd1), .ex_rd2(ex_rd2), .ex_imm(ex_imm),
        .ex_rs1(ex_rs1), .ex_rs2(ex_rs2), .ex_rd(ex_rd),
        .ex_funct3(ex_funct3), .ex_funct7b5(ex_funct7b5)
    );

    always #5 clk = ~clk;

    task check(input [157:0] exp, input [511:0] name);
        begin
            if (ex_bus === exp) begin
                $display("PASS: %0s", name);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s (got %h, expected %h)", name, ex_bus, exp);
                fail_count = fail_count + 1;
            end
        end
    endtask

    // Pattern A: every control bit = 1 and distinct non-zero data values
    task set_pattern_a;
        begin
            id_reg_write = 1; id_mem_read = 1; id_mem_write = 1; id_mem_to_reg = 1;
            id_alu_src = 1; id_alu_op = 2'b11; id_branch = 1; id_jump = 1;
            id_jalr = 1; id_lui = 1;
            id_pc = 32'h0000_0040; id_rd1 = 32'hAAAA_5555; id_rd2 = 32'h1234_ABCD;
            id_imm = 32'hFFFF_FFF8; id_rs1 = 5'd1; id_rs2 = 5'd2; id_rd = 5'd31;
            id_funct3 = 3'b101; id_funct7b5 = 1;
        end
    endtask

    // Pattern B: a realistic lw x3,8(x1) decode
    task set_pattern_b;
        begin
            id_reg_write = 1; id_mem_read = 1; id_mem_write = 0; id_mem_to_reg = 1;
            id_alu_src = 1; id_alu_op = 2'b00; id_branch = 0; id_jump = 0;
            id_jalr = 0; id_lui = 0;
            id_pc = 32'h0000_0010; id_rd1 = 32'h0000_0100; id_rd2 = 32'h0000_0000;
            id_imm = 32'h0000_0008; id_rs1 = 5'd1; id_rs2 = 5'd8; id_rd = 5'd3;
            id_funct3 = 3'b010; id_funct7b5 = 0;
        end
    endtask

    reg [157:0] saved;

    initial begin
        $dumpfile("simulation/build/tb_id_ex_reg.vcd");
        $dumpvars(0, tb_id_ex_reg);

        // 1. Reset -> all zeros (even with non-zero inputs)
        rst = 1; flush = 0; set_pattern_a;
        @(posedge clk); #1;
        check(158'd0, "reset gives all zeros");

        // 2. Pass-through of pattern A
        rst = 0;
        @(posedge clk); #1;
        check(id_bus, "pattern A passes id_* -> ex_*");

        // 3. Outputs only change on the clock edge
        saved = ex_bus;
        set_pattern_b; #2;
        check(saved, "outputs hold until next edge");

        // 4. Pass-through of pattern B
        @(posedge clk); #1;
        check(id_bus, "pattern B (lw) passes id_* -> ex_*");

        // 5. Flush -> bubble (all zeros)
        set_pattern_a; flush = 1;
        @(posedge clk); #1;
        check(158'd0, "flush gives all zeros (bubble)");

        // 6. Normal operation after flush
        flush = 0;
        @(posedge clk); #1;
        check(id_bus, "pass-through resumes after flush");

        // 7. Reset again
        rst = 1;
        @(posedge clk); #1;
        check(158'd0, "reset clears pipeline register");

        $display("--------------------------------------------");
        $display("tb_id_ex_reg SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("RESULT: PASS");
        else                 $display("RESULT: FAIL");
        $finish;
    end

endmodule
