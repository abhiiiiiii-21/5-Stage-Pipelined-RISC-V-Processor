`timescale 1ns/1ps
`include "defines.vh"
// =============================================================================
// Module      : alu
// Stage       : EX
// Description : 32-bit combinational Arithmetic Logic Unit. Performs one of
//               the 10 operations selected by the 4-bit alu_ctrl code
//               (ALU_* macros in defines.vh):
//                 ADD, SUB, AND, OR, XOR   - arithmetic / bitwise
//                 SLL, SRL, SRA            - shifts by b[4:0] (0..31)
//                 SLT  - signed   compare, result = 1 if a < b else 0
//                 SLTU - unsigned compare, result = 1 if a < b else 0
//               Unknown codes give result = 0.
//               zero = 1 when result is 0 (kept for debug; branch decisions
//               are made in branch_unit, not from this flag).
// Ports       : a, b      - 32-bit operands
//               alu_ctrl  - operation select (from alu_control)
//               result    - 32-bit result
//               zero      - result == 0
// =============================================================================
module alu (
    input      [31:0] a,
    input      [31:0] b,
    input      [3:0]  alu_ctrl,
    output reg [31:0] result,
    output            zero
);

    always @(*) begin
        case (alu_ctrl)
            `ALU_ADD:  result = a + b;
            `ALU_SUB:  result = a - b;
            `ALU_AND:  result = a & b;
            `ALU_OR:   result = a | b;
            `ALU_XOR:  result = a ^ b;
            `ALU_SLL:  result = a << b[4:0];
            `ALU_SRL:  result = a >> b[4:0];
            // >>> on a signed operand copies the sign bit into the vacated bits
            `ALU_SRA:  result = $signed(a) >>> b[4:0];
            `ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            `ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;
            default:   result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);

endmodule
