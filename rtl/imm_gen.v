`timescale 1ns/1ps
`include "defines.vh"
// =============================================================================
// Module      : imm_gen
// Stage       : ID (Instruction Decode)
// Description : Immediate generator. Extracts the immediate field of the
//               instruction and sign-extends it to 32 bits. The instruction
//               format is selected by the opcode (instr[6:0]):
//                 I-type : OP_ITYPE, OP_LOAD, OP_JALR  -> imm[11:0]
//                 S-type : OP_STORE                    -> imm[11:5] | imm[4:0]
//                 B-type : OP_BRANCH                   -> imm[12:1], imm[0] = 0
//                 U-type : OP_LUI                      -> imm[31:12], low 12 = 0
//                 J-type : OP_JAL                      -> imm[20:1], imm[0] = 0
//                 other  : 0 (R-type has no immediate)
//               In every format the sign bit is instr[31], which is why the
//               RISC-V encoding keeps it in the same position.
//               For SLLI/SRLI/SRAI the I-type immediate also carries funct7;
//               the ALU only uses the low 5 bits (shamt) as the shift amount.
// Ports       : instr - 32-bit instruction in the ID stage
//               imm   - 32-bit sign-extended immediate
// =============================================================================
module imm_gen (
    input      [31:0] instr,
    output reg [31:0] imm
);

    always @(*) begin
        case (instr[6:0])
            // I-type: instr[31:20]
            `OP_ITYPE,
            `OP_LOAD,
            `OP_JALR:   imm = {{20{instr[31]}}, instr[31:20]};

            // S-type: instr[31:25] = imm[11:5], instr[11:7] = imm[4:0]
            `OP_STORE:  imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

            // B-type: imm[12|10:5|4:1|11], bit 0 is always 0 (2-byte aligned)
            `OP_BRANCH: imm = {{19{instr[31]}}, instr[31], instr[7],
                               instr[30:25], instr[11:8], 1'b0};

            // U-type: upper 20 bits, lower 12 bits are zero
            `OP_LUI:    imm = {instr[31:12], 12'b0};

            // J-type: imm[20|10:1|11|19:12], bit 0 is always 0
            `OP_JAL:    imm = {{11{instr[31]}}, instr[31], instr[19:12],
                               instr[20], instr[30:21], 1'b0};

            default:    imm = 32'd0;
        endcase
    end

endmodule
