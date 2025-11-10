#!/usr/bin/env python3
"""
duckasm.py — Simple preprocessor for Intel 4004 assembly with DuckOps.

This preprocessor expands a few custom pseudo‑operations (DuckOps) into
standard 4004 assembly. DuckOps allow the 4004 code to call out to the
host 8086 emulator for convenience (e.g. reading files, printing
characters, halting). The expansions are described in README_DUCKER.md.

Supported pseudo‑ops (case‑insensitive):

* `RBF label, id` → reads the binary file `<id>.BIN` into ROM at `label`.  Expands to:
    JMS DUCK_RBF
    DB LOW(label), HIGH(label), id

* `SAY 'X'` → prints the ASCII character `X` on the host.  Expands to:
    JMS DUCK_SAY
    DB 'X'

* `PUTN Rx` → prints the low nibble of register `Rx` as hexadecimal.  Expands to:
    JMS DUCK_PUTN
    DB Rx

* `HALT` → stops execution under the emulator.  Expands to:
    JMS DUCK_HALT

Lines that do not match these patterns are passed through unchanged.  This
script does not perform any assembly itself; it merely prepares a file
for consumption by a 4004 assembler such as `asm4004_lite.py`.

Usage:

    python3 duckasm.py input.asm -o output.exp.asm

If no output file is specified, the result is written to stdout.
"""

import argparse
import re
import sys


def preprocess_line(line: str) -> str:
    """Expand a single line containing a DuckOp pseudo‑op."""
    # Strip comments (but preserve them in output if line is unchanged)
    stripped = line.lstrip()
    # Match patterns
    m = re.match(r"(?i)\s*RBF\s+(\w+),\s*(\w+)", stripped)
    if m:
        label, fid = m.groups()
        return f"    JMS DUCK_RBF\n    DB LOW({label}), HIGH({label}), {fid}\n"
    m = re.match(r"(?i)\s*SAY\s+'([^'])'", stripped)
    if m:
        char = m.group(1)
        return f"    JMS DUCK_SAY\n    DB '{char}'\n"
    m = re.match(r"(?i)\s*PUTN\s+(R\w+)", stripped)
    if m:
        reg = m.group(1)
        return f"    JMS DUCK_PUTN\n    DB {reg}\n"
    m = re.match(r"(?i)\s*HALT\b", stripped)
    if m:
        return "    JMS DUCK_HALT\n"
    # Otherwise return line unchanged
    return line


def preprocess_file(inp: str, outp: str) -> None:
    with open(inp, 'r', encoding='utf-8') as f_in:
        lines = f_in.readlines()
    processed = []
    for line in lines:
        # Preserve empty lines and full‑line comments
        if line.strip().startswith(';') or not line.strip():
            processed.append(line)
            continue
        expanded = preprocess_line(line)
        processed.append(expanded)
    if outp:
        with open(outp, 'w', encoding='utf-8') as f_out:
            f_out.writelines(processed)
    else:
        sys.stdout.write(''.join(processed))


def main() -> None:
    parser = argparse.ArgumentParser(description="Preprocess Intel 4004 assembly with DuckOps expansions")
    parser.add_argument('input', help="Input .ASM file")
    parser.add_argument('-o', '--output', help="Output .exp.asm file")
    args = parser.parse_args()
    preprocess_file(args.input, args.output)


if __name__ == '__main__':
    main()