`timescale 1ns/1ps
`include "defines.vh"
// =============================================================================
// Testbench   : tb_ex_stage
// Description : Self-checking unit test for ex_stage (alu_control, alu and
//               branch_unit inside, plus the forwarding / operand muxes).
//               - forwarding selects 00 / 01 / 10 on operand A and B
//               - ALU source mux (immediate vs register)
//               - LUI path (operand A forced to 0, result = imm)
//               - JAL / JALR: ex_result = pc + 4, target and pc_src
//               - store_data takes the forwarded rs2 value
//               - branch decided on forwarded operands
//               Register-file values are 100 (rs1) and 200 (rs2), EX/MEM
//               forward value is 1000 and MEM/WB value is 2000, so each
//               result shows which source was selected.
// Run         : iverilog -g2012 -I rtl -o simulation/build/tb_ex_stage.vvp \
//                   rtl/alu.v rtl/alu_control.v rtl/branch_unit.v rtl/ex_stage.v \
//                   testbench/unit/tb_ex_stage.v
//               vvp simulation/build/tb_ex_stage.vvp
// =============================================================================
module tb_ex_stage;

    reg  [31:0] ex_pc, ex_rd1, ex_rd2, ex_imm;
    reg  [2:0]  ex_funct3;
    reg         ex_funct7b5, ex_alu_src;
    reg  [1:0]  ex_alu_op;
    reg         ex_branch, ex_jump, ex_jalr, ex_lui;
    reg  [1:0]  forward_a, forward_b;
    reg  [31:0] mem_fwd_data, wb_data;
    wire [31:0] ex_result, store_data, branch_target;
    wire        pc_src;

    integer pass_count = 0;
    integer fail_count = 0;

    ex_stage dut (
        .ex_pc(ex_pc), .ex_rd1(ex_rd1), .ex_rd2(ex_rd2), .ex_imm(ex_imm),
        .ex_funct3(ex_funct3), .ex_funct7b5(ex_funct7b5), .ex_alu_src(ex_alu_src),
        .ex_alu_op(ex_alu_op), .ex_branch(ex_branch), .ex_jump(ex_jump),
        .ex_jalr(ex_jalr), .ex_lui(ex_lui),
        .forward_a(forward_a), .forward_b(forward_b),
        .mem_fwd_data(mem_fwd_data), .wb_data(wb_data),
        .ex_result(ex_result), .store_data(store_data),
        .pc_src(pc_src), .branch_target(branch_target)
    );

    // Default: R-type ADD, no forwarding, no branch/jump
    task set_defaults;
        begin
            ex_pc = 32'h40; ex_rd1 = 32'd100; ex_rd2 = 32'd200; ex_imm = 32'd8;
            ex_funct3 = 3'b000; ex_funct7b5 = 1'b0; ex_alu_src = 1'b0;
            ex_alu_op = `ALUOP_RTYPE;
            ex_branch = 1'b0; ex_jump = 1'b0; ex_jalr = 1'b0; ex_lui = 1'b0;
            forward_a = 2'b00; forward_b = 2'b00;
            mem_fwd_data = 32'd1000; wb_data = 32'd2000;
        end
    endtask

    task check32(input [31:0] got, input [31:0] exp, input [511:0] name);
        begin
            if (got === exp) begin
                $display("PASS: %0s (%0d / 0x%h)", name, got, got);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s (got %0d / 0x%h, expected %0d / 0x%h)",
                         name, got, got, exp, exp);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("simulation/build/tb_ex_stage.vcd");
        $dumpvars(0, tb_ex_stage);

        // ---- Forwarding on operand A / B (R-type ADD) ----
        set_defaults; #1;
        check32(ex_result, 32'd300,  "fwd A=00 B=00: 100 + 200");
        forward_a = 2'b10; #1;
        check32(ex_result, 32'd1200, "fwd A=10 (EX/MEM): 1000 + 200");
        forward_a = 2'b01; #1;
        check32(ex_result, 32'd2200, "fwd A=01 (MEM/WB): 2000 + 200");
        forward_a = 2'b00; forward_b = 2'b10; #1;
        check32(ex_result, 32'd1100, "fwd B=10 (EX/MEM): 100 + 1000");
        forward_b = 2'b01; #1;
        check32(ex_result, 32'd2100, "fwd B=01 (MEM/WB): 100 + 2000");
        forward_a = 2'b10; forward_b = 2'b01; #1;
        check32(ex_result, 32'd3000, "fwd A=10 B=01: 1000 + 2000");
        forward_a = 2'b11; forward_b = 2'b11; #1;
        check32(ex_result, 32'd300,  "fwd 11 (unused) falls back to register values");

        // ---- R-type SUB with forwarding ----
        set_defaults; ex_funct7b5 = 1'b1; forward_b = 2'b10; #1;
        check32(ex_result, 32'hFFFFFC7C, "SUB 100 - 1000 (fwd B) = -900");

        // ---- I-type: immediate selected even if forward_b is set ----
        set_defaults; ex_alu_op = `ALUOP_ITYPE; ex_alu_src = 1'b1; forward_b = 2'b10; #1;
        check32(ex_result, 32'd108,  "ADDI 100 + 8 (alu_src ignores fwd B)");
        check32(store_data, 32'd1000, "store_data still forwarded rs2 value");

        // ---- SW: address = rs1 + imm, store_data = forwarded rs2 ----
        set_defaults; ex_alu_op = `ALUOP_ADD; ex_alu_src = 1'b1; ex_imm = 32'd12;
        forward_b = 2'b01; #1;
        check32(ex_result,  32'd112,  "SW address 100 + 12");
        check32(store_data, 32'd2000, "SW store_data from MEM/WB forward");
        forward_b = 2'b00; #1;
        check32(store_data, 32'd200,  "SW store_data from register file");

        // ---- LUI: 0 + imm, rs1 ignored even with forwarding ----
        set_defaults; ex_alu_op = `ALUOP_ADD; ex_alu_src = 1'b1; ex_lui = 1'b1;
        ex_imm = 32'h12345000; forward_a = 2'b10; #1;
        check32(ex_result, 32'h12345000, "LUI result = imm (operand A forced 0)");
        check32({31'd0, pc_src}, 32'd0,  "LUI does not redirect PC");

        // ---- JAL: result = pc + 4, target = pc + imm ----
        set_defaults; ex_alu_op = `ALUOP_ADD; ex_jump = 1'b1; ex_imm = 32'd32; #1;
        check32(ex_result,     32'h44, "JAL ex_result = pc + 4");
        check32(branch_target, 32'h60, "JAL target = pc + imm");
        check32({31'd0, pc_src}, 32'd1, "JAL pc_src = 1");

        // ---- JALR: result = pc + 4, target = (fwd rs1 + imm) & ~1 ----
        set_defaults; ex_alu_op = `ALUOP_ADD; ex_alu_src = 1'b1; ex_jalr = 1'b1;
        ex_imm = 32'd5; forward_a = 2'b10; #1;
        check32(ex_result,     32'h44,  "JALR ex_result = pc + 4");
        check32(branch_target, 32'd1004, "JALR target = (1000 + 5) & ~1");
        check32({31'd0, pc_src}, 32'd1, "JALR pc_src = 1");

        // ---- Branch decided on forwarded operands ----
        set_defaults; ex_alu_op = `ALUOP_BRANCH; ex_branch = 1'b1; ex_funct3 = 3'b000;
        ex_imm = 32'hFFFFFFF0; #1;
        check32({31'd0, pc_src}, 32'd0, "BEQ 100 vs 200 -> not taken");
        forward_a = 2'b10; forward_b = 2'b10; #1;
        check32({31'd0, pc_src}, 32'd1, "BEQ fwd 1000 vs 1000 -> taken");
        check32(branch_target, 32'h30,  "BEQ target = pc - 16");
        ex_funct3 = 3'b100; forward_a = 2'b00; forward_b = 2'b01; #1;
        check32({31'd0, pc_src}, 32'd1, "BLT 100 < 2000 (fwd B) -> taken");

        $display("--------------------------------------------");
        $display("tb_ex_stage SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("RESULT: PASS");
        else                 $display("RESULT: FAIL");
        $finish;
    end

endmodule
