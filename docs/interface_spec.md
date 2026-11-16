# Interface Specification — 5-Stage Pipelined RISC-V Processor

This document is the single shared contract for all team members. Every module must use exactly the
module names, port names, widths and instance names below so that the parts integrate without changes.
Questions or proposed changes go to the project lead (Abhishek) before any code is changed.

## 1. Scope

- ISA: RV32I subset (32-bit, 32 integer registers, `x0` hard-wired to 0).
- Pipeline: IF → ID → EX → MEM → WB with registers IF/ID, ID/EX, EX/MEM, MEM/WB.
- Hazard handling: forwarding unit (EX/MEM→EX, MEM/WB→EX), hazard detection unit (load-use stall,
  branch/jump flush), register-file write-first bypass (WB→ID).
- Language / tools: Verilog-2001 style, Icarus Verilog, GTKWave.

### Supported instructions

| Type | Instructions |
|------|--------------|
| R-type | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU |
| I-type ALU | ADDI, ANDI, ORI, XORI, SLTI, SLTIU, SLLI, SRLI, SRAI |
| Load / Store | LW, SW (word-aligned only) |
| Branch | BEQ, BNE, BLT, BGE |
| Jump | JAL, JALR |
| Upper immediate | LUI |

## 2. Coding rules

- `` `timescale 1ns/1ps `` at the top of every file; `` `include "defines.vh" `` where macros are used.
- Clock: rising edge of `clk`. Reset: synchronous, active-high `rst`.
- Compile: `iverilog -g2012 -I rtl -o simulation/build/<name>.vvp <files>`; run: `vvp simulation/build/<name>.vvp`.
- Every module has a self-checking unit testbench `testbench/unit/tb_<module>.v` that prints PASS/FAIL
  per check, a final summary, and dumps a VCD into `simulation/build/`.
- Only edit the files you own (see section 7).

## 3. Shared constants (`rtl/defines.vh`)

| Group | Macro | Value |
|-------|-------|-------|
| Opcode | `OP_RTYPE` | `7'b0110011` |
| Opcode | `OP_ITYPE` | `7'b0010011` |
| Opcode | `OP_LOAD` | `7'b0000011` |
| Opcode | `OP_STORE` | `7'b0100011` |
| Opcode | `OP_BRANCH` | `7'b1100011` |
| Opcode | `OP_JAL` | `7'b1101111` |
| Opcode | `OP_JALR` | `7'b1100111` |
| Opcode | `OP_LUI` | `7'b0110111` |
| ALU ctrl | `ALU_ADD` … `ALU_SLTU` | 0 ADD, 1 SUB, 2 AND, 3 OR, 4 XOR, 5 SLL, 6 SRL, 7 SRA, 8 SLT, 9 SLTU |
| alu_op | `ALUOP_ADD` | `2'b00` (LW/SW address, LUI) |
| alu_op | `ALUOP_BRANCH` | `2'b01` |
| alu_op | `ALUOP_RTYPE` | `2'b10` |
| alu_op | `ALUOP_ITYPE` | `2'b11` |
| Misc | `NOP` | `32'h00000013` (addi x0,x0,0) |

## 4. Micro-architecture decisions

1. Harvard memories: `instr_mem` and `data_mem`, 1024 words (4 KB) each, word index `addr[11:2]`,
   combinational read. `data_mem` writes on the rising clock edge. `instr_mem` is loaded with
   `$readmemh(MEM_FILE)`.
2. Branches and jumps are resolved in **EX** with predict-not-taken. When taken, IF/ID and ID/EX are
   flushed (2-cycle penalty).
3. JAL/JALR write PC+4: `ex_stage` outputs `ex_result = (jump | jalr) ? pc + 4 : alu_out`.
4. LUI: the ALU computes `0 + imm` (the `lui` flag forces ALU operand A to 0).
5. Forwarding encoding: `2'b10` = from EX/MEM, `2'b01` = from MEM/WB, `2'b00` = register file value.
   EX/MEM has priority.
6. Load-use hazard: 1-cycle stall (PC and IF/ID hold, bubble inserted into ID/EX).
7. Register file write-first bypass handles the WB→ID case.
8. Branch flush has priority over a load-use stall.
9. PC mux (top): `pc_next = pc_src ? branch_target : pc + 4`.
10. Write-back mux (top): `wb_data = wb_mem_to_reg ? wb_mem_rdata : wb_result`.

## 5. Main control truth table (`control_unit`)

