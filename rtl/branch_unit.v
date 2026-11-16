`timescale 1ns/1ps
// =============================================================================
// Module      : branch_unit
// Stage       : EX
// Description : Resolves branches and jumps in the EX stage (the pipeline
//               predicts not-taken, so a taken result flushes IF/ID and
//               ID/EX - a 2-cycle penalty).
//               Branch condition by funct3:
//                 000 BEQ  rs1 == rs2
//                 001 BNE  rs1 != rs2
//                 100 BLT  rs1 <  rs2 (signed)
//                 101 BGE  rs1 >= rs2 (signed)
//               pc_src        = (branch && condition) || jump || jalr
//               branch_target = jalr ? (rs1 + imm) & ~1   (JALR clears bit 0)
//                                    : pc + imm           (branches, JAL)
// Ports       : branch, jump, jalr - instruction type flags (from ID/EX)
//               funct3             - branch type
//               rs1_val, rs2_val   - forwarded register operands
//               pc, imm            - PC of the instruction and its immediate
//               pc_src             - 1 = redirect fetch to branch_target
//               branch_target      - new PC when pc_src = 1
// =============================================================================
module branch_unit (
    input         branch,
    input         jump,
    input         jalr,
    input  [2:0]  funct3,
    input  [31:0] rs1_val,
    input  [31:0] rs2_val,
    input  [31:0] pc,
    input  [31:0] imm,
    output        pc_src,
    output [31:0] branch_target
);

    reg cond;

    always @(*) begin
        case (funct3)
            3'b000:  cond = (rs1_val == rs2_val);                    // BEQ
            3'b001:  cond = (rs1_val != rs2_val);                    // BNE
            3'b100:  cond = ($signed(rs1_val) <  $signed(rs2_val));  // BLT
            3'b101:  cond = ($signed(rs1_val) >= $signed(rs2_val));  // BGE
            default: cond = 1'b0;                                    // unsupported
        endcase
    end

    assign pc_src        = (branch && cond) || jump || jalr;
    assign branch_target = jalr ? ((rs1_val + imm) & ~32'd1) : (pc + imm);

endmodule
