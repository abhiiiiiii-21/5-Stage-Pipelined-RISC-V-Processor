# Simulation Guide

## Prerequisites

Install Icarus Verilog (`iverilog` and `vvp`). GTKWave is optional for viewing waveforms.

```sh
# macOS
brew install icarus-verilog
brew install --cask gtkwave

# Debian/Ubuntu
sudo apt-get install iverilog gtkwave
```

Run the complete regression suite from the repository root:

```sh
bash simulation/run_all.sh
```

This runs 17 unit testbenches, six Phase I pipeline programs, six Phase I
single-cycle baseline programs, twelve benchmark/design combinations and twelve
pipeline-versus-baseline equivalence programs. Build and log files are written
under `simulation/build/`.

Run benchmark tests only:

```sh
bash simulation/run_bench.sh
```

Run differential equivalence tests only:

```sh
bash simulation/run_equiv.sh
```

Run one pipeline system test:

```sh
mkdir -p simulation/build
iverilog -g2012 -I rtl -DTEST=4 -s tb_riscv_top \
  -o simulation/build/tb_riscv_top_4.vvp rtl/*.v testbench/tb_riscv_top.v
vvp simulation/build/tb_riscv_top_4.vvp +VCD=simulation/build/tb_riscv_top_4.vcd
```

The script writes one VCD file and one log per system test to `simulation/build/`.
Open a waveform with:

```sh
gtkwave simulation/build/tb_riscv_top_4.vcd
```

Useful signals to add are `dut.u_pc.pc`, `dut.if_instr`, `dut.id_instr`,
`dut.ex_result`, `dut.mem_result`, `dut.wb_data`, `dut.forward_a`,
`dut.forward_b`, `dut.pc_write`, `dut.if_id_flush`, and `dut.id_ex_flush`.
The register file and data memory can also be inspected as
`dut.u_reg_file.regs` and `dut.u_dmem.mem`.
