`timescale 1ns/1ps
// Self-checking unit test for forwarding_unit.
// Run: iverilog -g2012 -I rtl -o simulation/build/tb_forwarding_unit.vvp rtl/forwarding_unit.v testbench/unit/tb_forwarding_unit.v
//      vvp simulation/build/tb_forwarding_unit.vvp
module tb_forwarding_unit;
    reg [4:0] ex_rs1, ex_rs2, mem_rd, wb_rd;
    reg mem_reg_write, wb_reg_write;
    wire [1:0] forward_a, forward_b;
    integer pass_count = 0, fail_count = 0;

    forwarding_unit dut (.ex_rs1(ex_rs1), .ex_rs2(ex_rs2), .mem_rd(mem_rd),
        .mem_reg_write(mem_reg_write), .wb_rd(wb_rd), .wb_reg_write(wb_reg_write),
        .forward_a(forward_a), .forward_b(forward_b));

    task check(input [1:0] exp_a, input [1:0] exp_b, input [255:0] name);
        begin
            #1;
            if (forward_a === exp_a && forward_b === exp_b) begin
                $display("PASS: %0s (A=%b B=%b)", name, forward_a, forward_b);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s (A=%b B=%b, expected A=%b B=%b)", name, forward_a, forward_b, exp_a, exp_b);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("simulation/build/tb_forwarding_unit.vcd");
        $dumpvars(0, tb_forwarding_unit);

        ex_rs1 = 5; ex_rs2 = 6; mem_rd = 1; wb_rd = 2; mem_reg_write = 1; wb_reg_write = 1;
        check(2'b00, 2'b00, "no hazard");

        mem_rd = 5;
        check(2'b10, 2'b00, "EX/MEM -> rs1");
        mem_rd = 6;
        check(2'b00, 2'b10, "EX/MEM -> rs2");

        mem_rd = 1; wb_rd = 5;
        check(2'b01, 2'b00, "MEM/WB -> rs1");
        wb_rd = 6;
        check(2'b00, 2'b01, "MEM/WB -> rs2");

        mem_rd = 5; wb_rd = 5; ex_rs2 = 5;
        check(2'b10, 2'b10, "both match: EX/MEM wins on A and B");

        ex_rs1 = 5; ex_rs2 = 6; mem_rd = 5; wb_rd = 6;
        check(2'b10, 2'b01, "A from EX/MEM, B from MEM/WB");

        ex_rs1 = 0; ex_rs2 = 0; mem_rd = 0; wb_rd = 0;
        check(2'b00, 2'b00, "rd = x0 never forwards");

        ex_rs1 = 5; ex_rs2 = 5; mem_rd = 5; wb_rd = 5; mem_reg_write = 0; wb_reg_write = 0;
        check(2'b00, 2'b00, "reg_write=0 never forwards");

        mem_reg_write = 0; wb_reg_write = 1;
        check(2'b01, 2'b01, "MEM no write, WB write -> MEM/WB forward");

        $display("--------------------------------------------");
        $display("tb_forwarding_unit SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
        $finish;
    end
endmodule
