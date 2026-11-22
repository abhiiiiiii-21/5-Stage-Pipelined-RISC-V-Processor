#!/usr/bin/env bash
# =============================================================================
# Script      : synth/breakdown.sh
# Description : Per-module (per-stage) resource breakdown of the pipeline.
#               Runs synth_ecp5 with -noflatten so that every module keeps its
#               own cell counts, then tabulates them with breakdown.py.
#
# Usage       : bash synth/breakdown.sh <program.hex>
# Output      : synth/reports/pipeline_breakdown.txt
#
# Note        : without flattening, yosys cannot move the IF/ID and MEM/WB
#               registers into the memories, so instr_mem becomes a LUT ROM and
#               data_mem becomes LUT RAM here, while the flat run of
#               run_synth.sh maps both to block RAM (DP16KD). The totals of the
#               two runs therefore differ; the flat run is the one in
#               summary.csv.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

[ $# -eq 1 ] || { echo "Usage: bash synth/breakdown.sh <program.hex>"; exit 2; }
PROG="$1"
TOP=riscv_pipeline_top
[ -f "$PROG" ] || { echo "ERROR: program file '$PROG' not found"; exit 2; }
command -v yosys >/dev/null 2>&1 || { echo "ERROR: yosys not found"; exit 2; }

mkdir -p synth/build synth/reports
STAT="synth/build/pipeline_noflatten_stat.json"
HDR="synth/build/pipeline_noflatten_header.txt"
SCRIPT="read_verilog -I rtl rtl/*.v; hierarchy; \
chparam -set IMEM_FILE \"$PROG\" $TOP; \
synth_ecp5 -noflatten -top $TOP; tee -q -o $STAT stat -json"

yosys -q -l synth/build/pipeline_noflatten_yosys.log -p "$SCRIPT" >/dev/null

{
    echo "# yosys   : $(yosys -V)"
    echo "# design  : pipeline ($TOP), synth_ecp5 -noflatten"
    echo "# program : $PROG"
    echo "# device  : Lattice ECP5 (synthesis only, no place-and-route)"
    echo "# columns : LUT4 = logic LUTs, FF = TRELLIS_FF, CARRY = CCU2C (2-bit"
    echo "#           carry cells), LUTRAM = TRELLIS_DPR16X4, BRAM = DP16KD"
    echo "# note    : without flattening the memories are not merged with the"
    echo "#           pipeline registers, so instr_mem is a LUT ROM and data_mem"
    echo "#           is LUT RAM in this table (block RAM in the flat run)."
} > "$HDR"

python3 synth/breakdown.py "$STAT" "$HDR" > synth/reports/pipeline_breakdown.txt
cat synth/reports/pipeline_breakdown.txt
