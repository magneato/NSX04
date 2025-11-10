# NSX4004

Modern, educational project structure for Intel 4004 + 8086 assembly plus Python utilities, built with a single CMake setup targeting Ubuntu 24.04. Includes convenient setup/build/test scripts and CI.

## Requirements (Ubuntu 24.04)
- `cmake` (>= 3.20)
- `python3`
- `nasm`

Install via scripts/setup.sh or manually:

```
sudo apt-get update && sudo apt-get install -y cmake build-essential nasm
```

## Layout
```
.
├── src/
│   ├── asm/             # Assembly sources
│   │   ├── tran4004.asm     # 4004 training ROM source
│   │   ├── infr4004.asm     # 4004 inference ROM source
│   │   ├── ducker.asm       # 8086 COM (educational emulator wrapper)
│   │   └── hell8086.asm     # 8086 COM demo
├── scripts/             # Python utilities and build helpers
│   ├── asm4004_lite.py
│   ├── duckasm.py
│   ├── hexdump.py
│   └── ...
├── docs/                # Notes and guidance
├── CMakeLists.txt
├── build.sh / run.sh / setup.sh  # Convenience scripts
├── .github/workflows/ci.yml      # CI on ubuntu-24.04
└── .gitignore
```

## Quickstart
```
bash scripts/setup.sh
bash scripts/build.sh
bash scripts/test.sh
```

Artifacts are placed in `out/`:
- `TRAN4004.ROM`, `INFR4004.ROM` (4004 ROMs assembled via `scripts/asm4004_lite.py`)
- `hell8086.com` (flat 16-bit COM binary for DOS)

Note: 8086 `.com` targets are built for educational purposes and run under DOS or DOS emulators (e.g., DOSBox); they do not run natively on Ubuntu.

## CMake Overview
- Root `CMakeLists.txt` defines:
  - Custom NASM rule producing `out/hell8086.com`
  - Custom commands to assemble `out/TRAN4004.ROM` and `out/INFR4004.ROM` via the Python assembler
  - Aggregate target: `roms`

## Assembler Notes (asm4004_lite.py)
- Directives: `ORG`, `EQU`, `DB`, `DW`
- Labels: case-insensitive; numbers: decimal, `0x..`, `$..`, `..h`
- FIM forms supported for convenience:
  - `FIM Rpair, data` (standard)
  - `FIM Rpair, hi, lo` (packs two 4-bit nibbles)
  - `FIM Reven, data` (single even register shorthand)

## Developing
- Add assembly sources under `src/asm/`. For new 8086 `.asm`, mimic the NASM rule to emit additional `.com` files. For 4004 `.asm`, add to the `ROM_SOURCES` list so they assemble via the Python tool.
- Python tools live under `scripts/` (no build needed).

## Docs
See `docs/` for architecture notes and study material. Add examples, references, and lab exercises as needed.
