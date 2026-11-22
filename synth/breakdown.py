#!/usr/bin/env python3
"""Per-stage resource table for the pipeline, used by synth/breakdown.sh.

Reads the yosys `stat -json` output of a non-flattened synth_ecp5 run of
riscv_pipeline_top and prints one row per module, grouped by pipeline stage.
Counts of a module include its submodules (ex_stage = alu + alu_control +
branch_unit + its own muxes).

Usage: python3 synth/breakdown.py <stat.json> <header-file>
"""
import json
import sys

# (stage, module name in the netlist, label in the table)
ROWS = [
    ("IF",      "pc_reg",          "pc_reg"),
    ("IF",      "instr_mem",       "instr_mem"),
    ("ID",      "reg_file",        "reg_file"),
    ("ID",      "imm_gen",         "imm_gen"),
    ("ID",      "control_unit",    "control_unit"),
    ("EX",      "ex_stage",        "ex_stage"),
    ("MEM",     "data_mem",        "data_mem"),
    ("PIPE",    "if_id_reg",       "if_id_reg"),
    ("PIPE",    "id_ex_reg",       "id_ex_reg"),
    ("PIPE",    "ex_mem_reg",      "ex_mem_reg"),
    ("PIPE",    "mem_wb_reg",      "mem_wb_reg"),
    ("HAZARD",  "forwarding_unit", "forwarding_unit"),
    ("HAZARD",  "hazard_unit",     "hazard_unit"),
]

COLUMNS = [
    ("LUT4", "LUT4"),
    ("FF", "TRELLIS_FF"),
    ("CARRY", "CCU2C"),
    ("LUTRAM", "TRELLIS_DPR16X4"),
    ("BRAM", "DP16KD"),
]


def clean(name):
    """'$paramod\\data_mem\\DEPTH=...' or '\\reg_file' -> 'data_mem' / 'reg_file'."""
    name = name.lstrip("\\")
    if name.startswith("$paramod"):
        name = name.split("\\")[1]
    return name


def totals(modules, name):
    """Primitive cell counts of a module including all its submodules.

    Module keys carry a leading backslash ('\\alu'), cell types of submodule
    instances may not ('alu'), so both spellings are looked up.
    """
    counts = {}
    for cell, n in modules[name].get("num_cells_by_type", {}).items():
        sub = cell if cell in modules else "\\" + cell
        if sub in modules:
            for k, v in totals(modules, sub).items():
                counts[k] = counts.get(k, 0) + v * n
        else:
            counts[cell] = counts.get(cell, 0) + n
    return counts


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    with open(sys.argv[1]) as f:
        modules = json.load(f)["modules"]
    by_short = {clean(full): full for full in modules}

    with open(sys.argv[2]) as f:
        print(f.read().rstrip())
    print()
    head = "%-7s %-16s" % ("Stage", "Module") + "".join(
        "%8s" % c for c, _ in COLUMNS)
    print(head)
    print("-" * len(head))
    sums = {c: 0 for c, _ in COLUMNS}
    for stage, mod, label in ROWS:
        counts = totals(modules, by_short[mod])
        cells = [counts.get(prim, 0) for _, prim in COLUMNS]
        for (c, _), v in zip(COLUMNS, cells):
            sums[c] += v
        print("%-7s %-16s" % (stage, label) + "".join("%8d" % v for v in cells))
    top = totals(modules, by_short["riscv_pipeline_top"])
    print("-" * len(head))
    print("%-24s" % "Sum of rows" + "".join("%8d" % sums[c] for c, _ in COLUMNS))
    print("%-24s" % "Whole design" + "".join(
        "%8d" % top.get(p, 0) for _, p in COLUMNS))
    print()
    print("Whole design minus sum of rows = glue logic in riscv_pipeline_top")
    print("(next-PC adder and mux, write-back mux).")
    return 0


if __name__ == "__main__":
    sys.exit(main())
