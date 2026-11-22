#!/usr/bin/env bash
# ==============================================================================
# Script: analysis/run_perf.sh
# Author: Vikash Kumar (2401010503)
# Description: Automated performance benchmarking and analysis runner.
#              Simulates all 6 Phase I programs and 6 Phase II benchmarks on
#              both the 5-stage pipelined processor and the single-cycle baseline.
#              Extracts cycle-accurate metrics (N, C, S, T, CPI, IPC), asserts
#              the analytical pipeline cycle equation C = N + 4 + S + 2T,
#              generates perf.csv, speedup.csv, and performance figures.
# ==============================================================================
set -euo pipefail

# Ensure iverilog and vvp are in PATH
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
export MPLCONFIGDIR="${MPLCONFIGDIR:-/tmp/matplotlib}"

mkdir -p simulation/build analysis/results analysis/figures

PERF_CSV="analysis/results/perf.csv"
echo "program,design,instr,cycles,cpi,ipc,stalls,taken" > "$PERF_CSV"

echo "=============================================================================="
echo " Running Performance Benchmarks (Pipeline vs Single-Cycle Baseline)"
echo "=============================================================================="

# Array of Phase I test programs: (test_number, program_name)
PHASE1_TESTS=(
    "1:test1_arith"
    "2:test2_loadstore"
    "3:test3_forwarding"
    "4:test4_loaduse"
    "5:test5_branch_jump"
    "6:test6_sum_array"
)

# Array of Phase II benchmarks
BENCH_NAMES=("fib" "sum" "sort" "gcd" "memcpy" "mul")

# ------------------------------------------------------------------------------
# 1. Run Phase I Programs on Pipeline and Baseline
# ------------------------------------------------------------------------------
echo "[1/3] Executing Phase I programs (6 on pipeline, 6 on single-cycle)..."

for entry in "${PHASE1_TESTS[@]}"; do
    num="${entry%%:*}"
    name="${entry##*:}"

    # --- Pipeline run ---
    iverilog -g2012 -I rtl -DTEST="$num" -s tb_riscv_top \
        -o "simulation/build/tb_riscv_top_${num}.vvp" rtl/*.v testbench/tb_riscv_top.v
    pipe_out=$(vvp "simulation/build/tb_riscv_top_${num}.vvp")

    if ! echo "$pipe_out" | grep -q "TEST $num: PASS"; then
        echo "ERROR: Pipeline run failed for $name" >&2
        echo "$pipe_out" >&2
        exit 1
    fi

    # Parse: PERF: instructions=21 cycles=25 load_use_stalls=0 taken_branches_jumps=0 CPI=1.190
    perf_line=$(echo "$pipe_out" | grep "PERF: instructions=")
    n_pipe=$(echo "$perf_line" | sed -E 's/.*instructions=([0-9]+).*/\1/')
    c_pipe=$(echo "$perf_line" | sed -E 's/.*cycles=([0-9]+).*/\1/')
    s_pipe=$(echo "$perf_line" | sed -E 's/.*load_use_stalls=([0-9]+).*/\1/')
    t_pipe=$(echo "$perf_line" | sed -E 's/.*taken_branches_jumps=([0-9]+).*/\1/')
    cpi_pipe=$(echo "$perf_line" | sed -E 's/.*CPI=([0-9.]+).*/\1/')
    ipc_pipe=$(awk "BEGIN {printf \"%.3f\", $n_pipe / $c_pipe}")

    # Validate analytical formula: C = N + 4 + S + 2T
    expected_c=$((n_pipe + 4 + s_pipe + 2 * t_pipe))
    if [ "$c_pipe" -ne "$expected_c" ]; then
        echo "ERROR: Cycle equation mismatch for $name pipeline: measured=$c_pipe, expected=$expected_c (N=$n_pipe, S=$s_pipe, T=$t_pipe)" >&2
        exit 1
    fi

    echo "$name,pipeline,$n_pipe,$c_pipe,$cpi_pipe,$ipc_pipe,$s_pipe,$t_pipe" >> "$PERF_CSV"

    # --- Single-Cycle run ---
    iverilog -g2012 -I rtl -DTEST="$num" -s tb_single_cycle \
        -o "simulation/build/tb_single_cycle_${num}.vvp" rtl/*.v testbench/tb_single_cycle.v
    single_out=$(vvp "simulation/build/tb_single_cycle_${num}.vvp")

    if ! echo "$single_out" | grep -q "TEST $num: PASS"; then
        echo "ERROR: Single-cycle run failed for $name" >&2
        echo "$single_out" >&2
        exit 1
    fi

    perf_line_s=$(echo "$single_out" | grep "PERF: instructions=")
    n_single=$(echo "$perf_line_s" | sed -E 's/.*instructions=([0-9]+).*/\1/')
    c_single=$(echo "$perf_line_s" | sed -E 's/.*cycles=([0-9]+).*/\1/')
    cpi_single="1.000"
    ipc_single="1.000"

    echo "$name,single,$n_single,$c_single,$cpi_single,$ipc_single,0,0" >> "$PERF_CSV"
    printf "  %-18s | Pipe C=%-3d (CPI=%-5s) | Single C=%-3d (CPI=%-5s) | PASS\n" \
           "$name" "$c_pipe" "$cpi_pipe" "$c_single" "$cpi_single"
