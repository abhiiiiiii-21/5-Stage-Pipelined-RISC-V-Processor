#!/usr/bin/env python3
# =============================================================================
# Tool        : assemble.py
# Description : Two-pass assembler for the 29-instruction RV32I subset of the
#               5-stage pipelined RISC-V processor. It turns an assembly source
#               (.s) into a hex image (.hex) that instr_mem loads with
#               $readmemh: one 32-bit word per line, 8 lowercase hex digits,
#               followed by a "// source line" comment.
#
#               Supported instructions:
#                 R-type : ADD SUB AND OR XOR SLL SRL SRA SLT SLTU
#                 I-type : ADDI ANDI ORI XORI SLTI SLTIU SLLI SRLI SRAI
#                 Memory : LW SW
#                 Branch : BEQ BNE BLT BGE
#                 Jump   : JAL JALR
#                 Upper  : LUI
#               plus the pseudo-instruction "nop" (= addi x0, x0, 0).
#
#               Syntax: registers x0..x31, labels ("loop:"), decimal or 0x hex
#               immediates (optionally negative), "#" comments. A branch or JAL
#               target is either a label or a numeric byte offset relative to
#               the instruction itself (as in the Phase I programs).
#
# Usage       : python3 tools/assemble.py input.s output.hex
#               python3 tools/assemble.py --mix input.s     (instruction mix)
#               python3 tools/assemble.py --selftest        (check Phase I hex)
#               --mix can also be given together with input.s output.hex.
# =============================================================================
import glob
import os
import re
import sys

# mnemonic -> (funct7, funct3) for R-type, opcode 0110011
R_TYPE = {
    "add":  (0b0000000, 0b000),
    "sub":  (0b0100000, 0b000),
    "sll":  (0b0000000, 0b001),
    "slt":  (0b0000000, 0b010),
    "sltu": (0b0000000, 0b011),
    "xor":  (0b0000000, 0b100),
    "srl":  (0b0000000, 0b101),
    "sra":  (0b0100000, 0b101),
    "or":   (0b0000000, 0b110),
    "and":  (0b0000000, 0b111),
}

# mnemonic -> funct3 for I-type ALU, opcode 0010011
I_TYPE = {
    "addi":  0b000,
    "slti":  0b010,
    "sltiu": 0b011,
    "xori":  0b100,
    "ori":   0b110,
    "andi":  0b111,
}

# mnemonic -> (funct7, funct3) for shifts by immediate, opcode 0010011
SHIFT_I = {
    "slli": (0b0000000, 0b001),
    "srli": (0b0000000, 0b101),
    "srai": (0b0100000, 0b101),
}

# mnemonic -> funct3 for branches, opcode 1100011
BRANCH = {
    "beq": 0b000,
    "bne": 0b001,
    "blt": 0b100,
    "bge": 0b101,
}

OP_RTYPE, OP_ITYPE, OP_LOAD, OP_STORE = 0b0110011, 0b0010011, 0b0000011, 0b0100011
OP_BRANCH, OP_JAL, OP_JALR, OP_LUI = 0b1100011, 0b1101111, 0b1100111, 0b0110111

# Instruction classes reported by --mix
CLASSES = ["ALU", "load", "store", "branch", "jump", "upper-immediate"]


def instr_class(mnemonic):
    if mnemonic in R_TYPE or mnemonic in I_TYPE or mnemonic in SHIFT_I or mnemonic == "nop":
        return "ALU"
    if mnemonic == "lw":
        return "load"
    if mnemonic == "sw":
        return "store"
    if mnemonic in BRANCH:
        return "branch"
    if mnemonic in ("jal", "jalr"):
        return "jump"
    if mnemonic == "lui":
        return "upper-immediate"
    return None


class AsmError(Exception):
    pass


def parse_reg(tok):
    m = re.fullmatch(r"x([0-9]|[12][0-9]|3[01])", tok.strip().lower())
    if not m:
        raise AsmError(f"bad register '{tok.strip()}' (use x0..x31)")
    return int(m.group(1))


def parse_int(tok):
    t = tok.strip().lower()
    if re.fullmatch(r"[+-]?0x[0-9a-f]+", t) or re.fullmatch(r"[+-]?[0-9]+", t):
        return int(t, 0)
    raise AsmError(f"bad immediate '{tok.strip()}'")


def check_range(value, lo, hi, what):
    if not lo <= value <= hi:
        raise AsmError(f"{what} {value} out of range [{lo}, {hi}]")


