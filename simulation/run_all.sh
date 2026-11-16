#!/usr/bin/env bash
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
unit_status=0
system_status=0

echo "Unit tests"
for tb in testbench/unit/tb_*.v; do
    name="$(basename "$tb" .v)"
    if iverilog -g2012 -I rtl -s "$name" -o "simulation/build/$name.vvp" "${RTL[@]}" "$tb" &&
       vvp "simulation/build/$name.vvp"; then
        echo "$name: PASS"
    else
        echo "$name: FAIL"
        unit_status=1
    fi
done

echo "System tests"
for n in 1 2 3 4 5 6; do
    out="simulation/build/tb_riscv_top_${n}.vvp"
    if iverilog -g2012 -I rtl -DTEST="$n" -s tb_riscv_top \
       -o "$out" "${RTL[@]}" testbench/tb_riscv_top.v &&
       vvp "$out" +VCD="simulation/build/tb_riscv_top_${n}.vcd" |
           tee "simulation/build/test${n}.log" &&
       grep -q "TEST ${n}: PASS" "simulation/build/test${n}.log"; then
        echo "test${n}: PASS"
    else
        echo "test${n}: FAIL"
        system_status=1
    fi
done

echo
printf "%-20s %s\n" "Suite" "Result"
printf "%-20s %s\n" "Unit tests" "$([ "$unit_status" -eq 0 ] && echo PASS || echo FAIL)"
printf "%-20s %s\n" "System tests" "$([ "$system_status" -eq 0 ] && echo PASS || echo FAIL)"
exit $((unit_status || system_status))
