# 🍪 DUCKER — Intel 4004 Emulator for Neural Inference
**"Consciousness needs no cathedral. This CPU needs no transistors." ⚡**

*Made by Robert L. Sitton, Jr. of Neural Splines, LLC (AGPL-3.0-or-later).*

![Ducker Logo](ducker.jpg "Van Gogh Duck")

## Overview
DUCKER (Docker-inspired Universal 4004 Emulator) is an Intel 4004 CPU emulator written in 8086 assembly (`src/asm/ducker.asm`) that executes 4004 neural network ROMs under DOS / DOSBox.

```text
Modern PC assembles 4004 ROMs (scripts/asm4004.py) and 8086 COM (nasm)
    ↓
8086 (1978) runs DUCKER.COM emulator (1,410 bytes)
    ↓
4004 (1971) executes TRAN4004.ROM (288 bytes) and INFR4004.ROM (282 bytes)
    ↓
Neural network trains and evaluates the NAND gate (100% accuracy)
```

## Architecture

### `DUCKER.COM` (`src/asm/ducker.asm`, 669 lines → 1,410 bytes)
- Emulates 16 × 4-bit registers (`R0`–`R15`)
- 4 KB ROM address space (12-bit addressing)
- 320 nibbles RAM (4 banks × 4 registers × 20 nibbles)
- 3-level call stack (matching the Intel 4004)
- Supports `0x0F` HLT marker and `0x0FE` DuckOp halt trap

### `INFR4004.ROM` (`src/asm/infr4004.asm`, 165 lines → 282 bytes)
- 2→3→1 neural network topology for NAND
- Signed 8-bit Q4.4 fixed-point arithmetic (4-bit integer, 4-bit fractional)
- 13 Q4.4 parameters (9 weights + 4 biases) stored in Page 1 ROM (`0x100`–`0x10C`) and read via `FIN`
- Zero-multiply binary-gate forward pass (`ADD_IF_BIT`)
- Step activation (`0x08 <= sum <= 0x7F` → `1`, else `0`) via `BBL 1` / `BBL 0`

### `TRAN4004.ROM` (`src/asm/tran4004.asm`, 304 lines → 288 bytes)
- 2→3→1 Extreme Learning Machine + perceptron trainer
- 4-byte packed NAND truth table (`NAND_SAMPLES` at `0x100`–`0x103`)
- 4-entry `NomNom` hidden-feature codebook (`HIDDEN_LUT` at `0x104`–`0x107`)
- 8 nibbles of RAM Bank 0 (`W_O[0..2]` + `B_O`)
- Converges to **0 errors in 6 epochs** (`4,914` instructions, `5,876` cycles)

## Quick Start

```bash
bash setup.sh
bash scripts/build.sh
bash scripts/test.sh
```

Artifacts are written to `output/`:
- `output/bins/DUCKER.COM` (1,410 bytes)
- `output/bins/HELL8086.COM` (45 bytes)
- `output/roms/TRAN4004.ROM` (288 bytes)
- `output/roms/INFR4004.ROM` (282 bytes)

To run under DOSBox:
```bash
dosbox-x
# Inside DOSBox (from output/):
bins\DUCKER.COM roms\TRAN4004.ROM
bins\DUCKER.COM roms\INFR4004.ROM
```
