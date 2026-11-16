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

Run all unit tests and system programs from the repository root:

```sh
./simulation/run_all.sh
```

Run one system test:

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
