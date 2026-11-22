#!/usr/bin/env python3
"""
Performance Figures Generator for RISC-V 5-Stage Pipeline vs Single-Cycle Baseline.
Requires: matplotlib, numpy
Outputs:
  - analysis/figures/cpi_comparison.png, .svg
  - analysis/figures/pipeline_cycle_breakdown.png, .svg
  - analysis/figures/execution_time_speedup.png, .svg
"""

import os
import csv
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt

# Styling configuration
plt.rcParams['font.family'] = 'sans-serif'
plt.rcParams['font.size'] = 9.5
plt.rcParams['axes.edgecolor'] = '#444444'
plt.rcParams['axes.linewidth'] = 0.8
plt.rcParams['grid.color'] = '#dddddd'
plt.rcParams['grid.linestyle'] = ':'
plt.rcParams['grid.linewidth'] = 0.7

COLOR_SINGLE = '#4a90e2'     # Blue for single-cycle baseline
COLOR_PIPE = '#e65100'       # Deep orange for 5-stage pipeline
COLOR_N = '#2e7d32'          # Green for instructions
COLOR_FILL = '#9e9e9e'       # Grey for 4-cycle fill
COLOR_STALL = '#f57c00'      # Amber for load-use stalls
COLOR_FLUSH = '#d32f2f'      # Crimson for branch flushes

def load_data():
    perf_csv = "analysis/results/perf.csv"
    speedup_csv = "analysis/results/speedup.csv"

    data = []
    with open(perf_csv, 'r') as f:
        reader = csv.DictReader(f)
        by_prog = {}
        for row in reader:
            prog = row['program']
            des = row['design']
            by_prog.setdefault(prog, {})[des] = row

    speedup_by_prog = {}
    if os.path.exists(speedup_csv):
        with open(speedup_csv, 'r') as f:
            for row in csv.DictReader(f):
                speedup_by_prog[row['program']] = row

    order = [
        'test1_arith', 'test2_loadstore', 'test3_forwarding',
        'test4_loaduse', 'test5_branch_jump', 'test6_sum_array',
        'bench_fib', 'bench_sum', 'bench_sort',
        'bench_gcd', 'bench_memcpy', 'bench_mul'
    ]

    progs = [p for p in order if p in by_prog and 'pipeline' in by_prog[p] and 'single' in by_prog[p]]
    return progs, by_prog, speedup_by_prog

def plot_cpi_comparison(progs, by_prog):
    labels = [p.replace('test', 't').replace('bench_', '') for p in progs]
    cpi_single = [float(by_prog[p]['single']['cpi']) for p in progs]
    cpi_pipe = [float(by_prog[p]['pipeline']['cpi']) for p in progs]

    x = np.arange(len(progs))
    width = 0.38

    fig, ax = plt.subplots(figsize=(10, 4.5), dpi=200)
    rects1 = ax.bar(x - width/2, cpi_single, width, label='Single-Cycle Baseline (CPI = 1.0)',
                    color=COLOR_SINGLE, edgecolor='#2c3e50', linewidth=0.7)
    rects2 = ax.bar(x + width/2, cpi_pipe, width, label='5-Stage Pipelined Processor',
                    color=COLOR_PIPE, edgecolor='#bf360c', linewidth=0.7)

    # Separation line between Phase I and Phase II benchmarks
    ax.axvline(x=5.5, color='#888888', linestyle='--', linewidth=1.2, alpha=0.8)
    ax.text(2.5, 2.30, 'Phase I Test Programs', ha='center', fontsize=9, fontweight='bold', color='#555555')
    ax.text(8.5, 2.30, 'Phase II Realistic Benchmarks', ha='center', fontsize=9, fontweight='bold', color='#555555')

    ax.set_ylabel('Cycles Per Instruction (CPI)', fontweight='bold')
    ax.set_title('CPI Comparison: 5-Stage Pipelined Processor vs. Single-Cycle Baseline', fontweight='bold', pad=12)
    ax.set_xticks(x)
    ax.set_xticklabels(labels, rotation=30, ha='right', fontsize=9)
    ax.set_ylim(0, 2.5)
    ax.grid(axis='y', alpha=0.7)
    ax.legend(loc='upper right', framealpha=0.95)

    # Bar value labels
    for rect in rects2:
        h = rect.get_height()
        ax.annotate(f'{h:.2f}',
                    xy=(rect.get_x() + rect.get_width() / 2, h),
                    xytext=(0, 3), textcoords="offset points",
                    ha='center', va='bottom', fontsize=7.5, fontweight='bold', color='#b71c1c')

    plt.tight_layout()
    os.makedirs('analysis/figures', exist_ok=True)
    plt.savefig('analysis/figures/cpi_comparison.png', dpi=200)
    plt.savefig('analysis/figures/cpi_comparison.svg')
    plt.close()
    print("Generated: analysis/figures/cpi_comparison.{png,svg}")

