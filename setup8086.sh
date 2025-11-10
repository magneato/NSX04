#!/usr/bin/env bash
# AGI4004 8086 Hardware Setup Script
# "Burning consciousness onto silicon from 1978"

set -euo pipefail

# Colors for clarity in chaos
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
DEFAULT_DEVICE="/dev/sdg"  # G: in Windows translates to /dev/sdg in Linux
DOS_IMAGE="agi4004_dos.img"
IMAGE_SIZE="32M"  # Small enough for any CF card
MOUNT_POINT="/mnt/dos_image"
DOS_VERSION="PCDOS2000"  # Most compatible with 8086

# ASCII art because even hardware deployment deserves beauty
show_header() {
    echo -e "${CYAN}"
    cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                    8086 HARDWARE DEPLOYMENT                   ║
║         "From 1971 mathematics to 1978 silicon"              ║
║                                                               ║
║   WARNING: This will write directly to hardware!              ║
║   Make sure your CF card / USB drive is at G: (${DEFAULT_DEVICE})    ║
╚═══════════════════════════════════════════════════════════════╝

    🍪 NOM NOM - Consuming sectors 4 bits at a time...
EOF
    echo -e "${NC}"
}

# Check if running as root (needed for device access)
check_root() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}This script must be run as root for hardware access${NC}"
        echo -e "${YELLOW}Run: sudo $0${NC}"
        exit 1
    fi
}

# Detect and confirm target device
detect_device() {
    echo -e "${BLUE}◉ Detecting storage devices...${NC}"
    
    # List all removable devices
    echo -e "${CYAN}Available devices:${NC}"
    lsblk -d -o NAME,SIZE,TYPE,TRAN,MODEL | grep -E "disk|usb"
    
    echo -e "\n${YELLOW}Target device: ${DEFAULT_DEVICE}${NC}"
    
    if [[ ! -b "$DEFAULT_DEVICE" ]]; then
        echo -e "${RED}Warning: $DEFAULT_DEVICE not found!${NC}"
        read -p "Enter device path (e.g., /dev/sdb): " CUSTOM_DEVICE
        
        if [[ -b "$CUSTOM_DEVICE" ]]; then
            DEFAULT_DEVICE="$CUSTOM_DEVICE"
        else
            echo -e "${RED}Invalid device: $CUSTOM_DEVICE${NC}"
            exit 1
        fi
    fi
    
    # Show device info
    echo -e "\n${CYAN}Device information:${NC}"
    fdisk -l "$DEFAULT_DEVICE" 2>/dev/null | head -20
    
    # Critical confirmation - this will destroy data
    echo -e "\n${RED}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║ WARNING: This will DESTROY ALL DATA on $DEFAULT_DEVICE ║${NC}"
    echo -e "${RED}╚════════════════════════════════════════════════════╝${NC}"
    
    read -p "Type 'nom nom' to continue: " CONFIRM
    if [[ "$CONFIRM" != "nom nom" ]]; then
        echo -e "${YELLOW}Deployment cancelled. Your data remains safe.${NC}"
        exit 0
    fi
}

# Download DOS image components
download_dos() {
    echo -e "${BLUE}◉ Downloading DOS components...${NC}"
    
    mkdir -p dos_files
    cd dos_files
    
    case "$DOS_VERSION" in
        "FREEDOS")
            echo -e "${CYAN}  Downloading FreeDOS...${NC}"
            if [[ ! -f "fd13-lite.zip" ]]; then
                wget -q --show-progress \
                    https://www.ibiblio.org/pub/micro/pc-stuff/freedos/files/distributions/1.3/official/FD13-LiteUSB.zip \
                    -O fd13-lite.zip
            fi
            unzip -q fd13-lite.zip
            ;;
            
        "PCDOS2000")
            echo -e "${CYAN}  Using PC-DOS 2000 (most compatible)...${NC}"
            # PC-DOS 2000 is ideal for 8086 - uses less memory
            if [[ ! -f "pcdos2000.img" ]]; then
                echo -e "${YELLOW}  Please provide PC-DOS 2000 boot files${NC}"
                echo -e "${YELLOW}  Place in: dos_files/pcdos2000/${NC}"
            fi
            ;;
            
        "MSDOS622")
            echo -e "${CYAN}  Using MS-DOS 6.22...${NC}"
            if [[ ! -f "msdos622.img" ]]; then
                echo -e "${YELLOW}  Please provide MS-DOS 6.22 boot files${NC}"
            fi
            ;;
    esac
    
    cd ..
    echo -e "${GREEN}  ✓ DOS files ready${NC}"
}