| Opcode | reg_write | mem_read | mem_write | mem_to_reg | alu_src | alu_op | branch | jump | jalr | lui |
|--------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| R | 1 | 0 | 0 | 0 | 0 | 10 | 0 | 0 | 0 | 0 |
| I-ALU | 1 | 0 | 0 | 0 | 1 | 11 | 0 | 0 | 0 | 0 |
| LOAD | 1 | 1 | 0 | 1 | 1 | 00 | 0 | 0 | 0 | 0 |
| STORE | 0 | 0 | 1 | 0 | 1 | 00 | 0 | 0 | 0 | 0 |
| BRANCH | 0 | 0 | 0 | 0 | 0 | 01 | 1 | 0 | 0 | 0 |
| JAL | 1 | 0 | 0 | 0 | 0 | 00 | 0 | 1 | 0 | 0 |
| JALR | 1 | 0 | 0 | 0 | 1 | 00 | 0 | 0 | 1 | 0 |
| LUI | 1 | 0 | 0 | 0 | 1 | 00 | 0 | 0 | 0 | 1 |
| other | 0 | 0 | 0 | 0 | 0 | 00 | 0 | 0 | 0 | 0 |

## 6. Module port lists (binding)

All data buses are 32 bits unless noted. Register addresses are 5 bits.

```verilog
module pc_reg      (input clk, input rst, input en,
                    input [31:0] pc_next, output reg [31:0] pc);              // reset pc = 0

module instr_mem   #(parameter MEM_FILE = "", parameter DEPTH = 1024)
                   (input [31:0] addr, output [31:0] instr);

module if_id_reg   (input clk, input rst, input en, input flush,
                    input [31:0] if_pc, input [31:0] if_instr,
                    output reg [31:0] id_pc, output reg [31:0] id_instr);     // flush/reset -> NOP

module reg_file    (input clk, input rst, input we,
                    input [4:0] rs1, input [4:0] rs2, input [4:0] rd, input [31:0] wd,
                    output [31:0] rd1, output [31:0] rd2);                    // array: regs[0:31]

module imm_gen     (input [31:0] instr, output reg [31:0] imm);

module control_unit(input [6:0] opcode,
                    output reg reg_write, output reg mem_read, output reg mem_write,
                    output reg mem_to_reg, output reg alu_src, output reg [1:0] alu_op,
                    output reg branch, output reg jump, output reg jalr, output reg lui);

module id_ex_reg   (input clk, input rst, input flush,
                    input id_reg_write, id_mem_read, id_mem_write, id_mem_to_reg, id_alu_src,
                    input [1:0] id_alu_op, input id_branch, id_jump, id_jalr, id_lui,
                    input [31:0] id_pc, id_rd1, id_rd2, id_imm,
                    input [4:0] id_rs1, id_rs2, id_rd, input [2:0] id_funct3, input id_funct7b5,
                    output reg ex_reg_write, ex_mem_read, ex_mem_write, ex_mem_to_reg, ex_alu_src,
                    output reg [1:0] ex_alu_op, output reg ex_branch, ex_jump, ex_jalr, ex_lui,
                    output reg [31:0] ex_pc, ex_rd1, ex_rd2, ex_imm,
                    output reg [4:0] ex_rs1, ex_rs2, ex_rd, output reg [2:0] ex_funct3,
                    output reg ex_funct7b5);                                  // flush/reset -> 0

module alu_control (input [1:0] alu_op, input [2:0] funct3, input funct7b5,
                    output reg [3:0] alu_ctrl);

module alu         (input [31:0] a, input [31:0] b, input [3:0] alu_ctrl,
                    output reg [31:0] result, output zero);

module branch_unit (input branch, input jump, input jalr, input [2:0] funct3,
                    input [31:0] rs1_val, input [31:0] rs2_val, input [31:0] pc, input [31:0] imm,
                    output pc_src, output [31:0] branch_target);

module ex_stage    (input [31:0] ex_pc, ex_rd1, ex_rd2, ex_imm,
                    input [2:0] ex_funct3, input ex_funct7b5, input ex_alu_src,
                    input [1:0] ex_alu_op, input ex_branch, ex_jump, ex_jalr, ex_lui,
                    input [1:0] forward_a, forward_b,
                    input [31:0] mem_fwd_data, wb_data,
                    output [31:0] ex_result, store_data,
                    output pc_src, output [31:0] branch_target);

module ex_mem_reg  (input clk, input rst,
                    input ex_reg_write, ex_mem_read, ex_mem_write, ex_mem_to_reg,
                    input [31:0] ex_result, ex_store_data, input [4:0] ex_rd,
                    output reg mem_reg_write, mem_mem_read, mem_mem_write, mem_mem_to_reg,
                    output reg [31:0] mem_result, mem_store_data, output reg [4:0] mem_rd);

module data_mem    #(parameter DEPTH = 1024)
                   (input clk, input mem_read, input mem_write,
                    input [31:0] addr, input [31:0] wdata, output [31:0] rdata); // array: mem

module mem_wb_reg  (input clk, input rst,
                    input mem_reg_write, mem_mem_to_reg,
                    input [31:0] mem_result, mem_mem_rdata, input [4:0] mem_rd,
                    output reg wb_reg_write, wb_mem_to_reg,
                    output reg [31:0] wb_result, wb_mem_rdata, output reg [4:0] wb_rd);

module forwarding_unit(input [4:0] ex_rs1, ex_rs2, mem_rd, input mem_reg_write,
                       input [4:0] wb_rd, input wb_reg_write,
                       output reg [1:0] forward_a, forward_b);

module hazard_unit (input [4:0] id_rs1, id_rs2, ex_rd, input ex_mem_read, input pc_src,
                    output reg pc_write, if_id_write, if_id_flush, id_ex_flush);

module riscv_pipeline_top #(parameter IMEM_FILE = "") (input clk, input rst);
```

