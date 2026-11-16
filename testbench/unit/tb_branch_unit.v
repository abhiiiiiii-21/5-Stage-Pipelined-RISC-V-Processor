`timescale 1ns/1ps
// =============================================================================
// Testbench   : tb_branch_unit
// Description : Self-checking unit test for branch_unit.
//               - BEQ, BNE, BLT, BGE each taken and not taken, including
//                 signed negative operands (where signed and unsigned order
//                 differ)
//               - non-branch instruction (branch=0) never redirects
//               - JAL: always taken, target = pc + imm (forward and backward)
//               - JALR: always taken, target = (rs1 + imm) with bit 0 cleared
//               pc_src and branch_target are checked together.
// Run         : iverilog -g2012 -I rtl -o simulation/build/tb_branch_unit.vvp \
//                   rtl/branch_unit.v testbench/unit/tb_branch_unit.v
//               vvp simulation/build/tb_branch_unit.vvp
// =============================================================================
module tb_branch_unit;

    reg         branch, jump, jalr;
    reg  [2:0]  funct3;
    reg  [31:0] rs1_val, rs2_val, pc, imm;
    wire        pc_src;
    wire [31:0] branch_target;

    integer pass_count = 0;
    integer fail_count = 0;

    localparam F3_BEQ = 3'b000, F3_BNE = 3'b001, F3_BLT = 3'b100, F3_BGE = 3'b101;

    branch_unit dut (
        .branch(branch), .jump(jump), .jalr(jalr), .funct3(funct3),
        .rs1_val(rs1_val), .rs2_val(rs2_val), .pc(pc), .imm(imm),
        .pc_src(pc_src), .branch_target(branch_target)
    );

    // flags = {branch, jump, jalr}
    task check(input [2:0] flags, input [2:0] f3,
               input [31:0] v1, input [31:0] v2, input [31:0] in_pc, input [31:0] in_imm,
               input exp_src, input [31:0] exp_target, input [511:0] name);
        begin
            {branch, jump, jalr} = flags;
            funct3 = f3; rs1_val = v1; rs2_val = v2; pc = in_pc; imm = in_imm; #1;
            if (pc_src === exp_src && branch_target === exp_target) begin
                $display("PASS: %0s (pc_src=%b target=%h)", name, pc_src, branch_target);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s (pc_src=%b target=%h, expected pc_src=%b target=%h)",
                         name, pc_src, branch_target, exp_src, exp_target);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("simulation/build/tb_branch_unit.vcd");
        $dumpvars(0, tb_branch_unit);

        // ---- BEQ ----
        check(3'b100, F3_BEQ, 32'd10, 32'd10, 32'h100, 32'd16,       1, 32'h110, "BEQ taken (10 == 10)");
        check(3'b100, F3_BEQ, 32'd10, 32'd11, 32'h100, 32'd16,       0, 32'h110, "BEQ not taken (10 != 11)");
        // ---- BNE ----
        check(3'b100, F3_BNE, 32'd1,  32'd2,  32'h200, 32'hFFFFFFF8, 1, 32'h1F8, "BNE taken, backward offset -8");
        check(3'b100, F3_BNE, 32'd7,  32'd7,  32'h200, 32'hFFFFFFF8, 0, 32'h1F8, "BNE not taken (7 == 7)");
        // ---- BLT (signed) ----
        check(3'b100, F3_BLT, 32'hFFFFFFFF, 32'd1, 32'h40, 32'd8,    1, 32'h48,  "BLT taken (-1 < 1 signed)");
        check(3'b100, F3_BLT, 32'd1, 32'hFFFFFFFF, 32'h40, 32'd8,    0, 32'h48,  "BLT not taken (1 < -1 false)");
        check(3'b100, F3_BLT, 32'hFFFFFFF6, 32'hFFFFFFFB, 32'h40, 32'd8, 1, 32'h48, "BLT taken (-10 < -5)");
        check(3'b100, F3_BLT, 32'd5,  32'd5,  32'h40, 32'd8,         0, 32'h48,  "BLT not taken (5 < 5 false)");
        // ---- BGE (signed) ----
        check(3'b100, F3_BGE, 32'd5,  32'd5,  32'h80, 32'd12,        1, 32'h8C,  "BGE taken (5 >= 5)");
        check(3'b100, F3_BGE, 32'd1, 32'hFFFFFFFF, 32'h80, 32'd12,   1, 32'h8C,  "BGE taken (1 >= -1 signed)");
        check(3'b100, F3_BGE, 32'hFFFFFFFF, 32'd1, 32'h80, 32'd12,   0, 32'h8C,  "BGE not taken (-1 >= 1 false)");
        // ---- not a branch: condition true but branch=0 ----
        check(3'b000, F3_BEQ, 32'd3,  32'd3,  32'h10, 32'd4,         0, 32'h14,  "no branch flag -> not taken");
        // ---- JAL: pc + imm ----
        check(3'b010, 3'b000, 32'd0,  32'd0,  32'h20, 32'd100,       1, 32'h84,  "JAL forward (0x20 + 100)");
        check(3'b010, 3'b000, 32'd0,  32'd0,  32'h20, 32'hFFFFFFF0,  1, 32'h10,  "JAL backward (0x20 - 16)");
        // ---- JALR: (rs1 + imm) & ~1 ----
        check(3'b001, 3'b000, 32'h1000, 32'd0, 32'h30, 32'd4,        1, 32'h1004, "JALR rs1+imm");
        check(3'b001, 3'b000, 32'h1001, 32'd0, 32'h30, 32'd4,        1, 32'h1004, "JALR clears bit 0 (0x1005 -> 0x1004)");
        check(3'b001, 3'b000, 32'h1000, 32'd0, 32'h30, 32'hFFFFFFFF, 1, 32'h0FFE, "JALR negative imm, bit 0 cleared");

        $display("--------------------------------------------");
        $display("tb_branch_unit SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("RESULT: PASS");
        else                 $display("RESULT: FAIL");
        $finish;
    end

endmodule
