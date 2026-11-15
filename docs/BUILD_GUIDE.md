# 🚀 NSX4004 Build Guide — Quick Start

*Made by Robert L. Sitton, Jr. of Neural Splines, LLC (AGPL-3.0-or-later).*

## What You're Building
A 2→3→1 neural network training and running on an **Intel 4004 (1971)** to learn and evaluate a **NAND gate**, verified in a cycle-accurate 4004 simulator (`scripts/sim4004.py`) and packaged with **DUCKER.COM** (an 8086 DOS emulator).

---
## Prerequisites (Ubuntu 24.04)
```bash
bash setup.sh
# Installs: cmake, build-essential, nasm (plus python3)
# Optional for running .COM binaries under DOS emulation:
sudo apt install -y dosbox-x
```

---
## Build & Test (CMake + CTest)
```bash
bash scripts/build.sh
bash scripts/test.sh
```

**Verified test output:**
```text
1/7 Test #1: asm4004_whitespace ...............   Passed
2/7 Test #2: asm4004_multidigit ...............   Passed
3/7 Test #3: asm4004_mixedcase ................   Passed
4/7 Test #4: asm4004_tran4004 .................   Passed
5/7 Test #5: asm4004_infr4004 .................   Passed
6/7 Test #6: sim4004_train_nand ...............   Passed
7/7 Test #7: sim4004_infer_nand ...............   Passed
```

---
## Direct 4004 Simulation
You can also run the 4004 verifier directly after building:
```bash
python3 scripts/sim4004.py output/roms/TRAN4004.ROM --verify-train
# PASS train: converged to 0 errors in 6 epochs (4914 insns, 5876 cycles, rom 288 bytes)

python3 scripts/sim4004.py output/roms/INFR4004.ROM --verify-infer
# PASS infer: all 4 NAND cases verified (total 1156 cycles, rom 282 bytes)
```

---
## Running Under DOSBox (8086 Emulator)
```bash
dosbox-x
```
Inside DOSBox, from `output/`:
```bat
bins\DUCKER.COM roms\TRAN4004.ROM
bins\DUCKER.COM roms\INFR4004.ROM
```

---
## Measured File Sizes
```text
src/asm/ducker.asm       17 KB  -> output/bins/DUCKER.COM     1,410 bytes
src/asm/hell8086.asm     622 B  -> output/bins/HELL8086.COM      45 bytes
src/asm/infr4004.asm    5.4 KB  -> output/roms/INFR4004.ROM     282 bytes
src/asm/tran4004.asm    7.9 KB  -> output/roms/TRAN4004.ROM     288 bytes
```
