`timescale 1ns/1ps
// =============================================================================
// Module      : hazard_unit
// Stage       : ID (hazard logic)
// Description : Load-use stall and branch/jump flush control.
//               pc_src (taken branch/jump) has priority: flush IF/ID and ID/EX,
//               keep PC and IF/ID enabled so the target is fetched.
//               Load-use: freeze PC and IF/ID one cycle, bubble into ID/EX.
// Ports       : id_rs1/id_rs2, ex_rd, ex_mem_read, pc_src;
//               pc_write, if_id_write, if_id_flush, id_ex_flush
// =============================================================================
module hazard_unit (
    input  [4:0] id_rs1,
    input  [4:0] id_rs2,
    input  [4:0] ex_rd,
    input        ex_mem_read,
    input        pc_src,
    output       pc_write,
    output       if_id_write,
    output       if_id_flush,
    output       id_ex_flush
);

    wire load_use = ex_mem_read && (ex_rd != 5'd0) &&
                    (ex_rd == id_rs1 || ex_rd == id_rs2);

    assign pc_write    = pc_src ? 1'b1 : ~load_use;
    assign if_id_write = pc_src ? 1'b1 : ~load_use;
    assign if_id_flush = pc_src;
    assign id_ex_flush = pc_src | load_use;

endmodule
