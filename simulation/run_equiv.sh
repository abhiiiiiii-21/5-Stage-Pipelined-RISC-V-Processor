#!/usr/bin/env bash
# Runs differential pipeline/single-cycle equivalence checks for all Phase I
# programs and Phase II benchmarks.
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
mkdir -p simulation/build

if ! command -v iverilog >/dev/null 2>&1 || ! command -v vvp >/dev/null 2>&1; then
    echo "ERROR: Icarus Verilog (iverilog and vvp) is required."
    exit 2
fi

RTL=(rtl/*.v)
status=0
declare -a PROGRAMS=(
    "test1_arith:testbench/programs/test1_arith.hex"
    "test2_loadstore:testbench/programs/test2_loadstore.hex"
    "test3_forwarding:testbench/programs/test3_forwarding.hex"
    "test4_loaduse:testbench/programs/test4_loaduse.hex"
    "test5_branch_jump:testbench/programs/test5_branch_jump.hex"
    "test6_sum_array:testbench/programs/test6_sum_array.hex"
    "bench_fib:testbench/programs/bench_fib.hex"
    "bench_sum:testbench/programs/bench_sum.hex"
    "bench_sort:testbench/programs/bench_sort.hex"
    "bench_gcd:testbench/programs/bench_gcd.hex"
    "bench_memcpy:testbench/programs/bench_memcpy.hex"
    "bench_mul:testbench/programs/bench_mul.hex"
)

for entry in "${PROGRAMS[@]}"; do
    name="${entry%%:*}"
    prog="${entry#*:}"
    out="simulation/build/tb_equivalence_${name}.vvp"
    if iverilog -g2012 -I rtl -s tb_equivalence \
        -DPROG="\"$prog\"" -DNAME="\"$name\"" \
        -o "$out" "${RTL[@]}" testbench/tb_equivalence.v &&
       vvp -n "$out" | tee "simulation/build/equiv_${name}.log" &&
       grep -q "EQUIV name=$name result=PASS" "simulation/build/equiv_${name}.log"; then
        :
    else
        status=1
    fi
done

exit "$status"