def plot_cycle_breakdown(progs, by_prog):
    # Only Phase II benchmarks for clarity (or all, but benchmarks have meaningful scale)
    bench_progs = [p for p in progs if p.startswith('bench_')]
    labels = [p.replace('bench_', '') for p in bench_progs]

    N_vals = []
    fill_vals = []
    stall_vals = []
    flush_vals = []
    total_cycles = []

    for p in bench_progs:
        row = by_prog[p]['pipeline']
        n = int(row['instr'])
        s = int(row['stalls'])
        t = int(row['taken'])
        c = int(row['cycles'])

        N_vals.append(n)
        fill_vals.append(4)
        stall_vals.append(s)
        flush_vals.append(2 * t)
        total_cycles.append(c)

    x = np.arange(len(bench_progs))
    width = 0.55

    fig, ax = plt.subplots(figsize=(9, 4.8), dpi=200)

    b1 = ax.bar(x, N_vals, width, label='Base Instructions (N)', color=COLOR_N, edgecolor='#1b5e20', linewidth=0.7)
    b2 = ax.bar(x, fill_vals, width, bottom=N_vals, label='Pipeline Fill (4 cycles)', color=COLOR_FILL, edgecolor='#616161', linewidth=0.7)
    
    bot_stall = np.array(N_vals) + np.array(fill_vals)
    b3 = ax.bar(x, stall_vals, width, bottom=bot_stall, label='Load-Use Stalls (S)', color=COLOR_STALL, edgecolor='#e65100', linewidth=0.7)
    
    bot_flush = bot_stall + np.array(stall_vals)
    b4 = ax.bar(x, flush_vals, width, bottom=bot_flush, label='Branch/Jump Flushes (2T)', color=COLOR_FLUSH, edgecolor='#b71c1c', linewidth=0.7)

    ax.set_ylabel('Total Clock Cycles (C)', fontweight='bold')
    ax.set_title('Pipeline Cycle Breakdown: Analytical Model vs Measured (C = N + 4 + S + 2T)', fontweight='bold', pad=12)
    ax.set_xticks(x)
    ax.set_xticklabels(labels, fontsize=9.5, fontweight='bold')
    ax.grid(axis='y', alpha=0.7)
    ax.legend(loc='upper left', framealpha=0.95)

    # Annotate total cycles on top of each stack
    for idx, total in enumerate(total_cycles):
        ax.text(x[idx], total + 25, f'{total} cyc\n(CPI={total/N_vals[idx]:.2f})',
                ha='center', va='bottom', fontsize=8, fontweight='bold')

    ax.set_ylim(0, max(total_cycles) * 1.18)
    plt.tight_layout()
    plt.savefig('analysis/figures/pipeline_cycle_breakdown.png', dpi=200)
    plt.savefig('analysis/figures/pipeline_cycle_breakdown.svg')
    plt.close()
    print("Generated: analysis/figures/pipeline_cycle_breakdown.{png,svg}")

def plot_execution_time_speedup(progs, speedup_by_prog):
    bench_progs = [p for p in progs if p.startswith('bench_')]
    labels = [p.replace('bench_', '') for p in bench_progs]

    time_single = [float(speedup_by_prog[p]['time_single_us']) for p in bench_progs]
    time_pipe = [float(speedup_by_prog[p]['time_pipeline_us']) for p in bench_progs]
    speedups = [float(speedup_by_prog[p]['speedup']) for p in bench_progs]

    fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(11, 4.5), dpi=200)

    # Subplot 1: Execution Time in microseconds
    x = np.arange(len(bench_progs))
    width = 0.38
    ax1.bar(x - width/2, time_single, width, label='Single-Cycle @ 28.43 MHz', color=COLOR_SINGLE, edgecolor='#2c3e50', linewidth=0.7)
    ax1.bar(x + width/2, time_pipe, width, label='5-Stage Pipeline @ 56.55 MHz', color=COLOR_PIPE, edgecolor='#bf360c', linewidth=0.7)
    ax1.set_ylabel('Execution Time (µs)', fontweight='bold')
    ax1.set_title('Execution Time Comparison (Lower is Better)', fontweight='bold', pad=10)
    ax1.set_xticks(x)
    ax1.set_xticklabels(labels, fontsize=9)
    ax1.grid(axis='y', alpha=0.7)
    ax1.legend(loc='upper left', framealpha=0.95)

    # Subplot 2: Net Speed-Up Factor
    bars = ax2.bar(x, speedups, width=0.5, color='#388e3c', edgecolor='#1b5e20', linewidth=0.7)
    ax2.axhline(y=1.0, color='#888888', linestyle='--', linewidth=1.0)
    ax2.axhline(y=1.989, color='#d32f2f', linestyle=':', linewidth=1.2, label='Fmax Limit (1.99x)')
    ax2.set_ylabel('Speed-Up Factor (Single / Pipeline)', fontweight='bold')
    ax2.set_title('Net Speed-Up Across Benchmarks', fontweight='bold', pad=10)
    ax2.set_xticks(x)
    ax2.set_xticklabels(labels, fontsize=9)
    ax2.set_ylim(0, 2.2)
    ax2.grid(axis='y', alpha=0.7)
    ax2.legend(loc='lower right', framealpha=0.95)

    for bar in bars:
        h = bar.get_height()
        ax2.annotate(f'{h:.2f}x',
                     xy=(bar.get_x() + bar.get_width() / 2, h),
                     xytext=(0, 3), textcoords="offset points",
                     ha='center', va='bottom', fontsize=8.5, fontweight='bold', color='#1b5e20')

    plt.tight_layout()
    plt.savefig('analysis/figures/execution_time_speedup.png', dpi=200)
    plt.savefig('analysis/figures/execution_time_speedup.svg')
    plt.close()
    print("Generated: analysis/figures/execution_time_speedup.{png,svg}")

def main():
    progs, by_prog, speedup_by_prog = load_data()
    plot_cpi_comparison(progs, by_prog)
    plot_cycle_breakdown(progs, by_prog)
    plot_execution_time_speedup(progs, speedup_by_prog)

if __name__ == '__main__':
    main()
