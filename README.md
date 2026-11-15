# NSX4004

*Made by Robert L. Sitton, Jr. of Neural Splines, LLC — Licensed under AGPL-3.0-or-later.*

Educational project for **Intel 4004 + 8086 assembly** neural network experiments, featuring a two-pass Python 4004 assembler, a cycle-accurate 4004 simulator/verifier, an 8086 DOS emulator (`DUCKER.COM`), interactive browser demos, and CMake/CTest CI targeting Ubuntu 24.04.

## Requirements (Ubuntu 24.04)
- `cmake` (>= 3.20)
- `python3`
- `nasm`

Install via `setup.sh` or manually:

```bash
sudo apt-get update && sudo apt-get install -y cmake build-essential nasm
```

## Layout
```text
.
├── index.html               # GitHub Pages landing page
├── .nojekyll                # Disable Jekyll processing for GitHub Pages
├── demo/                    # Interactive browser demos
│   ├── intel4004.html       # DUCKER 4004 interactive CPU emulator
│   └── nsx4004.html         # NSX4004 Consciousness Engine demo
├── src/
│   └── asm/                 # Assembly sources
│       ├── tran4004.asm     # 4004 training ROM (288 bytes)
│       ├── infr4004.asm     # 4004 inference ROM (282 bytes)
│       ├── ducker.asm       # 8086 DOS emulator (1,410 bytes)
│       └── hell8086.asm     # 8086 COM demo (45 bytes)
├── scripts/                 # Python utilities and build helpers
│   ├── asm4004.py           # Two-pass Intel 4004 assembler
│   ├── sim4004.py           # Cycle-accurate 4004 simulator & verifier
│   ├── duckasm.py           # DuckOps preprocessor
│   ├── gen_test_data.py     # Synthetic MNIST-like test data generator
│   ├── hexdump.py           # Hex dump utility
│   ├── build.sh / test.sh / clean.sh
├── docs/                    # Architecture notes & guides
├── test/asmcases/           # Assembler regression tests
├── CMakeLists.txt
├── build.sh / test.sh / run.sh / setup.sh
└── .github/workflows/ci.yml
```

## Quickstart
```bash
bash setup.sh
bash scripts/build.sh
bash scripts/test.sh
```

Artifacts are placed in `output/`:
- `output/roms/TRAN4004.ROM` (288 bytes — converges on NAND in 6 epochs, 5,876 cycles)
- `output/roms/INFR4004.ROM` (282 bytes — verified on all 4 NAND input pairs)
- `output/bins/DUCKER.COM` (1,410 bytes — 16-bit DOS 4004 emulator)
- `output/bins/HELL8086.COM` (45 bytes — 16-bit DOS demo)

Note: 8086 `.COM` targets run under DOS or DOS emulators (e.g., `dosbox-x`); they do not run natively on Ubuntu.

## CMake & CTest Overview
- Root `CMakeLists.txt` defines:
  - Custom NASM rules producing `output/bins/DUCKER.COM` and `output/bins/HELL8086.COM`
  - Custom commands assembling `output/roms/TRAN4004.ROM` and `output/roms/INFR4004.ROM` via `scripts/asm4004.py`
  - 7 CTest checks: 5 assembler tests (`asm4004_*`) + 2 full-execution 4004 simulator verifications (`sim4004_train_nand`, `sim4004_infer_nand`)

## Assembler Notes (`scripts/asm4004.py`)
- Directives: `ORG`, `EQU`, `DB`, `DW`
- Labels: case-insensitive; numbers: decimal, `0x..`, `$..`, `..h`, `0b..`
- `FIM` forms supported:
  - `FIM Rpair, data` (standard)
  - `FIM Rpair, hi, lo` (packs two 4-bit nibbles)

## Interactive Web Demos & GitHub Pages
- Open `index.html` locally or serve via GitHub Pages (with `.nojekyll` enabled).
- Includes links to [`demo/intel4004.html`](demo/intel4004.html) and [`demo/nsx4004.html`](demo/nsx4004.html).

## Docs
See `docs/` for architecture notes and study material (`TLDR.md`, `BUILD_GUIDE.md`, `PROJECT_PHILOSOPHY.md`, `README_DUCKER.md`, `README_TRAN4004.md`, `LICENSE-PATENTS.md`).