def parse_mem(tok):
    """Parse 'imm(xN)' into (imm, reg)."""
    m = re.fullmatch(r"\s*([^()\s]*)\s*\(\s*(\w+)\s*\)\s*", tok)
    if not m:
        raise AsmError(f"bad memory operand '{tok.strip()}' (use imm(xN))")
    imm = parse_int(m.group(1)) if m.group(1) else 0
    return imm, parse_reg(m.group(2))


def target_offset(tok, pc, labels):
    """Byte offset to a label, or a numeric offset relative to pc."""
    t = tok.strip()
    if re.fullmatch(r"[A-Za-z_.][\w.]*", t):
        if t not in labels:
            raise AsmError(f"undefined label '{t}'")
        return labels[t] - pc
    return parse_int(t)


def enc_r(f7, rs2, rs1, f3, rd, op):
    return (f7 << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_i(imm, rs1, f3, rd, op):
    check_range(imm, -2048, 2047, "12-bit immediate")
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (f3 << 12) | (rd << 7) | op


def enc_s(imm, rs2, rs1, f3, op):
    check_range(imm, -2048, 2047, "store offset")
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (f3 << 12) | ((imm & 0x1F) << 7) | op


def enc_b(off, rs2, rs1, f3, op):
    check_range(off, -4096, 4094, "branch offset")
    if off % 2:
        raise AsmError(f"branch offset {off} is not even")
    o = off & 0x1FFF
    return (((o >> 12) & 1) << 31) | (((o >> 5) & 0x3F) << 25) | (rs2 << 20) | (rs1 << 15) | \
           (f3 << 12) | (((o >> 1) & 0xF) << 8) | (((o >> 11) & 1) << 7) | op


def enc_j(off, rd, op):
    check_range(off, -(1 << 20), (1 << 20) - 2, "jump offset")
    if off % 2:
        raise AsmError(f"jump offset {off} is not even")
    o = off & 0x1FFFFF
    return (((o >> 20) & 1) << 31) | (((o >> 1) & 0x3FF) << 21) | (((o >> 11) & 1) << 20) | \
           (((o >> 12) & 0xFF) << 12) | (rd << 7) | op


def expect(ops, n, mnemonic):
    if len(ops) != n:
        raise AsmError(f"'{mnemonic}' takes {n} operands, got {len(ops)}")


def encode(mnemonic, ops, pc, labels):
    if mnemonic == "nop":
        expect(ops, 0, mnemonic)
        return enc_i(0, 0, 0b000, 0, OP_ITYPE)
    if mnemonic in R_TYPE:
        expect(ops, 3, mnemonic)
        f7, f3 = R_TYPE[mnemonic]
        return enc_r(f7, parse_reg(ops[2]), parse_reg(ops[1]), f3, parse_reg(ops[0]), OP_RTYPE)
    if mnemonic in I_TYPE:
        expect(ops, 3, mnemonic)
        return enc_i(parse_int(ops[2]), parse_reg(ops[1]), I_TYPE[mnemonic], parse_reg(ops[0]), OP_ITYPE)
    if mnemonic in SHIFT_I:
        expect(ops, 3, mnemonic)
        f7, f3 = SHIFT_I[mnemonic]
        shamt = parse_int(ops[2])
        check_range(shamt, 0, 31, "shift amount")
        return enc_r(f7, shamt, parse_reg(ops[1]), f3, parse_reg(ops[0]), OP_ITYPE)
    if mnemonic == "lw":
        expect(ops, 2, mnemonic)
        imm, rs1 = parse_mem(ops[1])
        return enc_i(imm, rs1, 0b010, parse_reg(ops[0]), OP_LOAD)
    if mnemonic == "sw":
        expect(ops, 2, mnemonic)
        imm, rs1 = parse_mem(ops[1])
        return enc_s(imm, parse_reg(ops[0]), rs1, 0b010, OP_STORE)
    if mnemonic in BRANCH:
        expect(ops, 3, mnemonic)
        off = target_offset(ops[2], pc, labels)
        return enc_b(off, parse_reg(ops[1]), parse_reg(ops[0]), BRANCH[mnemonic], OP_BRANCH)
    if mnemonic == "jal":
        expect(ops, 2, mnemonic)
        return enc_j(target_offset(ops[1], pc, labels), parse_reg(ops[0]), OP_JAL)
    if mnemonic == "jalr":
        # jalr rd, imm(rs1)  or  jalr rd, rs1, imm
        if len(ops) == 2:
            imm, rs1 = parse_mem(ops[1])
        else:
            expect(ops, 3, mnemonic)
            rs1, imm = parse_reg(ops[1]), parse_int(ops[2])
        return enc_i(imm, rs1, 0b000, parse_reg(ops[0]), OP_JALR)
    if mnemonic == "lui":
        expect(ops, 2, mnemonic)
        imm = parse_int(ops[1])
        check_range(imm, -(1 << 19), (1 << 20) - 1, "20-bit upper immediate")
        return ((imm & 0xFFFFF) << 12) | (parse_reg(ops[0]) << 7) | OP_LUI
    raise AsmError(f"unsupported instruction '{mnemonic}' (not in the 29-instruction RV32I subset)")


def split_operands(text):
    return [t.strip() for t in text.split(",")] if text.strip() else []


def assemble(path):
    """Return a list of (word, mnemonic, source_text). Raises AsmError."""
    with open(path) as f:
        lines = f.readlines()

    # Pass 1: strip comments, collect labels and instruction lines
    labels = {}
    items = []  # (line_no, mnemonic, operand_text, source_text)
    for line_no, raw in enumerate(lines, 1):
        code = raw.split("#", 1)[0].strip()
        while True:
            m = re.match(r"([A-Za-z_.][\w.]*)\s*:\s*(.*)", code)
            if not m:
                break
            name = m.group(1)
            if name in labels:
                raise AsmError(f"{path}:{line_no}: duplicate label '{name}'")
            labels[name] = 4 * len(items)
            code = m.group(2).strip()
        if not code:
            continue
        parts = code.split(None, 1)
        items.append((line_no, parts[0].lower(), parts[1] if len(parts) > 1 else "", code))

    # Pass 2: encode
    out = []
    for i, (line_no, mnemonic, operands, source) in enumerate(items):
        try:
            word = encode(mnemonic, split_operands(operands), 4 * i, labels)
        except AsmError as e:
            raise AsmError(f"{path}:{line_no}: {e}") from None
        out.append((word & 0xFFFFFFFF, mnemonic, " ".join(source.split())))
    return out


def write_hex(words, path):
    with open(path, "w") as f:
        for word, _, source in words:
            f.write(f"{word:08x} // {source}\n")


def read_hex(path):
    """Words of a $readmemh file, ignoring // comments and blank lines."""
    words = []
    with open(path) as f:
        for line in f:
            tok = line.split("//", 1)[0].strip()
            if tok:
                words.append(int(tok, 16))
    return words


def print_mix(words, name):
    counts = {c: 0 for c in CLASSES}
    for _, mnemonic, _ in words:
        counts[instr_class(mnemonic)] += 1
    print(f"MIX {name}: total={len(words)} " + " ".join(f"{c}={counts[c]}" for c in CLASSES))


def selftest():
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    sources = sorted(glob.glob(os.path.join(root, "testbench", "programs", "test*_*.s")))
    if not sources:
        print("SELFTEST: no testbench/programs/test*_*.s found")
        return 1
    failed = 0
    for src in sources:
        name = os.path.basename(src)
        expected = read_hex(src[:-2] + ".hex")
        got = [w for w, _, _ in assemble(src)]
        if got == expected:
            print(f"SELFTEST {name}: PASS ({len(got)} words)")
        else:
            failed += 1
            print(f"SELFTEST {name}: FAIL")
            for i in range(max(len(got), len(expected))):
                g = f"{got[i]:08x}" if i < len(got) else "--------"
                e = f"{expected[i]:08x}" if i < len(expected) else "--------"
                if g != e:
                    print(f"  word {i}: assembled {g}, committed {e}")
    print(f"SELFTEST: {'PASS' if failed == 0 else 'FAIL'} ({len(sources) - failed}/{len(sources)} programs match)")
    return 1 if failed else 0


def main(argv):
    usage = "usage: assemble.py [--mix] input.s [output.hex] | --selftest"
    args = [a for a in argv if not a.startswith("--")]
    flags = [a for a in argv if a.startswith("--")]
    unknown = [f for f in flags if f not in ("--mix", "--selftest")]
    if unknown:
        print(f"error: unknown flag {unknown[0]}\n{usage}", file=sys.stderr)
        return 2
    try:
        if "--selftest" in flags:
            return selftest()
        mix = "--mix" in flags
        if len(args) == 2:
            words = assemble(args[0])
            write_hex(words, args[1])
        elif len(args) == 1 and mix:
            words = assemble(args[0])
        else:
            print(usage, file=sys.stderr)
            return 2
        if mix:
            print_mix(words, os.path.splitext(os.path.basename(args[0]))[0])
    except AsmError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    except OSError as e:
        print(f"error: {e}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
