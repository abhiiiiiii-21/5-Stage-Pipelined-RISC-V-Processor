#!/usr/bin/env bash
# =============================================================================
# Script      : synth/run_synth.sh
# Description : Synthesis (Yosys) and place-and-route (nextpnr) of one design,
#               with resource utilisation and maximum frequency (Fmax).
#
# Usage       : bash synth/run_synth.sh <pipeline|single> <program.hex> [ecp5|hx8k]
#               (run from any directory; paths are relative to the repo root)
#
# Devices     : ecp5 (default) - Lattice ECP5 LFE5U-85F, CABGA381 package.
#                                Both designs fit; these runs fill
#                                synth/reports/summary.csv.
#               hx8k           - Lattice iCE40 HX8K, CT256 package. Kept for
#                                reference: the single-cycle design does not
#                                fit on this device (see its report).
#
# Flow        : 1. yosys: read_verilog -I rtl rtl/*.v; hierarchy;
#                  chparam -set IMEM_FILE "<program.hex>" <top>;
#                  synth_<family> -top <top> -json synth/build/<run>.json; stat
#               2. check_rom.py: the program words must be in the instruction
#                  ROM (stops the flow if the program was optimised away)
#               3. nextpnr --freq F --seed 1. If the target F is met, F is
#                  raised and place-and-route is repeated until it fails, so
#                  the last reported Fmax is the real limit of the design.
#               4. ECP5 runs: the post-placement utilisation (TRELLIS_COMB,
#                  TRELLIS_FF, DP16KD) and Fmax replace that design's row in
#                  synth/reports/summary.csv.
#
# Outputs     : synth/reports/<design>[_hx8k]_yosys.txt    full yosys log
#               synth/reports/<design>[_hx8k]_nextpnr.txt  log of the final
#                                                          nextpnr run
#               synth/reports/summary.csv  design,luts,ffs,brams,fmax_mhz
#               Every .txt report starts with the tool versions and settings.
# =============================================================================
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

usage() {
    echo "Usage: bash synth/run_synth.sh <pipeline|single> <program.hex> [ecp5|hx8k]"
    exit 2
}

[ $# -ge 2 ] || usage
DESIGN="$1"
PROG="$2"
DEVICE="${3:-ecp5}"

SEED=1          # fixed placer seed, so every run is reproducible
START_FREQ=50   # first nextpnr target frequency in MHz
MAX_RUNS=10     # upper bound on the number of nextpnr runs

case "$DESIGN" in
    pipeline) TOP=riscv_pipeline_top ;;
    single)   TOP=riscv_single_cycle_top ;;
    *)        usage ;;
esac

case "$DEVICE" in
    ecp5)
        SYNTH_CMD=synth_ecp5
        PNR=nextpnr-ecp5
        PNR_ARGS=(--85k --package CABGA381)
        DEVICE_NAME="Lattice ECP5 LFE5U-85F (CABGA381)"
        RUN="$DESIGN"
        ;;
    hx8k)
        SYNTH_CMD=synth_ice40
        PNR=nextpnr-ice40
        PNR_ARGS=(--hx8k --package ct256)
        DEVICE_NAME="Lattice iCE40 HX8K (CT256)"
        RUN="${DESIGN}_hx8k"
        ;;
    *)  usage ;;
esac

[ -f "$PROG" ] || { echo "ERROR: program file '$PROG' not found"; exit 2; }
for tool in yosys "$PNR" python3; do
    command -v "$tool" >/dev/null 2>&1 || {
        echo "ERROR: '$tool' not found. Install the OSS CAD Suite"
        echo "(https://github.com/YosysHQ/oss-cad-suite-build) and add its bin/ to PATH."
        exit 2
    }
done

mkdir -p synth/build synth/reports
BUILD="synth/build"
REPORTS="synth/reports"
JSON="$BUILD/$RUN.json"

YOSYS_VER="$(yosys -V)"
PNR_VER="$("$PNR" --version 2>&1 | head -n 1)"

header() {
    echo "# yosys   : $YOSYS_VER"
    echo "# nextpnr : $PNR_VER"
    echo "# design  : $DESIGN ($TOP)"
    echo "# program : $PROG"
    echo "# device  : $DEVICE_NAME"
}

