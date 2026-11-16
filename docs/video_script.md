# Phase-I Demonstration Script (under 5 minutes)

## 0:00–1:00 — Abhishek

“Our project is a 32-bit five-stage pipelined RISC-V processor implemented in Verilog.
The stages are instruction fetch, instruction decode, execute, memory, and write-back.
Pipelining overlaps instructions to improve throughput, while forwarding, stalling, and
flushing handle data and control hazards. Our team is Abhishek Kumar Patel, Yogesh Modi,
Kapish Rohilla, Vikash Kumar, and Prateek Shakya.”

## 1:00–1:45 — Yogesh

“I implemented the decode-side modules. The register file provides two reads and one
write, the immediate generator supports the required RV32I formats, and the control unit
converts opcodes into pipeline control signals. The ID/EX register carries decoded data
and controls into execute.”

## 1:45–2:30 — Kapish

“The execute stage selects the ALU operation, applies forwarding to both operands, and
computes arithmetic, logical, shift, and comparison results. Branch and jump decisions
are resolved here. The EX/MEM register carries the result and store data into memory.”

## 2:30–3:20 — Vikash

“The memory stage implements word-aligned loads and stores. The MEM/WB register carries
results to write-back. The forwarding unit chooses EX/MEM before MEM/WB, and the hazard
unit inserts a one-cycle bubble for a load-use dependency. A taken branch or jump flushes
the younger instructions.”

## 3:20–4:30 — Prateek

“I am running the verification suite with `./simulation/run_all.sh`. The unit tests check
individual modules, while six system programs cover arithmetic, load/store, forwarding,
load-use hazards, branches and jumps, and an array sum. I can open the generated VCD in
GTKWave and inspect the PC, pipeline instructions, forwarding selections, and flush and
stall controls. The Mermaid sources document the complete datapath and hazard paths.”

## 4:30–4:50 — Closing

“This prototype demonstrates a working RV32I subset processor and a repeatable verification
workflow. The repository contains the RTL, self-checking tests, programs, simulation script,
and design diagrams.”
