#!/usr/bin/env bash
# Runs all unit, pipeline, baseline, benchmark and equivalence suites.
set -u
set -o pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p simulation/build

if ! command -v iverilog >/dev/null 2>&1 || ! command -v vvp >/dev/null 2>&1; then
    echo "ERROR: Icarus Verilog (iverilog and vvp) is required."
    echo "macOS: brew install icarus-verilog"
    exit 2
fi

RTL=(rtl/*.v)
unit_pass=0
unit_fail=0
phase1_pass=0
phase1_fail=0
baseline_pass=0
baseline_fail=0

echo "Unit tests"
for tb in testbench/unit/tb_*.v; do
    name="$(basename "$tb" .v)"
    if iverilog -g2012 -I rtl -s "$name" -o "simulation/build/$name.vvp" "${RTL[@]}" "$tb" &&
       vvp -n "simulation/build/$name.vvp"; then
        echo "$name: PASS"
        unit_pass=$((unit_pass + 1))
    else
        echo "$name: FAIL"
        unit_fail=$((unit_fail + 1))
    fi
done

echo "Phase I pipeline tests"
for n in 1 2 3 4 5 6; do
    out="simulation/build/tb_riscv_top_${n}.vvp"
    log="simulation/build/test${n}.log"
    if iverilog -g2012 -I rtl -DTEST="$n" -s tb_riscv_top \
       -o "$out" "${RTL[@]}" testbench/tb_riscv_top.v &&
       vvp -n "$out" +VCD="simulation/build/tb_riscv_top_${n}.vcd" |
           tee "$log" &&
       grep -q "TEST ${n}: PASS" "$log"; then
        echo "test${n}: PASS"
        phase1_pass=$((phase1_pass + 1))
    else
        echo "test${n}: FAIL"
        phase1_fail=$((phase1_fail + 1))
    fi
done

echo "Phase I single-cycle baseline tests"
for n in 1 2 3 4 5 6; do
    out="simulation/build/tb_single_cycle_${n}.vvp"
    log="simulation/build/single_test${n}.log"
    if iverilog -g2012 -I rtl -DTEST="$n" -s tb_single_cycle \
       -o "$out" "${RTL[@]}" testbench/tb_single_cycle.v &&
       vvp -n "$out" +VCD="simulation/build/tb_single_cycle_${n}.vcd" |
           tee "$log" &&
       grep -q "TEST ${n}: PASS" "$log"; then
        echo "test${n}: PASS"
        baseline_pass=$((baseline_pass + 1))
    else
        echo "test${n}: FAIL"
        baseline_fail=$((baseline_fail + 1))
    fi
done

echo "Phase II benchmark tests"
bench_log="simulation/build/run_bench.log"
bash simulation/run_bench.sh | tee "$bench_log"
bench_status=$?
bench_pass=$(grep -c '^BENCH .*result=PASS' "$bench_log" || true)
bench_fail=$(grep -c '^BENCH .*result=FAIL' "$bench_log" || true)

echo "Pipeline/single-cycle equivalence tests"
equiv_log="simulation/build/run_equiv.log"
bash simulation/run_equiv.sh | tee "$equiv_log"
equiv_status=$?
equiv_pass=$(grep -c '^EQUIV .*result=PASS' "$equiv_log" || true)
equiv_fail=$(grep -c '^EQUIV .*result=FAIL' "$equiv_log" || true)

echo
printf "%-28s %8s %8s %8s\n" "Suite" "Passed" "Failed" "Result"
printf "%-28s %8d %8d %8s\n" "Unit testbenches" "$unit_pass" "$unit_fail" \
    "$([ "$unit_fail" -eq 0 ] && echo PASS || echo FAIL)"
printf "%-28s %8d %8d %8s\n" "Phase I pipeline" "$phase1_pass" "$phase1_fail" \
    "$([ "$phase1_fail" -eq 0 ] && echo PASS || echo FAIL)"
printf "%-28s %8d %8d %8s\n" "Phase I baseline" "$baseline_pass" "$baseline_fail" \
    "$([ "$baseline_fail" -eq 0 ] && echo PASS || echo FAIL)"
printf "%-28s %8d %8d %8s\n" "Phase II benchmarks" "$bench_pass" "$bench_fail" \
    "$([ "$bench_fail" -eq 0 ] && echo PASS || echo FAIL)"
printf "%-28s %8d %8d %8s\n" "Equivalence" "$equiv_pass" "$equiv_fail" \
    "$([ "$equiv_fail" -eq 0 ] && echo PASS || echo FAIL)"

if [ "$unit_fail" -ne 0 ] || [ "$phase1_fail" -ne 0 ] ||
   [ "$baseline_fail" -ne 0 ] || [ "$bench_status" -ne 0 ] ||
   [ "$equiv_status" -ne 0 ]; then
    exit 1
fi
exit 0
