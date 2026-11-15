#!/usr/bin/env python3
# =========================================================
# NSX4004 Project - Intel 4004 Neural Network Experiments
# File: scripts/sim4004.py
# Author: Robert L. Sitton, Jr. of Neural Splines, LLC
# Copyright (c) 2025 Robert L. Sitton, Jr. of Neural Splines, LLC
# License: GNU AGPL-3.0-or-later
# =========================================================
"""Lightweight cycle-accurate Intel 4004 simulator for verifying NSX4004 ROMs."""

import argparse
import sys
from typing import Dict, List, Optional, Tuple


class Cpu4004:
    """Intel 4004 4-bit microprocessor simulator."""

    def __init__(self, rom: bytes) -> None:
        self.rom = bytearray(rom)
        if len(self.rom) < 4096:
            self.rom.extend(b"\x00" * (4096 - len(self.rom)))
        self.ram: Dict[Tuple[int, int], int] = {}
        self.regs: List[int] = [0] * 16
        self.acc: int = 0
        self.carry: int = 0
        self.test_pin: int = 1
        self.pc: int = 0
        self.stack: List[int] = []
        self.ram_bank: int = 0
        self.ram_addr: int = 0
        self.cycles: int = 0
        self.instructions: int = 0
        self.halted: bool = False

    def get_pair(self, p: int) -> int:
        return ((self.regs[2 * p] & 0xF) << 4) | (self.regs[2 * p + 1] & 0xF)

    def set_pair(self, p: int, val: int) -> None:
        self.regs[2 * p] = (val >> 4) & 0xF
        self.regs[2 * p + 1] = val & 0xF

    def step(self) -> bool:
        if self.halted:
            return False

        op = self.rom[self.pc & 0xFFF]
        self.pc = (self.pc + 1) & 0xFFF
        hi = (op >> 4) & 0xF
        lo = op & 0xF
        self.instructions += 1
        self.cycles += 1

        if op == 0x00:  # NOP
            pass
        elif op == 0x0F:  # Emulator HLT marker
            self.halted = True
        elif hi == 0x1:  # JCN
            addr8 = self.rom[self.pc & 0xFFF]
            self.pc = (self.pc + 1) & 0xFFF
            self.cycles += 1
            hit = False
            if (lo & 0x04) and self.acc == 0:
                hit = True
            if (lo & 0x02) and self.carry == 1:
                hit = True
            if (lo & 0x01) and self.test_pin == 0:
                hit = True
            jump = (not hit) if (lo & 0x08) else hit
            if jump:
                self.pc = (self.pc & 0xF00) | addr8
        elif hi == 0x2:
            if (lo & 1) == 0:  # FIM
                imm8 = self.rom[self.pc & 0xFFF]
                self.pc = (self.pc + 1) & 0xFFF
                self.cycles += 1
                self.set_pair(lo >> 1, imm8)
            else:  # SRC
                self.ram_addr = self.get_pair(lo >> 1)
        elif hi == 0x3:
            if (lo & 1) == 0:  # FIN
                addr12 = (self.pc & 0xF00) | self.get_pair(0)
                self.set_pair(lo >> 1, self.rom[addr12])
                self.cycles += 1
            else:  # JIN
                self.pc = (self.pc & 0xF00) | self.get_pair(lo >> 1)
        elif hi == 0x4:  # JUN
            addr8 = self.rom[self.pc & 0xFFF]
            self.pc = ((lo << 8) | addr8) & 0xFFF
            self.cycles += 1
        elif hi == 0x5:  # JMS
            addr8 = self.rom[self.pc & 0xFFF]
            self.pc = (self.pc + 1) & 0xFFF
            self.cycles += 1
            target = ((lo << 8) | addr8) & 0xFFF
            if target == 0x0FE:  # DUCK_HALT trap
                self.halted = True
            else:
                if len(self.stack) >= 3:
                    self.stack.pop(0)
                self.stack.append(self.pc)
                self.pc = target
        elif hi == 0x6:  # INC
            self.regs[lo] = (self.regs[lo] + 1) & 0xF
        elif hi == 0x7:  # ISZ
            addr8 = self.rom[self.pc & 0xFFF]
            self.pc = (self.pc + 1) & 0xFFF
            self.cycles += 1
            self.regs[lo] = (self.regs[lo] + 1) & 0xF
            if self.regs[lo] != 0:
                self.pc = (self.pc & 0xF00) | addr8
        elif hi == 0x8:  # ADD
            s = self.acc + self.regs[lo] + self.carry
            self.acc = s & 0xF
            self.carry = 1 if s > 15 else 0
        elif hi == 0x9:  # SUB
            s = self.acc + (self.regs[lo] ^ 0xF) + (self.carry ^ 1)
            self.acc = s & 0xF
            self.carry = 1 if s > 15 else 0
        elif hi == 0xA:  # LD
            self.acc = self.regs[lo] & 0xF
        elif hi == 0xB:  # XCH
            self.acc, self.regs[lo] = self.regs[lo] & 0xF, self.acc & 0xF
        elif hi == 0xC:  # BBL
            self.acc = lo
            if not self.stack:
                self.halted = True
            else:
                self.pc = self.stack.pop()
        elif hi == 0xD:  # LDM
            self.acc = lo
        elif hi == 0xE:  # RAM / I/O
            if op == 0xE0:  # WRM
                self.ram[(self.ram_bank, self.ram_addr)] = self.acc & 0xF
            elif op == 0xE8:  # SBM
                m = self.ram.get((self.ram_bank, self.ram_addr), 0) & 0xF
                s = self.acc + (m ^ 0xF) + (self.carry ^ 1)
                self.acc = s & 0xF
                self.carry = 1 if s > 15 else 0
            elif op == 0xE9:  # RDM
                self.acc = self.ram.get((self.ram_bank, self.ram_addr), 0) & 0xF
            elif op == 0xEB:  # ADM
                m = self.ram.get((self.ram_bank, self.ram_addr), 0) & 0xF
                s = self.acc + m + self.carry
                self.acc = s & 0xF
                self.carry = 1 if s > 15 else 0
        elif hi == 0xF:  # Accumulator group
            if op == 0xF0:  # CLB
                self.acc = 0
                self.carry = 0
            elif op == 0xF1:  # CLC
                self.carry = 0
            elif op == 0xF2:  # IAC
                s = self.acc + 1
                self.acc = s & 0xF
                self.carry = 1 if s > 15 else 0
            elif op == 0xF3:  # CMC
                self.carry ^= 1
            elif op == 0xF4:  # CMA
                self.acc ^= 0xF
            elif op == 0xF5:  # RAL
                s = (self.acc << 1) | self.carry
                self.acc = s & 0xF
                self.carry = (s >> 4) & 1
            elif op == 0xF6:  # RAR
                new_c = self.acc & 1
                self.acc = ((self.carry << 3) | (self.acc >> 1)) & 0xF
                self.carry = new_c
            elif op == 0xF7:  # TCC
                self.acc = self.carry
                self.carry = 0
            elif op == 0xF8:  # DAC
                s = self.acc + 0xF
                self.acc = s & 0xF
                self.carry = 1 if s > 15 else 0
            elif op == 0xF9:  # TCS
                self.acc = 10 if self.carry else 9
                self.carry = 0
            elif op == 0xFA:  # STC
                self.carry = 1
            elif op == 0xFB:  # DAA
                if self.acc > 9 or self.carry:
                    s = self.acc + 6
                    self.acc = s & 0xF
                    if s > 15:
                        self.carry = 1
            elif op == 0xFC:  # KBP
                kbp_lut = {0: 0, 1: 1, 2: 2, 4: 3, 8: 4}
                self.acc = kbp_lut.get(self.acc, 0xF)
            elif op == 0xFD:  # DCL
                self.ram_bank = self.acc & 0x7

        return not self.halted

    def run(self, max_steps: int = 100000) -> int:
        while not self.halted and self.instructions < max_steps:
            self.step()
        return self.instructions