done

# ------------------------------------------------------------------------------
# 2. Run Phase II Benchmarks on Pipeline and Baseline
# ------------------------------------------------------------------------------
echo "[2/3] Executing Phase II benchmarks (6 on pipeline, 6 on single-cycle)..."

for b in "${BENCH_NAMES[@]}"; do
    prog_file="testbench/programs/bench_${b}.hex"
    prog_name="bench_${b}"

    # --- Pipeline run ---
    out_pipe="simulation/build/bench_${b}_pipeline.vvp"
    iverilog -g2012 -I rtl -s tb_bench \
        -DPROG="\"$prog_file\"" -DNAME="\"$b\"" \
        -o "$out_pipe" rtl/*.v testbench/tb_bench.v
    pipe_out=$(vvp -n "$out_pipe")
    bench_line=$(echo "$pipe_out" | grep "^BENCH name=")

    if ! echo "$bench_line" | grep -q "result=PASS"; then
        echo "ERROR: Pipeline benchmark failed for $b: $bench_line" >&2
        exit 1
    fi

    n_pipe=$(echo "$bench_line" | sed -E 's/.*instr=([0-9]+).*/\1/')
    c_pipe=$(echo "$bench_line" | sed -E 's/.*cycles=([0-9]+).*/\1/')
    s_pipe=$(echo "$bench_line" | sed -E 's/.*stalls=([0-9]+).*/\1/')
    t_pipe=$(echo "$bench_line" | sed -E 's/.*taken=([0-9]+).*/\1/')
    cpi_pipe=$(awk "BEGIN {printf \"%.3f\", $c_pipe / $n_pipe}")
    ipc_pipe=$(awk "BEGIN {printf \"%.3f\", $n_pipe / $c_pipe}")

    # Validate analytical formula: C = N + 4 + S + 2T
    expected_c=$((n_pipe + 4 + s_pipe + 2 * t_pipe))
    if [ "$c_pipe" -ne "$expected_c" ]; then
        echo "ERROR: Cycle equation mismatch for $b pipeline: measured=$c_pipe, expected=$expected_c (N=$n_pipe, S=$s_pipe, T=$t_pipe)" >&2
        exit 1
    fi

    echo "$prog_name,pipeline,$n_pipe,$c_pipe,$cpi_pipe,$ipc_pipe,$s_pipe,$t_pipe" >> "$PERF_CSV"

    # --- Single-Cycle run ---
    out_single="simulation/build/bench_${b}_single.vvp"
    iverilog -g2012 -I rtl -s tb_bench -DSINGLE \
        -DPROG="\"$prog_file\"" -DNAME="\"$b\"" \
        -o "$out_single" rtl/*.v testbench/tb_bench.v
    single_out=$(vvp -n "$out_single")
    bench_line_s=$(echo "$single_out" | grep "^BENCH name=")

    if ! echo "$bench_line_s" | grep -q "result=PASS"; then
        echo "ERROR: Single-cycle benchmark failed for $b: $bench_line_s" >&2
        exit 1
    fi

    n_single=$(echo "$bench_line_s" | sed -E 's/.*instr=([0-9]+).*/\1/')
    c_single=$(echo "$bench_line_s" | sed -E 's/.*cycles=([0-9]+).*/\1/')
    cpi_single="1.000"
    ipc_single="1.000"

    echo "$prog_name,single,$n_single,$c_single,$cpi_single,$ipc_single,0,0" >> "$PERF_CSV"
    printf "  %-18s | Pipe C=%-5d (CPI=%-5s) | Single C=%-5d (CPI=%-5s) | PASS\n" \
           "$prog_name" "$c_pipe" "$cpi_pipe" "$c_single" "$cpi_single"
done

# ------------------------------------------------------------------------------
# 3. Compute Speed-up and Generate Plots
# ------------------------------------------------------------------------------
echo "[3/3] Computing speed-up metrics and rendering figures..."
python3 analysis/compute_speedup.py
python3 analysis/plot_perf.py

echo "=============================================================================="
echo " Performance Analysis Completed Successfully!"
echo " Results written to: $PERF_CSV and analysis/results/speedup.csv"
echo " Figures generated in: analysis/figures/"
echo "=============================================================================="
