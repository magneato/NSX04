# 🍪 TRAN4004 — Neural Network Training on Intel 4004
**"The smallest mind can learn. The 4004 breathes." ⚡**

*Made by Robert L. Sitton, Jr. of Neural Splines, LLC (AGPL-3.0-or-later).*

---
## Overview
`src/asm/tran4004.asm` (304 lines, assembles to **288 bytes** in `TRAN4004.ROM`) trains a 2→3→1 neural network to compute the **NAND** logic gate directly on the 4-bit Intel 4004 instruction set, with zero hardware multiplication and zero floating-point operations.

---
## Architecture

### Hardware Constraints
- **CPU:** Intel 4004 (1971, 2,300 transistors, 46 opcodes)
- **ALU:** 4-bit accumulator + 1-bit carry
- **ROM used:** 288 bytes (out of 4 KB)
- **RAM used:** 8 nibbles (4 bytes) in Bank 0 for `W_O[0..2]` and `B_O`

### ROM & RAM Layout
```text
ROM Page 0 (0x000..):
  START              — Initialize weights, LFSR seed, epoch loop
  INIT_WEIGHTS       — Zero 8 nibbles in RAM Bank 0 (SRC + WRM)
  FORWARD_PASS       — Zero-multiply binary-gate sum + Q4.4 step activation
  UPDATE_WEIGHTS     — Sign-selected perceptron step (+0x02 / -0x02)
  ACTIVATION         — Signed 8-bit Q4.4 threshold at +0.5 (0x08)

ROM Page 1 (0x100..):
  NAND_SAMPLES (4B)  — Packed (Target << 2 | X1 << 1 | X0): 0x04, 0x06, 0x05, 0x03
  HIDDEN_LUT   (4B)  — NomNom 2-bit -> 3-bit ELM codebook: 0x01, 0x02, 0x04, 0x07
  FETCH_SAMPLE       — Reads packed sample & hidden mask via FIN

RAM Bank 0 (8 nibbles):
  0x00..0x01 : W_O[0] (hi, lo)
  0x02..0x03 : W_O[1] (hi, lo)
  0x04..0x05 : W_O[2] (hi, lo)
  0x06..0x07 : B_O    (hi, lo)
```

---
## Algorithm
1. **Zero Output Weights:** `W_O[0..2]` and `B_O` are cleared to `0x00`.
2. **Packed Sample + NomNom Lookup:** For each sample `i ∈ {0..3}`, `FETCH_SAMPLE` reads `Target` (`R2`) and the 3-bit hidden activation mask `H[2:0]` (`R3`) from Page 1 ROM via `FIN`.
3. **Zero-Multiply Forward Pass:** Since `H_k ∈ {0, 1}`, `FORWARD_PASS` shifts `H[2:0]` via `RAR` and conditionally adds each 8-bit `W_O[k]` plus `B_O` into `(R5, R4)` with carry, then applies signed Q4.4 step activation (`0x08 <= sum <= 0x7F` → `1`, else `0`).
4. **Sign-Selected Perceptron Update:** If `target != pred`:
   - Increment `ERR_COUNT_REG` (`R12`) and chiral rupture counter (`R13`).
   - Select `delta = +0x02` (`+0.125`) if `target == 1`, or `delta = 0xFE` (`-0.125`) if `target == 0`.
   - Update `B_O += delta` and `W_O[k] += delta` wherever `H_k == 1`.
5. **Soliton Equilibrium Check:** When an epoch completes with `R12 == 0` (zero errors across all 4 NAND samples), `TRAN4004.ROM` halts via `JMS 0x0FE` (`DUCK_HALT`).

---
## Verified Execution (`scripts/sim4004.py`)
```bash
bash scripts/build.sh
python3 scripts/sim4004.py output/roms/TRAN4004.ROM --verify-train
```
Observed output:
```text
PASS train: converged to 0 errors in 6 epochs (4914 insns, 5876 cycles, rom 288 bytes)
```