# ---------------------------------------------------------------------------
# 1. Synthesis
# ---------------------------------------------------------------------------
echo "[$RUN] yosys $SYNTH_CMD ..."
YOSYS_SCRIPT="read_verilog -I rtl rtl/*.v; hierarchy; \
chparam -set IMEM_FILE \"$PROG\" $TOP; \
$SYNTH_CMD -top $TOP -json $JSON; stat"
yosys -q -l "$BUILD/${RUN}_yosys.log" -p "$YOSYS_SCRIPT" >/dev/null
{ header; echo "# command : yosys -p '$YOSYS_SCRIPT'"; echo
  cat "$BUILD/${RUN}_yosys.log"; } > "$REPORTS/${RUN}_yosys.txt"

# ---------------------------------------------------------------------------
# 2. Sanity check: the program must be in the instruction ROM
# ---------------------------------------------------------------------------
yosys -q -p "read_verilog -I rtl rtl/*.v; hierarchy; \
chparam -set IMEM_FILE \"$PROG\" $TOP; hierarchy -top $TOP; \
proc; flatten; opt_clean; memory_collect; write_rtlil $BUILD/${RUN}_mem.il" >/dev/null
python3 synth/check_rom.py "$BUILD/${RUN}_mem.il" "$PROG"

# ---------------------------------------------------------------------------
# 3. Place and route, raising the target until it is no longer met
# ---------------------------------------------------------------------------
freq=$START_FREQ
attempts=""
fmax=""
for run_no in $(seq 1 "$MAX_RUNS"); do
    echo "[$RUN] $PNR --freq $freq --seed $SEED ..."
    log="$BUILD/${RUN}_nextpnr.log"
    if ! "$PNR" "${PNR_ARGS[@]}" --json "$JSON" --freq "$freq" --seed "$SEED" \
         --timing-allow-fail -l "$log" >/dev/null 2>&1; then
        # Placement or routing failed (for example the design does not fit).
        { header; echo "# seed    : $SEED, target $freq MHz"
          echo "# result  : place-and-route FAILED, no Fmax"; echo
          cat "$log"; } > "$REPORTS/${RUN}_nextpnr.txt"
        echo "[$RUN] place-and-route FAILED, see $REPORTS/${RUN}_nextpnr.txt"
        exit 1
    fi
    # The last "Max frequency" line is the post-route timing result.
    line="$(grep 'Max frequency for clock' "$log" | tail -n 1)"
    fmax="$(echo "$line" | sed -E 's/.*: ([0-9.]+) MHz.*/\1/')"
    status="$(echo "$line" | sed -E 's/.*\((PASS|FAIL) at.*/\1/')"
    attempts="$attempts# run $run_no: target $freq MHz -> Fmax $fmax MHz ($status)"$'\n'
    [ "$status" = "FAIL" ] && break
    freq=$(( ${fmax%.*} + 5 ))
done

{ header; echo "# seed    : $SEED (fixed)"
  printf '%s' "$attempts"
  echo "# result  : Fmax = $fmax MHz (final run, target not met)"; echo
  cat "$log"; } > "$REPORTS/${RUN}_nextpnr.txt"
echo "[$RUN] Fmax = $fmax MHz"

# ---------------------------------------------------------------------------
# 4. Summary row (ECP5 runs only)
# ---------------------------------------------------------------------------
if [ "$DEVICE" = "ecp5" ]; then
    util() { grep -E "^Info:[[:space:]]+$1:" "$log" | head -n 1 | \
             sed -E 's/.*:[[:space:]]+([0-9]+)\/.*/\1/'; }
    luts="$(util TRELLIS_COMB)"
    ffs="$(util TRELLIS_FF)"
    brams="$(util DP16KD)"
    csv="$REPORTS/summary.csv"
    [ -f "$csv" ] || echo "design,luts,ffs,brams,fmax_mhz" > "$csv"
    grep -v "^$DESIGN," "$csv" > "$csv.tmp" || true
    echo "$DESIGN,$luts,$ffs,$brams,$fmax" >> "$csv.tmp"
    mv "$csv.tmp" "$csv"
    echo "[$RUN] summary: $DESIGN,$luts,$ffs,$brams,$fmax"
fi
