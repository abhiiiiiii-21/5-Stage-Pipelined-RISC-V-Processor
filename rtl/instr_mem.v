`timescale 1ns/1ps
`include "defines.vh"
// =============================================================================
// Module      : instr_mem
// Stage       : IF (Instruction Fetch)
// Description : Instruction memory (read-only during simulation).
//               - DEPTH words of 32 bits (default 1024 words = 4 KB).
//               - Every word is first filled with NOP, then the program is
//                 loaded from the hex file MEM_FILE using $readmemh
//                 (one 32-bit hex word per line).
//               - Combinational read: instr = mem[addr[11:2]].
//                 addr is a byte address; bits [1:0] are ignored because all
//                 instructions are word aligned.
// Parameters  : MEM_FILE - path of the program hex file ("" = no program)
//               DEPTH    - number of 32-bit words
// Ports       : addr  - byte address (the PC)
//               instr - instruction at that address
// =============================================================================
module instr_mem #(
    parameter MEM_FILE = "",
    parameter DEPTH    = 1024
) (
    input  [31:0] addr,
    output [31:0] instr
);

    reg [31:0] mem [0:DEPTH-1];

    integer i;
    initial begin
`ifndef SYNTHESIS
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = `NOP;
`endif
        if (MEM_FILE != "")
            $readmemh(MEM_FILE, mem);
    end

    // Word index = byte address / 4. With DEPTH = 1024 this is addr[11:2].
    assign instr = mem[addr[$clog2(DEPTH)+1:2]];

endmodule