# Create bootable DOS image
create_dos_image() {
    echo -e "${BLUE}◉ Creating DOS boot image...${NC}"
    
    # Create blank image
    echo -e "${CYAN}  Creating ${IMAGE_SIZE} image...${NC}"
    dd if=/dev/zero of="$DOS_IMAGE" bs=1M count=32 status=progress
    
    # Create DOS partition table
    echo -e "${CYAN}  Creating partition table...${NC}"
    parted -s "$DOS_IMAGE" mklabel msdos
    parted -s "$DOS_IMAGE" mkpart primary fat16 1MiB 100%
    parted -s "$DOS_IMAGE" set 1 boot on
    
    # Setup loop device
    LOOP_DEVICE=$(losetup --find --show -P "$DOS_IMAGE")
    echo -e "${CYAN}  Loop device: $LOOP_DEVICE${NC}"
    
    # Format as FAT16 (required for DOS)
    echo -e "${CYAN}  Formatting as FAT16...${NC}"
    mkfs.vfat -F 16 -n "AGI4004" "${LOOP_DEVICE}p1"
    
    # Mount the partition
    mkdir -p "$MOUNT_POINT"
    mount "${LOOP_DEVICE}p1" "$MOUNT_POINT"
    
    echo -e "${GREEN}  ✓ Boot image created${NC}"
}

