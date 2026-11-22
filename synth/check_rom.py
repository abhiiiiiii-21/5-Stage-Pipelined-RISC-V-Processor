#!/usr/bin/env python3
"""Sanity check used by synth/run_synth.sh.

Reads the RTLIL netlist written by yosys after memory_collect and checks that
the initial contents of the instruction memory (u_imem.mem) start with the
program words of the hex file. If the program was optimised away (for example
because a simulation-only initial loop overwrote the $readmemh contents), the
check fails and the synthesis numbers must not be used.

Usage: python3 synth/check_rom.py <netlist.il> <program.hex>
"""
import re
import sys


def read_hex(path):
    words = []
    with open(path) as f:
        for line in f:
            text = line.split("//")[0].strip()
            if text:
                words.append(int(text, 16))
    return words


def read_rom(path):
    with open(path) as f:
        netlist = f.read()
    for cell in re.findall(r"cell \$mem_v2 .*?\n  end", netlist, re.S):
        if "u_imem.mem" not in cell:
            continue
        init = re.search(r"parameter \\INIT (\d+)'([01x]+)", cell)
        if init is None:
            return []
        bits = init.group(2)
        count = int(init.group(1)) // 32
        words = []
        for i in range(count):
            word = bits[len(bits) - 32 * (i + 1):len(bits) - 32 * i]
            words.append(None if "x" in word else int(word, 2))
        return words
    return []


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        return 2
    program = read_hex(sys.argv[2])
    rom = read_rom(sys.argv[1])
    if rom[:len(program)] != program:
        print("ROM CHECK FAIL: the instruction memory does not contain "
              "the program %s" % sys.argv[2])
        return 1
    print("ROM CHECK PASS: %d program words found in u_imem" % len(program))
    return 0


if __name__ == "__main__":
    sys.exit(main())