Naming rule for pipeline registers: an input is the signal name with the source-stage prefix
(`id_`, `ex_`, `mem_`), the output is the same name with the destination-stage prefix. Because the
memory-control signals already start with `mem_`, the EX/MEM outputs are `mem_mem_read`,
`mem_mem_write`, `mem_mem_to_reg`, and the MEM/WB data input is `mem_mem_rdata`.

### Instance names inside `riscv_pipeline_top`

`u_pc, u_imem, u_if_id, u_reg_file, u_control, u_imm_gen, u_id_ex, u_ex_stage, u_ex_mem, u_dmem,
u_mem_wb, u_fwd, u_hazard`

The system testbench reads `dut.u_reg_file.regs[i]` and `dut.u_dmem.mem[i]`.

## 7. File ownership

| Member | Files |
|--------|-------|
| Abhishek Kumar Patel (2401010020) | `README.md`, `.gitignore`, `rtl/defines.vh`, `docs/interface_spec.md`, `rtl/pc_reg.v`, `rtl/instr_mem.v`, `rtl/if_id_reg.v`, `rtl/riscv_pipeline_top.v`, `testbench/unit/tb_pc_reg.v`, `tb_instr_mem.v`, `tb_if_id_reg.v`, `testbench/programs/smoke.hex`, report: `abstract_intro.tex`, `ps_architecture_if.tex`, `contrib_abhishek.tex`, `refs_abhishek.bib` |
| Yogesh Modi (2401010519) | `rtl/reg_file.v`, `rtl/imm_gen.v`, `rtl/control_unit.v`, `rtl/id_ex_reg.v`, their unit testbenches, report: `literature_review.tex`, `ps_id_stage.tex`, `contrib_yogesh.tex`, `refs_yogesh.bib` |
| Kapish Rohilla (2401010210) | `rtl/alu.v`, `rtl/alu_control.v`, `rtl/branch_unit.v`, `rtl/ex_stage.v`, `rtl/ex_mem_reg.v`, their unit testbenches, report: `ps_ex_stage.tex`, `contrib_kapish.tex`, `refs_kapish.bib` |
| Vikash Kumar (2401010503) | `rtl/data_mem.v`, `rtl/mem_wb_reg.v`, `rtl/forwarding_unit.v`, `rtl/hazard_unit.v`, their unit testbenches, report: `ps_mem_wb_hazards.tex`, `contrib_vikash.tex`, `refs_vikash.bib` |
| Prateek Shakya (2401020048) | `testbench/tb_riscv_top.v`, `testbench/programs/test*.s/.hex`, `simulation/run_all.sh`, `simulation/README.md`, `diagrams/*`, `docs/report/main.tex`, `ps_verification.tex`, `contrib_prateek.tex`, `refs_prateek.bib`, `docs/report/Phase1_Report.pdf`, `docs/video_script.md`, `video/README.md` |

## 8. Branches and merge order

| Branch | Owner |
|--------|-------|
| `part1-setup`, `part1-if-stage`, `part1-report`, `part1-top-integration` | Abhishek |
| `part2-id-stage` | Yogesh |
| `part3-ex-stage` | Kapish |
| `part4-mem-wb-hazards` | Vikash |
| `part5-verification-docs` | Prateek |

Merge order into `main`: `part1-setup` → `part1-if-stage` → parts 2, 3, 4 (any order) →
`part1-top-integration` → `part5-verification-docs`. Always `git pull origin main` before opening a PR.
