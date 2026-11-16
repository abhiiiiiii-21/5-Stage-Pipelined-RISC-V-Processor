# Diagrams

Rendered figures (PNG and SVG). They are the same figures used in the IEEE report
(`report/main.pdf`); their LaTeX/TikZ source is in `report/main.tex`.

| File | Shows |
|------|-------|
| `block_diagram` | Five-stage datapath with pipeline registers, forwarding paths and hazard control |
| `load_use_timing` | Pipeline timing of a load-use dependency: one-cycle stall, then MEM/WB forwarding |
| `branch_flush_timing` | Taken branch resolved in EX and the two flushed instructions (test 5) |
| `hazard_unit_flowchart` | Decision order of the hazard detection unit (flush before stall) |
| `waveform_test4` | Key signals of system test 4 redrawn from the simulation trace |
| `cpi_cycles_comparison` | Measured cycles per test program versus a non-pipelined baseline |
| `design_flow` | Team design and verification flow |

The Mermaid files are simple text sketches of the same structure:

- `datapath.mmd`: five-stage data path and control connections.
- `pipeline_timing.mmd`: normal, load-use and taken-branch timing summary.
- `hazard_forwarding.mmd`: EX/MEM and MEM/WB forwarding priority.

GTKWave waveforms come from running the tests (see `simulation/README.md`), for example
`gtkwave simulation/build/tb_riscv_top_4.vcd`.