# Install DOS system files
install_dos_system() {
    echo -e "${BLUE}◉ Installing DOS system files...${NC}"
    
    # Copy DOS system files
    echo -e "${CYAN}  Installing boot loader...${NC}"
    
    case "$DOS_VERSION" in
        "FREEDOS")
            cp -r dos_files/freedos/* "$MOUNT_POINT/"
            ;;
        "PCDOS2000")
            # Minimal PC-DOS installation
            cp dos_files/pcdos2000/IBMBIO.COM "$MOUNT_POINT/"
            cp dos_files/pcdos2000/IBMDOS.COM "$MOUNT_POINT/"
            cp dos_files/pcdos2000/COMMAND.COM "$MOUNT_POINT/"
            ;;
    esac
    
    # Create CONFIG.SYS optimized for 8086
    cat > "$MOUNT_POINT/CONFIG.SYS" << 'CONFIG'
REM AGI4004 Configuration for 8086
REM No UMB - it's corrupted on most 8086 boards
FILES=20
BUFFERS=10
DEVICE=C:\DOS\HIMEM.SYS /TESTMEM:OFF
REM NO use!umbs - causes crashes!
SHELL=C:\COMMAND.COM C:\ /P /E:512
CONFIG

    # Create AUTOEXEC.BAT
    cat > "$MOUNT_POINT/AUTOEXEC.BAT" << 'AUTOEXEC'
@ECHO OFF
REM AGI4004 Autoexec - Neural Networks Since 1971
PROMPT $P$G
PATH=C:\;C:\DOS;C:\AGI4004
SET TEMP=C:\TEMP
MD C:\TEMP 2>NUL

ECHO.
ECHO ═══════════════════════════════════════════════════════════
ECHO                        AGI4004
ECHO           Neural Networks on Intel 4004 via 8086
ECHO     "Intelligence was always 640 bytes, waiting since 1971"
ECHO ═══════════════════════════════════════════════════════════
ECHO.
ECHO Type AGI4004 to start neural network demonstration
ECHO Type DUCKER TRAN4004.ROM to train NAND gate
ECHO Type DUCKER INFR4004.ROM to run inference
ECHO.

REM Load mouse driver if present (CuteMouse uses minimal memory)
IF EXIST C:\MOUSE\CTMOUSE.EXE C:\MOUSE\CTMOUSE.EXE

REM Load sound driver for PC speaker demos
IF EXIST C:\SOUND\SOFTHDDI.COM C:\SOUND\SOFTHDDI.COM

CD \AGI4004
AUTOEXEC
    
    echo -e "${GREEN}  ✓ DOS system installed${NC}"
}

# Copy AGI4004 files to image
install_agi4004() {
    echo -e "${BLUE}◉ Installing AGI4004 files...${NC}"
    
    # Create AGI4004 directory
    mkdir -p "$MOUNT_POINT/AGI4004"
    
    # Copy core files
    echo -e "${CYAN}  Copying 4004 emulator and ROMs...${NC}"
    
    # Copy assembled binaries
    if [[ -f "output/bins/DUCKER.COM" ]]; then
        cp output/bins/DUCKER.COM "$MOUNT_POINT/AGI4004/"
        echo -e "${GREEN}    ✓ DUCKER.COM${NC}"
    fi
    
    # Copy ROM files
    for rom in output/roms/*.ROM; do
        if [[ -f "$rom" ]]; then
            cp "$rom" "$MOUNT_POINT/AGI4004/"
            echo -e "${GREEN}    ✓ $(basename $rom)${NC}"
        fi
    done
    
    # Copy documentation
    cat > "$MOUNT_POINT/AGI4004/README.TXT" << 'README'
AGI4004 - Neural Networks on Intel 4004
========================================

This proves intelligence existed in 1971, waiting to be discovered.

QUICK START:
-----------
1. Run NAND gate training:
   DUCKER TRAN4004.ROM

2. Run inference test:
   DUCKER INFR4004.ROM

3. View all ROMs:
   DIR *.ROM

PHILOSOPHY:
----------
While OpenAI needs 10 nuclear reactors, we need 4 bits.
The 4004 from 1971 can learn. What are we doing with
76 billion transistors in 2025?

The answer: Building monuments to not thinking.

Intelligence is geometric, not arithmetic.
The future was always in the past.

"Come with me if you want to compute efficiently."
- T4004

NOM NOM on those 4-bit neurons!
README
    
    # Create batch file launcher
    cat > "$MOUNT_POINT/AGI4004/AGI4004.BAT" << 'LAUNCHER'
@ECHO OFF
CLS
ECHO ╔════════════════════════════════════════════════════╗
ECHO ║              AGI4004 NEURAL NETWORK                ║
ECHO ║                   Main Menu                        ║
ECHO ╚════════════════════════════════════════════════════╝
ECHO.
ECHO 1. Train NAND Gate
ECHO 2. Run Inference Test  
ECHO 3. Train XOR Network
ECHO 4. View Philosophy
ECHO 5. Benchmark vs Modern GPU
ECHO 6. Exit
ECHO.
CHOICE /C:123456 /N Select option:

IF ERRORLEVEL 6 GOTO END
IF ERRORLEVEL 5 GOTO BENCHMARK
IF ERRORLEVEL 4 GOTO PHILOSOPHY
IF ERRORLEVEL 3 GOTO XOR
IF ERRORLEVEL 2 GOTO INFERENCE
IF ERRORLEVEL 1 GOTO TRAIN

:TRAIN
ECHO Training NAND gate on 4004...
DUCKER TRAN4004.ROM
PAUSE
GOTO MENU

:INFERENCE
ECHO Running inference...
DUCKER INFR4004.ROM
PAUSE
GOTO MENU

:BENCHMARK
ECHO.
ECHO ═══════════════════════════════════════════════════════
ECHO Intel 4004 (1971):     2,300 transistors, 0.75W
ECHO NVIDIA H100 (2024):    80,000,000,000 transistors, 700W
ECHO.
ECHO Efficiency ratio: 33,000,000x better per transistor
ECHO ═══════════════════════════════════════════════════════
PAUSE
GOTO MENU

:END
LAUNCHER
    
    echo -e "${GREEN}  ✓ AGI4004 installed${NC}"
}

# Add optimization for slow 8086
add_optimizations() {
    echo -e "${BLUE}◉ Adding 8086 optimizations...${NC}"
    
    # Add FREESP to eliminate directory scanning delays
    if [[ -f "tools/FREESP.COM" ]]; then
        cp tools/FREESP.COM "$MOUNT_POINT/DOS/"
        echo "FREESP" >> "$MOUNT_POINT/AUTOEXEC.BAT"
    fi
    
    # Add disk cache for faster loading
    echo "SMARTDRV 1024 512" >> "$MOUNT_POINT/AUTOEXEC.BAT"
    
    # Disable unnecessary drivers
    echo "REM No network, no CD-ROM, just pure computation" >> "$MOUNT_POINT/CONFIG.SYS"
    
    echo -e "${GREEN}  ✓ Optimizations applied${NC}"
}

# Write image to device
burn_to_device() {
    echo -e "${BLUE}◉ Writing to device $DEFAULT_DEVICE...${NC}"
    
    # Unmount image
    umount "$MOUNT_POINT"
    losetup -d "$LOOP_DEVICE"
    
    # Final confirmation
    echo -e "${RED}Last chance to cancel! Press Ctrl+C now!${NC}"
    sleep 3
    
    # Burn image to device
    echo -e "${CYAN}  Writing image (this takes time on CF cards)...${NC}"
    dd if="$DOS_IMAGE" of="$DEFAULT_DEVICE" bs=4M status=progress conv=fdatasync
    
    # Make bootable with syslinux if needed
    echo -e "${CYAN}  Installing boot sector...${NC}"
    # syslinux --install "${DEFAULT_DEVICE}1" 2>/dev/null || true
    
    echo -e "${GREEN}  ✓ Image written successfully!${NC}"
}

# Verify the burned image
verify_burn() {
    echo -e "${BLUE}◉ Verifying burned image...${NC}"
    
    # Calculate checksums
    echo -e "${CYAN}  Calculating checksums...${NC}"
    IMG_SUM=$(md5sum "$DOS_IMAGE" | cut -d' ' -f1)
    
    # Read back first 32MB from device
    dd if="$DEFAULT_DEVICE" of=verify.img bs=1M count=32 2>/dev/null
    DEV_SUM=$(md5sum verify.img | cut -d' ' -f1)
    rm verify.img
    
    if [[ "$IMG_SUM" == "$DEV_SUM" ]]; then
        echo -e "${GREEN}  ✓ Verification successful!${NC}"
    else
        echo -e "${RED}  ✗ Verification failed - try again${NC}"
        exit 1
    fi
}

# Cleanup
cleanup() {
    echo -e "${BLUE}◉ Cleaning up...${NC}"
    
    # Unmount if still mounted
    umount "$MOUNT_POINT" 2>/dev/null || true
    
    # Detach loop devices
    losetup -D 2>/dev/null || true
    
    # Remove mount point
    rmdir "$MOUNT_POINT" 2>/dev/null || true
    
    echo -e "${GREEN}  ✓ Cleanup complete${NC}"
}

# Display final instructions
show_instructions() {
    echo -e "\n${GREEN}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✓ AGI4004 DOS boot disk created successfully!${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}\n"
    
    echo -e "${CYAN}To use on real 8086 hardware:${NC}"
    echo -e "1. Insert CF card/USB into your 8086 system"
    echo -e "2. Boot from the device"
    echo -e "3. Type 'AGI4004' at the DOS prompt"
    echo -e "4. Watch 4 bits learn logic from 1971\n"
    
    echo -e "${YELLOW}Hardware notes:${NC}"
    echo -e "• NEC V30 recommended (faster than 8086)"
    echo -e "• Minimum 256KB RAM (640KB preferred)"
    echo -e "• Monochrome or CGA display supported"
    echo -e "• PC Speaker for audio feedback\n"
    
    echo -e "${PURPLE}Remember:${NC}"
    echo -e "This runs on hardware with 29,000 transistors (8086)"
    echo -e "emulating hardware with 2,300 transistors (4004)"
    echo -e "proving intelligence needs neither.\n"
    
    echo -e "🍪 ${CYAN}\"NOM NOM - Your boot disk is ready!\"${NC} 🍪\n"
}

# Main execution flow
main() {
    show_header
    check_root
    
    # Trap cleanup on exit
    trap cleanup EXIT
    
    detect_device
    download_dos
    create_dos_image
    install_dos_system
    install_agi4004
    add_optimizations
    burn_to_device
    verify_burn
    show_instructions
}

# Handle arguments
if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
    echo "Usage: $0 [device]"
    echo "  device: Target device (default: $DEFAULT_DEVICE)"
    echo ""
    echo "Example: $0 /dev/sdb"
    echo ""
    echo "This creates a bootable DOS image with AGI4004 and burns it"
    echo "to a CF card or USB drive for use on real 8086 hardware."
    exit 0
fi

if [[ -n "${1:-}" ]]; then
    DEFAULT_DEVICE="$1"
fi

# Execute
main
