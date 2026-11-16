`timescale 1ns/1ps
// Self-checking unit test for hazard_unit.
// Run: iverilog -g2012 -I rtl -o simulation/build/tb_hazard_unit.vvp rtl/hazard_unit.v testbench/unit/tb_hazard_unit.v
//      vvp simulation/build/tb_hazard_unit.vvp
module tb_hazard_unit;
    reg [4:0] id_rs1, id_rs2, ex_rd;
    reg ex_mem_read, pc_src;
    wire pc_write, if_id_write, if_id_flush, id_ex_flush;
    integer pass_count = 0, fail_count = 0;

    hazard_unit dut (.id_rs1(id_rs1), .id_rs2(id_rs2), .ex_rd(ex_rd), .ex_mem_read(ex_mem_read),
        .pc_src(pc_src), .pc_write(pc_write), .if_id_write(if_id_write),
        .if_id_flush(if_id_flush), .id_ex_flush(id_ex_flush));

    task check(input e_pcw, input e_iiw, input e_iif, input e_idf, input [255:0] name);
        begin
            #1;
            if (pc_write === e_pcw && if_id_write === e_iiw && if_id_flush === e_iif && id_ex_flush === e_idf) begin
                $display("PASS: %0s", name);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s (pc_write=%b if_id_write=%b if_id_flush=%b id_ex_flush=%b)", name,
                         pc_write, if_id_write, if_id_flush, id_ex_flush);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("simulation/build/tb_hazard_unit.vcd");
        $dumpvars(0, tb_hazard_unit);

        id_rs1 = 1; id_rs2 = 2; ex_rd = 9; ex_mem_read = 0; pc_src = 0;
        check(1, 1, 0, 0, "no hazard");

        ex_rd = 1; ex_mem_read = 1;
        check(0, 0, 0, 1, "load-use on rs1 -> stall + bubble");

        ex_rd = 2;
        check(0, 0, 0, 1, "load-use on rs2 -> stall + bubble");

        ex_rd = 0; id_rs1 = 0;
        check(1, 1, 0, 0, "no stall when ex_rd = x0");

        id_rs1 = 1; ex_rd = 1; ex_mem_read = 0;
        check(1, 1, 0, 0, "no stall when EX is not a load");

        pc_src = 1; ex_mem_read = 0; ex_rd = 9;
        check(1, 1, 1, 1, "taken branch flushes IF/ID and ID/EX");

        ex_rd = 1; ex_mem_read = 1;
        check(1, 1, 1, 1, "branch + load-use together: flush wins");

        $display("--------------------------------------------");
        $display("tb_hazard_unit SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("RESULT: PASS"); else $display("RESULT: FAIL");
        $finish;
    end
endmodule
