#!/usr/bin/env bash
# Runs the six benchmark programs on the 5-stage pipeline and on the
# single-cycle baseline with testbench/tb_bench.v and prints one BENCH line per
# run (12 lines). Exits non-zero if any run fails or does not compile.
# Usage: bash simulation/run_bench.sh   (from any directory)
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p simulation/build

if ! command -v iverilog >/dev/null 2>&1 || ! command -v vvp >/dev/null 2>&1; then
    echo "ERROR: Icarus Verilog (iverilog and vvp) is required."
    echo "macOS: brew install icarus-verilog"
    exit 2
fi

RTL=(rtl/*.v)
BENCHES=(fib sum sort gcd memcpy mul)
status=0

for design in pipeline single; do
    for name in "${BENCHES[@]}"; do
        prog="testbench/programs/bench_${name}.hex"
        out="simulation/build/bench_${name}_${design}.vvp"
        defs=(-DPROG="\"$prog\"" -DNAME="\"$name\"")
        [ "$design" = "single" ] && defs+=(-DSINGLE)
        if ! iverilog -g2012 -I rtl -s tb_bench "${defs[@]}" -o "$out" \
             "${RTL[@]}" testbench/tb_bench.v; then
            echo "BENCH name=$name design=$design result=FAIL (compile error)"
            status=1
            continue
        fi
        line="$(vvp -n "$out" | grep '^BENCH ')"
        echo "${line:-BENCH name=$name design=$design result=FAIL (no output)}"
        case "$line" in
            *result=PASS*) ;;
            *) status=1 ;;
        esac
    done
done

exit $status
