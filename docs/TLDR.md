# 🧠 NSX4004 TLDR — Intel 4004 Neural Network Project

*Made by Robert L. Sitton, Jr. of Neural Splines, LLC (AGPL-3.0-or-later).*

## 🚀 What's NSX4004?

NSX4004 demonstrates training and running a 2→3→1 neural network (learning the **NAND** logic gate) on a **1971 Intel 4004** microprocessor (2,300 transistors, 4-bit ALU, 46 opcodes). Modern tools assemble the 4004 ROMs and an 8086 DOS emulator (`DUCKER.COM`) plus a cycle-accurate Python 4004 verifier (`scripts/sim4004.py`) execute and test them.

## 🧩 How It Works

- **Neural network topology:** 2 inputs → 3 hidden features → 1 output (NAND logic).
- **Extreme Learning Machine (ELM) + NomNom Codebook:** Hidden features are mapped via a 4-entry ROM lookup table (`HIDDEN_LUT` in `tran4004.asm`) and never updated. Only the output weights `W_O[0..2]` and bias `B_O` (8 nibbles in RAM Bank 0) learn via a perceptron rule.
- **Fixed-point math:** Signed 8-bit **Q4.4** (4 integer bits, 4 fractional bits; resolution `1/16 = 0.0625`, range `-8.0` to `+7.9375`).
- **Zero-multiply forward pass:** Since inputs and hidden activations are binary `{0, 1}`, multiplication reduces to conditional 8-bit addition (`ADD_IF_BIT` / `ADD_RAM_IF_HBIT`).
- **Step activation:** Outputs `1` if `0x08 <= sum <= 0x7F` (`>= +0.5`), else `0`.
- **Training convergence:** `TRAN4004.ROM` (288 bytes) converges from zeroed output weights to **0 errors in 6 epochs** (`4,914` instructions, `5,876` cycles), verified by `scripts/sim4004.py`.

## 🛠️ Files & Components

| File | Purpose | Measured Size |
|-----|---------|---------------|
| [`src/asm/tran4004.asm`](../src/asm/tran4004.asm) | 4004 training ROM (packed NAND samples, `HIDDEN_LUT`, perceptron updates) | `TRAN4004.ROM` = 288 bytes |
| [`src/asm/infr4004.asm`](../src/asm/infr4004.asm) | 4004 inference ROM (pre-trained Q4.4 weights in Page 1 ROM) | `INFR4004.ROM` = 282 bytes |
| [`src/asm/ducker.asm`](../src/asm/ducker.asm) | 8086 DOS emulator for 4004 ROMs (`DUCKER.COM`) | `DUCKER.COM` = 1,410 bytes |
| [`src/asm/hell8086.asm`](../src/asm/hell8086.asm) | Minimal 8086 DOS `.COM` demo | `HELL8086.COM` = 45 bytes |
| [`scripts/asm4004.py`](../scripts/asm4004.py) | Two-pass Python Intel 4004 assembler (`.asm` → `.ROM` + `.lst`) | 632 lines |
| [`scripts/sim4004.py`](../scripts/sim4004.py) | Cycle-accurate Python Intel 4004 simulator & CTest verifier | 261 lines |
| [`scripts/duckasm.py`](../scripts/duckasm.py) | Optional DuckOps macro preprocessor | 93 lines |

## 📦 Build & Verify

```bash
bash setup.sh
bash scripts/build.sh
bash scripts/test.sh
```

`ctest` runs 7 tests (assembler regression tests + full 4004 simulation of `TRAN4004.ROM` and `INFR4004.ROM`).
