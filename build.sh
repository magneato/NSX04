#!/usr/bin/env bash
# AGI4004 Build Script
# "Building the future with 46 opcodes"

set -euo pipefail

COPYRIGHT_NOTICE=${COPYRIGHT_NOTICE:-"Copyright (c) 2025 Neural Splines, LLC - Licensed under AGPL-3.0-or-later"}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_copyright() {
    echo -e "${PURPLE}${COPYRIGHT_NOTICE}${NC}"
}

# Build configuration
BUILD_DIR="build"
OUTPUT_DIR="output"
TOOLS_DIR="tools"
ASM="nasm"
ASMFLAGS="-f bin"
PYTHON=${PYTHON:-python3}
ASM4004_SCRIPT="scripts/asm4004_lite.py"

# ASCII art header
show_header() {
    echo -e "${CYAN}"
    cat << "EOF"
    ╔═══════════════════════════════════════════════════════╗
    ║              AGI4004 BUILD SYSTEM                     ║
    ║     "46 opcodes. 2,300 transistors. Infinite IQ."    ║
    ╚═══════════════════════════════════════════════════════╝
    
         Building consciousness, 4 bits at a time...
EOF
    echo -e "${NC}"
}

# Function to create directories
create_dirs() {
    echo -e "${BLUE}◉ Creating build directories...${NC}"
    mkdir -p $BUILD_DIR
    mkdir -p $OUTPUT_DIR/{roms,bins,logs}
    mkdir -p $TOOLS_DIR
    echo -e "${GREEN}  ✓ Directories created${NC}"
}

# Function to clean build artifacts
clean_build() {
    echo -e "${YELLOW}◉ Cleaning previous build...${NC}"
    rm -rf $BUILD_DIR/*
    rm -rf $OUTPUT_DIR/roms/*.ROM
    rm -rf $OUTPUT_DIR/bins/*.COM
    echo -e "${GREEN}  ✓ Clean complete${NC}"
}

# Build DUCKER (8086 emulator)
build_ducker() {
    echo -e "${BLUE}◉ Building DUCKER (8086 Docker)...${NC}"
    
    if [[ -f "src/asm/ducker.asm" ]]; then
        $ASM $ASMFLAGS src/asm/ducker.asm -o $OUTPUT_DIR/bins/DUCKER.COM
        echo -e "${GREEN}  ✓ DUCKER.COM built${NC}"
        echo -e "${CYAN}    8086 containerization ready${NC}"
    else
        echo -e "${RED}  ✗ src/asm/ducker.asm not found${NC}"
        return 1
    fi
}

# Assemble 4004 ROMs
assemble_4004_roms() {
    echo -e "${BLUE}◉ Assembling 4004 ROMs...${NC}"
    if [[ ! -f "${ASM4004_SCRIPT}" ]]; then
        echo -e "${RED}  ✗ ${ASM4004_SCRIPT} not found${NC}"
        exit 1
    fi
    
    # Training ROM
    if [[ -f "src/asm/tran4004.asm" ]]; then
        echo -e "${CYAN}  Assembling TRAN4004.ROM...${NC}"
        $PYTHON ${ASM4004_SCRIPT} src/asm/tran4004.asm -q -o $OUTPUT_DIR/roms/TRAN4004.ROM
        echo -e "${GREEN}    ✓ Training ROM ready${NC}"
    fi
    
    # Inference ROM
    if [[ -f "src/asm/infr4004.asm" ]]; then
        echo -e "${CYAN}  Assembling INFR4004.ROM...${NC}"
        $PYTHON ${ASM4004_SCRIPT} src/asm/infr4004.asm -q -o $OUTPUT_DIR/roms/INFR4004.ROM
        echo -e "${GREEN}    ✓ Inference ROM ready${NC}"
    fi
    
    # Test ROM
    if [[ -f "src/asm/test4004.asm" ]]; then
        echo -e "${CYAN}  Assembling TEST4004.ROM...${NC}"
        $PYTHON ${ASM4004_SCRIPT} src/asm/test4004.asm -q -o $OUTPUT_DIR/roms/TEST4004.ROM
        echo -e "${GREEN}    ✓ Test ROM ready${NC}"
    fi
}

# Build Python extensions (if any)
build_python_ext() {
    echo -e "${BLUE}◉ Building Python extensions...${NC}"
    
    if [[ -f "src/py4004.c" ]]; then
        echo -e "${CYAN}  Building py4004 module...${NC}"
        python3 setup.py build_ext --inplace
        echo -e "${GREEN}  ✓ Python extensions built${NC}"
    else
        echo -e "${YELLOW}  ⚠ No Python extensions to build${NC}"
    fi
}

# Calculate statistics
show_stats() {
    echo -e "\n${PURPLE}═══ BUILD STATISTICS ═══${NC}"
    
    # Count opcodes used
    if [[ -f "src/asm/tran4004.asm" ]]; then
        opcodes=$(grep -E "^\s*(FIM|SRC|FIN|JIN|JUN|JMS|INC|ISZ|ADD|SUB|LD|XCH|BBL|LDM)" src/asm/tran4004.asm | wc -l)
        echo -e "  Opcodes used: ${CYAN}$opcodes/46${NC}"
    fi
    
    # ROM sizes
    total_size=0
    for rom in $OUTPUT_DIR/roms/*.ROM; do
        if [[ -f "$rom" ]]; then
            size=$(stat -c%s "$rom")
            total_size=$((total_size + size))
        fi
    done
    echo -e "  Total ROM size: ${CYAN}$total_size bytes${NC}"
    
    # Efficiency calculation
    if [[ $total_size -gt 0 ]]; then
        efficiency=$((640 * 100 / total_size))
        echo -e "  Space efficiency: ${GREEN}$efficiency%${NC}"
    fi
    
    # Transistor efficiency
    echo -e "  Transistors per bit: ${YELLOW}0.36${NC} (2,300 ÷ 6,400 bits)"
    echo -e "  vs modern GPU: ${RED}11,875,000${NC} transistors per bit"
    
    echo -e "${PURPLE}════════════════════════${NC}"
}

# Main build process
main() {
    print_copyright
    show_header
    
    # Parse arguments
    if [[ "${1:-}" == "clean" ]]; then
        clean_build
        exit 0
    fi
    
    if [[ "${1:-}" == "quick" ]]; then
        echo -e "${YELLOW}Quick build mode...${NC}"
        assemble_4004_roms
        show_stats
        exit 0
    fi
    
    # Full build
    create_dirs
    
    # Build binaries
    build_ducker
    
    # Assemble ROMs
    assemble_4004_roms
    
    # Build Python extensions
    build_python_ext
    
    # Show statistics
    show_stats
    
    echo -e "\n${GREEN}═════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ AGI4004 build complete!${NC}"
    echo -e "${GREEN}═════════════════════════════════════════${NC}"
    
    echo -e "\n${CYAN}The 4004 awaits. Intelligence is geometric.${NC}"
    echo -e "${YELLOW}Run ./run.sh to begin exploration.${NC}"
    
    echo -e "\n🍪 ${PURPLE}\"NOM NOM - Build consumed successfully!\"${NC} 🍪\n"
}

# Execute main
main "$@"