def verify_infer(rom_path: str) -> bool:
    with open(rom_path, "rb") as f:
        rom = bytearray(f.read())

    # Test all 4 NAND input combinations by patching the initial FIM R0R1, imm8 at 0x000
    cases = [(0, 0, 1), (0, 1, 1), (1, 0, 1), (1, 1, 0)]
    total_cycles = 0
    for x0, x1, expected in cases:
        patched = bytearray(rom)
        patched[1] = (x0 << 4) | x1
        cpu = Cpu4004(patched)
        cpu.run(max_steps=10000)
        total_cycles += cpu.cycles
        if not cpu.halted:
            print(f"FAIL infer({x0},{x1}): did not halt", file=sys.stderr)
            return False
        if cpu.acc != expected:
            print(f"FAIL infer({x0},{x1}): got {cpu.acc}, expected {expected}", file=sys.stderr)
            return False

    print(f"PASS infer: all 4 NAND cases verified (total {total_cycles} cycles, rom {len(rom)} bytes)")
    return True


def verify_train(rom_path: str) -> bool:
    with open(rom_path, "rb") as f:
        rom = f.read()

    cpu = Cpu4004(rom)
    cpu.run(max_steps=50000)
    if not cpu.halted:
        print(f"FAIL train: did not converge/halt within 50000 steps", file=sys.stderr)
        return False

    err_count = cpu.regs[12]
    epochs = cpu.regs[14]
    if err_count != 0:
        print(f"FAIL train: halted with err_count={err_count} at epoch={epochs}", file=sys.stderr)
        return False

    print(
        f"PASS train: converged to 0 errors in {epochs} epochs "
        f"({cpu.instructions} insns, {cpu.cycles} cycles, rom {len(rom)} bytes)"
    )
    return True


def main() -> None:
    parser = argparse.ArgumentParser(description="Intel 4004 ROM simulator & verifier")
    parser.add_argument("rom", help="Path to .ROM file")
    parser.add_argument("--verify-infer", action="store_true", help="Verify NAND inference ROM")
    parser.add_argument("--verify-train", action="store_true", help="Verify NAND training ROM")
    parser.add_argument("--max-steps", type=int, default=50000)
    args = parser.parse_args()

    if args.verify_infer:
        sys.exit(0 if verify_infer(args.rom) else 1)
    if args.verify_train:
        sys.exit(0 if verify_train(args.rom) else 1)

    with open(args.rom, "rb") as f:
        cpu = Cpu4004(f.read())
    cpu.run(max_steps=args.max_steps)
    print(f"halted={cpu.halted} insns={cpu.instructions} cycles={cpu.cycles} acc={cpu.acc} R12={cpu.regs[12]} R14={cpu.regs[14]}")


if __name__ == "__main__":
    main()
