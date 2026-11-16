`timescale 1ns/1ps
`include "defines.vh"
// =============================================================================
// Testbench   : tb_control_unit
// Description : Self-checking unit test for control_unit.
//               Checks every row of the control truth table (R, I-ALU, LOAD,
//               STORE, BRANCH, JAL, JALR, LUI) and unknown opcodes, which must
//               give all-zero (NOP) control signals.
//               Outputs are compared as one 11-bit vector:
//               {reg_write, mem_read, mem_write, mem_to_reg, alu_src,
//                alu_op[1:0], branch, jump, jalr, lui}
// Run         : iverilog -g2012 -I rtl -o simulation/build/tb_control_unit.vvp \
//                   rtl/control_unit.v testbench/unit/tb_control_unit.v
//               vvp simulation/build/tb_control_unit.vvp
// =============================================================================
module tb_control_unit;

    reg  [6:0] opcode;
    wire       reg_write, mem_read, mem_write, mem_to_reg, alu_src;
    wire [1:0] alu_op;
    wire       branch, jump, jalr, lui;

    wire [10:0] ctrl = {reg_write, mem_read, mem_write, mem_to_reg, alu_src,
                        alu_op, branch, jump, jalr, lui};

    integer pass_count = 0;
    integer fail_count = 0;

    control_unit dut (
        .opcode(opcode),
        .reg_write(reg_write), .mem_read(mem_read), .mem_write(mem_write),
        .mem_to_reg(mem_to_reg), .alu_src(alu_src), .alu_op(alu_op),
        .branch(branch), .jump(jump), .jalr(jalr), .lui(lui)
    );

    task check(input [6:0] op, input [10:0] exp, input [511:0] name);
        begin
            opcode = op; #1;
            if (ctrl === exp) begin
                $display("PASS: %0s (opcode %07b -> %011b)", name, op, ctrl);
                pass_count = pass_count + 1;
            end else begin
                $display("FAIL: %0s (opcode %07b -> %011b, expected %011b)",
                         name, op, ctrl, exp);
                fail_count = fail_count + 1;
            end
        end
    endtask

    initial begin
        $dumpfile("simulation/build/tb_control_unit.vcd");
        $dumpvars(0, tb_control_unit);

        //                        rw mr mw m2r as  aluop br j jr lui
        check(`OP_RTYPE,  11'b1___0__0__0___0___10___0__0__0__0, "R-type");
        check(`OP_ITYPE,  11'b1___0__0__0___1___11___0__0__0__0, "I-type ALU");
        check(`OP_LOAD,   11'b1___1__0__1___1___00___0__0__0__0, "LOAD (lw)");
        check(`OP_STORE,  11'b0___0__1__0___1___00___0__0__0__0, "STORE (sw)");
        check(`OP_BRANCH, 11'b0___0__0__0___0___01___1__0__0__0, "BRANCH");
        check(`OP_JAL,    11'b1___0__0__0___0___00___0__1__0__0, "JAL");
        check(`OP_JALR,   11'b1___0__0__0___1___00___0__0__1__0, "JALR");
        check(`OP_LUI,    11'b1___0__0__0___1___00___0__0__0__1, "LUI");

        // Unknown / unsupported opcodes -> all zeros (safe NOP)
        check(7'b0010111, 11'b0, "unknown: AUIPC (not supported)");
        check(7'b0000000, 11'b0, "unknown: all-zero opcode");
        check(7'b1111111, 11'b0, "unknown: all-one opcode");

        $display("--------------------------------------------");
        $display("tb_control_unit SUMMARY: %0d passed, %0d failed", pass_count, fail_count);
        if (fail_count == 0) $display("RESULT: PASS");
        else                 $display("RESULT: FAIL");
        $finish;
    end

endmodule
