#!/usr/bin/env python3
"""
Compute Speed-Up and Execution Time Metrics for RISC-V 5-Stage Pipeline vs Single-Cycle Baseline.
Reads:
  - analysis/results/perf.csv
  - synth/reports/summary.csv
Outputs:
  - analysis/results/speedup.csv
"""

import os
import csv
import sys

def main():
    perf_csv = "analysis/results/perf.csv"
    synth_csv = "synth/reports/summary.csv"
    speedup_csv = "analysis/results/speedup.csv"

    if not os.path.exists(perf_csv):
        print(f"ERROR: {perf_csv} not found.", file=sys.stderr)
        sys.exit(1)

    # Read Fmax from synth summary if available
    fmax = {"pipeline": 56.55, "single": 28.43}
    if os.path.exists(synth_csv):
        with open(synth_csv, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                d = row['design'].strip()
                if d in fmax:
                    fmax[d] = float(row['fmax_mhz'])

    fmax_ratio = fmax["pipeline"] / fmax["single"]
    print(f"Fmax: Pipeline={fmax['pipeline']:.2f} MHz, Single-Cycle={fmax['single']:.2f} MHz (Ratio={fmax_ratio:.4f})")

    # Read perf rows
    perf_data = {}
    with open(perf_csv, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            prog = row['program']
            design = row['design']
            perf_data.setdefault(prog, {})[design] = {
                'instr': int(row['instr']),
                'cycles': int(row['cycles']),
                'cpi': float(row['cpi']),
                'ipc': float(row['ipc']),
                'stalls': int(row['stalls']),
                'taken': int(row['taken'])
            }

    # Generate speedup CSV
    # Header: program,instr,cycles_single,cycles_pipeline,cpi_single,cpi_pipeline,time_single_us,time_pipeline_us,cycles_ratio,fmax_ratio,speedup
    fieldnames = [
        "program", "instr", "cycles_single", "cycles_pipeline",
        "cpi_single", "cpi_pipeline", "time_single_us", "time_pipeline_us",
        "cycles_ratio", "fmax_ratio", "speedup"
    ]

    out_rows = []
    for prog, designs in perf_data.items():
        if "single" not in designs or "pipeline" not in designs:
            continue
        s = designs["single"]
        p = designs["pipeline"]

        instr = s["instr"]
        c_single = s["cycles"]
        c_pipe = p["cycles"]
        cpi_single = s["cpi"]
        cpi_pipe = p["cpi"]

        # Execution time in microseconds: cycles / (MHz)
        time_single_us = c_single / fmax["single"]
        time_pipe_us = c_pipe / fmax["pipeline"]

        cycles_ratio = c_single / c_pipe  # = 1.0 / cpi_pipe
        speedup = time_single_us / time_pipe_us

        out_rows.append({
            "program": prog,
            "instr": instr,
            "cycles_single": c_single,
            "cycles_pipeline": c_pipe,
            "cpi_single": f"{cpi_single:.3f}",
            "cpi_pipeline": f"{cpi_pipe:.3f}",
            "time_single_us": f"{time_single_us:.3f}",
            "time_pipeline_us": f"{time_pipe_us:.3f}",
            "cycles_ratio": f"{cycles_ratio:.4f}",
            "fmax_ratio": f"{fmax_ratio:.4f}",
            "speedup": f"{speedup:.4f}"
        })

    with open(speedup_csv, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(out_rows)

    print(f"Generated: {speedup_csv}")

if __name__ == "__main__":
    main()
