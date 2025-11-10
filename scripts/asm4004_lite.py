import argparse
import sys
import re
from enum import Enum
from typing import List, Dict, Optional, Tuple, Union

# ═══════════════════════════════════════════════════════════════════════════════
# ◈ OPCODES AND INSTRUCTION DEFINITIONS
# ═══════════════════════════════════════════════════════════════════════════════

class OperandType(Enum):
    NONE = 0
    REGISTER = 1
    REGISTER_PAIR = 2
    IMMEDIATE = 3
    ADDRESS = 4
    CONDITION = 5
    DATA_BYTE = 6 # (Used by DB directive)

# (mnemonic, base_opcode, operand_type, operand_bits)
INSTRUCTION_SET: Dict[str, Tuple[int, OperandType, int]] = {
    # No operand instructions
    "NOP": (0x00, OperandType.NONE, 0),
    "WRM": (0xE0, OperandType.NONE, 0),
    "WMP": (0xE1, OperandType.NONE, 0),
    "WRR": (0xE2, OperandType.NONE, 0),
    "WR0": (0xE4, OperandType.NONE, 0),
    "WR1": (0xE5, OperandType.NONE, 0),
    "WR2": (0xE6, OperandType.NONE, 0),
    "WR3": (0xE7, OperandType.NONE, 0),
    "SBM": (0xE8, OperandType.NONE, 0),
    "RDM": (0xE9, OperandType.NONE, 0),
    "RDR": (0xEA, OperandType.NONE, 0),
    "ADM": (0xEB, OperandType.NONE, 0),
    "RD0": (0xEC, OperandType.NONE, 0),
    "RD1": (0xED, OperandType.NONE, 0),
    "RD2": (0xEE, OperandType.NONE, 0),
    "RD3": (0xEF, OperandType.NONE, 0),
    "CLB": (0xF0, OperandType.NONE, 0),
    "CLC": (0xF1, OperandType.NONE, 0),
    "IAC": (0xF2, OperandType.NONE, 0),
    "CMC": (0xF3, OperandType.NONE, 0),
    "CMA": (0xF4, OperandType.NONE, 0),
    "RAL": (0xF5, OperandType.NONE, 0),
    "RAR": (0xF6, OperandType.NONE, 0),
    "TCC": (0xF7, OperandType.NONE, 0),
    "DAC": (0xF8, OperandType.NONE, 0),
    "TCS": (0xF9, OperandType.NONE, 0),
    "STC": (0xFA, OperandType.NONE, 0),
    "DAA": (0xFB, OperandType.NONE, 0),
    "KBP": (0xFC, OperandType.NONE, 0),
    "DCL": (0xFD, OperandType.NONE, 0),
    "SRC": (0x21, OperandType.REGISTER_PAIR, 0), # Special case, uses bits
    "JIN": (0x31, OperandType.REGISTER_PAIR, 0), # Special case, uses bits
    
    # Register operand instructions
    "INC": (0x60, OperandType.REGISTER, 4),
    "ADD": (0x80, OperandType.REGISTER, 4),
    "SUB": (0x90, OperandType.REGISTER, 4),
    "LD":  (0xA0, OperandType.REGISTER, 4),
    "XCH": (0xB0, OperandType.REGISTER, 4),
    "FIN": (0x30, OperandType.REGISTER_PAIR, 4),
    
    # Immediate operand instructions
    "BBL": (0xC0, OperandType.IMMEDIATE, 4),
    "LDM": (0xD0, OperandType.IMMEDIATE, 4),
    
    # Register pair + immediate (2 bytes)
    "FIM": (0x20, OperandType.REGISTER_PAIR, 4),
    
    # Address operand instructions (2 bytes)
    "JCN": (0x10, OperandType.CONDITION, 4),
    "JUN": (0x40, OperandType.ADDRESS, 12),
    "JMS": (0x50, OperandType.ADDRESS, 12),
    "ISZ": (0x70, OperandType.REGISTER, 8), # Special case: reg + 8-bit addr
}

# ═══════════════════════════════════════════════════════════════════════════════
# ◈ UTILITY FUNCTIONS
# ═══════════════════════════════════════════════════════════════════════════════

def to_upper(s: str) -> str:
    return s.upper()

def trim(s: str) -> str:
    return s.strip()

def remove_comment(line: str) -> str:
    if ';' in line:
        return trim(line.split(';', 1)[0])
    return trim(line)

def normalize_symbol(name: str) -> str:
    return to_upper(trim(name))

def parse_number(s: str) -> Optional[int]:
    s = trim(s)
    if not s:
        return None
    try:
        if s.startswith(('0x', '0X')):
            return int(s, 16)
        if s.startswith('$'):
            return int(s[1:], 16)
        if s.endswith(('h', 'H')):
            return int(s[:-1], 16)
        if s.startswith(('0b', '0B')):
            return int(s, 2)
        return int(s, 10)
    except ValueError:
        return None

def parse_register(s: str) -> Optional[int]:
    s = to_upper(trim(s))
    if s.startswith('R'):
        val = parse_number(s[1:])
        if val is not None and 0 <= val <= 15:
            return val
    return None

def parse_register_pair(s: str) -> Optional[int]:
    s = to_upper(trim(s))
    # Match R0R1, R2R3, etc.
    match = re.match(r'^R(\d{1,2})R(\d{1,2})$', s)
    if match:
        r1, r2 = int(match.group(1)), int(match.group(2))
        if r1 % 2 == 0 and r2 == r1 + 1:
            return r1 // 2  # Return pair index 0-7
    return None

# ═══════════════════════════════════════════════════════════════════════════════
# ◈ ASSEMBLER CLASS
# ═══════════════════════════════════════════════════════════════════════════════

class Assembler:
    def __init__(self, verbose=True):
        self.symbols: Dict[str, int] = {}
        self.binary: bytearray = bytearray()
        self.listing: List[str] = []
        self.current_address: int = 0
        self.org_address: int = 0
        self.line_number: int = 0
        self.verbose: bool = verbose
        self.last_label: Optional[str] = None
    
    def assemble_file(self, input_file: str, output_file: str, listing_file: str) -> bool:
        try:
            with open(input_file, 'r', encoding='utf-8') as f:
                lines = f.readlines()
        except IOError as e:
            print(f"Error: Cannot open input file '{input_file}': {e}", file=sys.stderr)
            return False
            
        try:
            # Two-pass assembly
            if not self.pass_one(lines):
                return False
            
            if not self.pass_two(lines):
                return False
            
            # Write binary output
            self.write_binary(output_file)
            
            # Write listing file if requested
            if listing_file:
                self.write_listing(listing_file)
                
        except ValueError as e:
            print(f"Error: {e}", file=sys.stderr)
            return False
            
        return True

    def resolve_simple_value(self, token: str) -> Optional[int]:
        token = trim(token)
        if not token:
            return None
        val = parse_number(token)
        if val is not None:
            return val
        reg = parse_register(token)
        if reg is not None:
            return reg
        key = normalize_symbol(token)
        if key in self.symbols:
            return self.symbols[key]
        return None

    def evaluate_expression(self, expr: str) -> Optional[int]:
        expr = expr.replace(' ', '')
        if not expr or (expr.find('+') == -1 and expr.find('-') == -1):
            return None
        total = 0
        term = ''
        sign = 1
        seen_term = False
        for ch in expr:
            if ch in '+-':
                if term:
                    value = self.resolve_simple_value(term)
                    if value is None:
                        return None
                    total += sign * value
                    term = ''
                    seen_term = True
                sign = 1 if ch == '+' else -1
            else:
                term += ch
        if term:
            value = self.resolve_simple_value(term)
            if value is None:
                return None
            total += sign * value
            seen_term = True
        return total if seen_term else None

    def resolve_value(self, s: str) -> int:
        token = trim(s)
        if not token:
            raise ValueError(f"Line {self.line_number}: Missing value")
        simple = self.resolve_simple_value(token)
        if simple is not None:
            return simple
        expr = self.evaluate_expression(token)
        if expr is not None:
            return expr
        raise ValueError(f"Line {self.line_number}: Unknown symbol or invalid number: '{s}'")

    def store_symbol(self, name: str, value: int) -> None:
        self.symbols[normalize_symbol(name)] = value

    def resolve_register(self, token: str) -> Optional[int]:
        reg = parse_register(token)
        if reg is not None:
            return reg
        key = normalize_symbol(token)
        if key in self.symbols:
            val = self.symbols[key]
            if 0 <= val <= 15:
                return val
        return None

    def resolve_register_pair(self, token: str) -> Optional[int]:
        pair = parse_register_pair(token)
        if pair is not None:
            return pair
        reg = self.resolve_register(token)
        if reg is not None and reg % 2 == 0:
            return reg // 2
        return None

    def pass_one(self, lines: List[str]) -> bool:
        if self.verbose:
            print("Pass 1: Collecting symbols...")
        
        self.line_number = 0
        self.current_address = 0
        self.last_label = None

        for raw_line in lines:
            self.line_number += 1
            line = remove_comment(raw_line)
            if not line:
                continue
            
            # Check for label (ends with :)
            if ':' in line:
                label, rest = line.split(':', 1)
                label = normalize_symbol(label)
                self.store_symbol(label, self.current_address)
                self.last_label = label
                line = trim(rest)
                if not line:
                    continue

            equ_inline = re.match(r'(?i)^\s*([A-Za-z_][\w]*)\s+EQU\s+(.+)$', line)
            if equ_inline:
                symbol = normalize_symbol(equ_inline.group(1))
                value_str = trim(equ_inline.group(2))
                val = self.resolve_value(value_str)
                self.store_symbol(symbol, val)
                self.last_label = symbol
                continue
            
            # Parse directive or instruction
            parts = line.split(maxsplit=1)
            mnemonic = to_upper(parts[0])
            operand_str = trim(parts[1]) if len(parts) > 1 else ""

            # Handle directives
            if mnemonic == "ORG":
                val = self.resolve_value(operand_str)
                self.current_address = val
                self.org_address = val
                continue
            
            if mnemonic == "EQU":
                if not self.last_label:
                    raise ValueError(f"Line {self.line_number}: EQU without label")
                val = self.resolve_value(operand_str)
                self.store_symbol(self.last_label, val)
                continue
            
            if mnemonic == "DB" or mnemonic == "BYTE":
                count = len(operand_str.split(','))
                self.current_address += count
                continue
            
            if mnemonic == "DW" or mnemonic == "WORD":
                count = len(operand_str.split(','))
                self.current_address += count * 2
                continue
            
            # Find instruction
            if mnemonic in INSTRUCTION_SET:
                inst = INSTRUCTION_SET[mnemonic]
                opcode, op_type, _ = inst
                
                # Count instruction bytes
                if 0x40 <= opcode < 0x60: # JUN/JMS
                    self.current_address += 2
                elif mnemonic == "FIM":
                    self.current_address += 2
                elif mnemonic == "ISZ":
                    self.current_address += 2
                elif mnemonic == "JCN":
                    self.current_address += 2
                else:
                    self.current_address += 1
            elif self.verbose:
                print(f"Warning: Line {self.line_number}: Unknown mnemonic '{mnemonic}'", file=sys.stderr)

        if self.verbose:
            print(f"Found {len(self.symbols)} symbols")
            for name, addr in self.symbols.items():
                print(f"  {name}: 0x{addr:04X}")
        
        return True

    def pass_two(self, lines: List[str]) -> bool:
        if self.verbose:
            print("\nPass 2: Generating code...")
        
        self.line_number = 0
        self.current_address = self.org_address
        self.binary = bytearray()
        self.listing = []
        
        for raw_line in lines:
            self.line_number += 1
            line = remove_comment(raw_line)
            
            if not line:
                self.listing.append(f"{self.line_number:4d}:                              ; {raw_line.rstrip()}")
                continue
            
            # Skip labels (already processed)
            if ':' in line:
                label, rest = line.split(':', 1)
                line = trim(rest)
                if not line:
                    self.listing.append(f"{self.line_number:4d}:                              {raw_line.rstrip()}")
                    continue
            
            start_addr = self.current_address
            bytes_out = bytearray()
            
            # Parse directive or instruction
            parts = line.split(maxsplit=1)
            mnemonic = to_upper(parts[0])
            operand_str = trim(parts[1]) if len(parts) > 1 else ""
            
            # Handle directives
            if mnemonic == "ORG":
                val = self.resolve_value(operand_str)
                self.current_address = val
                # Pad binary if needed
                if len(self.binary) < self.current_address:
                    self.binary.extend([0x00] * (self.current_address - len(self.binary)))
                self.listing.append(f"{self.line_number:4d}: {start_addr:04X}                      {raw_line.rstrip()}")
                continue
            
            if mnemonic == "EQU":
                self.listing.append(f"{self.line_number:4d}:                              {raw_line.rstrip()}")
                continue

            equ_inline = re.match(r'(?i)^\s*([A-Za-z_][\w]*)\s+EQU\s+(.+)$', line)
            if equ_inline:
                self.listing.append(f"{self.line_number:4d}:                              {raw_line.rstrip()}")
                continue
            
            if mnemonic == "DB" or mnemonic == "BYTE":
                for val_str in operand_str.split(','):
                    val = self.resolve_value(trim(val_str))
                    bytes_out.append(val & 0xFF)
            
            elif mnemonic == "DW" or mnemonic == "WORD":
                for val_str in operand_str.split(','):
                    val = self.resolve_value(trim(val_str))
                    bytes_out.append(val & 0xFF)         # Low byte
                    bytes_out.append((val >> 8) & 0xFF)  # High byte
            
            else:
                # Assemble instruction
                if mnemonic not in INSTRUCTION_SET:
                    raise ValueError(f"Line {self.line_number}: Unknown instruction '{mnemonic}'")
                
                inst = INSTRUCTION_SET[mnemonic]
                bytes_out = self.assemble_instruction(mnemonic, inst, operand_str)
            
            # Add bytes to binary
            self.binary.extend(bytes_out)
            self.current_address += len(bytes_out)
            
            # Generate listing line
            byte_str = "".join(f"{b:02X} " for b in bytes_out[:4])
            self.listing.append(f"{self.line_number:4d}: {start_addr:04X} {byte_str:<12} {raw_line.rstrip()}")

            if self.verbose and bytes_out:
                print(self.listing[-1])
        
        return True

    def assemble_instruction(self, mnemonic: str, inst: Tuple[int, OperandType, int], operand_str: str) -> bytearray:
        opcode, op_type, _ = inst
        bytes_out = bytearray()
        
        if op_type == OperandType.NONE:
            bytes_out.append(opcode)
        
        elif op_type == OperandType.REGISTER:
            if mnemonic == "ISZ":
                # ISZ register, address (2 bytes)
                parts = [trim(p) for p in operand_str.split(',')]
                if len(parts) != 2:
                    raise ValueError(f"Line {self.line_number}: ISZ requires register and address")
                
                reg = self.resolve_register(parts[0])
                if reg is None:
                    raise ValueError(f"Line {self.line_number}: Invalid ISZ register: '{parts[0]}'")
                
                addr = self.resolve_value(parts[1])
                bytes_out.append(opcode | (reg & 0x0F))
                bytes_out.append(addr & 0xFF)
            else:
                # Standard 1-byte register op
                reg = self.resolve_register(operand_str)
                if reg is None:
                    raise ValueError(f"Line {self.line_number}: Invalid register: '{operand_str}'")
                bytes_out.append(opcode | (reg & 0x0F))
        
        elif op_type == OperandType.REGISTER_PAIR:
            if mnemonic == "FIM":
                # FIM R0R1, data OR FIM R0R1, hi, lo
                parts = [trim(p) for p in operand_str.split(',')]
                if not 2 <= len(parts) <= 3:
                    raise ValueError(f"Line {self.line_number}: FIM requires: Rpair,data or Rpair,hi,lo")
                
                pair = self.resolve_register_pair(parts[0])
                if pair is None:
                    raise ValueError(f"Line {self.line_number}: Invalid FIM register or pair: '{parts[0]}'")

                imm = 0
                if len(parts) == 2:
                    # Single byte immediate
                    imm = self.resolve_value(parts[1])
                else:
                    # Two nibbles: hi, lo
                    hi = self.resolve_value(parts[1])
                    lo = self.resolve_value(parts[2])
                    imm = ((hi & 0x0F) << 4) | (lo & 0x0F)
                
                bytes_out.append(opcode | (pair & 0x07))
                bytes_out.append(imm & 0xFF)
            
            else:
                # SRC R0R1 or FIN R0R1 or JIN R0R1
                pair = self.resolve_register_pair(operand_str)
                if pair is None:
                    raise ValueError(f"Line {self.line_number}: Invalid register pair: '{operand_str}'")
                bytes_out.append(opcode | (pair & 0x07))
        
        elif op_type == OperandType.IMMEDIATE:
            val = self.resolve_value(operand_str)
            bytes_out.append(opcode | (val & 0x0F))
        
        elif op_type == OperandType.CONDITION:
            # JCN condition, address (2 bytes)
            parts = [trim(p) for p in operand_str.split(',')]
            if len(parts) != 2:
                raise ValueError(f"Line {self.line_number}: JCN requires condition and address")
            
            cond = self.resolve_value(parts[0])
            addr = self.resolve_value(parts[1])
            
            bytes_out.append(opcode | (cond & 0x0F))
            bytes_out.append(addr & 0xFF)
        
        elif op_type == OperandType.ADDRESS:
            # JUN/JMS with 12-bit address (2 bytes)
            addr = self.resolve_value(operand_str)
            bytes_out.append(opcode | ((addr >> 8) & 0x0F))
            bytes_out.append(addr & 0xFF)
            
        return bytes_out

    def write_binary(self, filename: str):
        try:
            with open(filename, 'wb') as f:
                f.write(self.binary)
            if self.verbose:
                print(f"\n✓ Assembled {len(self.binary)} bytes to '{filename}'")
        except IOError as e:
            raise ValueError(f"Cannot write to '{filename}': {e}")
    
    def write_listing(self, filename: str):
        try:
            with open(filename, 'w', encoding='utf-8') as f:
                f.write("Intel 4004 Assembly Listing\n")
                f.write("Generated by asm4004.py (from C++ port)\n")
                f.write("═══════════════════════════════════════════════════════════════\n\n")
                
                for line in self.listing:
                    f.write(line + '\n')
                
                f.write("\n═══════════════════════════════════════════════════════════════\n")
                f.write(f"Total bytes: {len(self.binary)}\n")
                f.write(f"Total lines: {len(self.listing)}\n")
                
                if self.symbols:
                    f.write("\nSymbol Table:\n")
                    for name, addr in self.symbols.items():
                        f.write(f"  {name:<20} = 0x{addr:04X}\n")
                
            if self.verbose:
                print(f"✓ Listing written to '{filename}'")
        except IOError as e:
            print(f"Warning: Cannot write listing to '{filename}': {e}", file=sys.stderr)

# ═══════════════════════════════════════════════════════════════════════════════
# ◈ COMMAND LINE PARSING
# ═══════════════════════════════════════════════════════════════════════════════

def print_usage():
    print(r"""
asm4004 - Intel 4004 Assembler (Python Port)
═══════════════════════════════════════════════════════════════════════════════

Usage: asm4004.py input.asm [options]

Options:
  -o, --output FILE     Output binary file (default: input.bin)
  -l, --listing FILE    Generate listing file
  -q, --quiet           Suppress verbose output
  -v, --verbose         Enable verbose output (default)
  -h, --help            Show this help message

Examples:
  asm4004.py INFR4004.asm
  asm4004.py INFR4004.asm -o neural.bin
  asm4004.py TRAN4004.asm -o trainer.bin -l trainer.lst
  asm4004.py program.asm -l output.lst -q

Supported Directives:
  ORG address           Set origin address
  EQU value             Define constant
  DB byte [,byte...]    Define byte(s)
  DW word [,word...]    Define word(s)

Number Formats:
  123                   Decimal
  0x7F                  Hexadecimal (0x prefix)
  $7F                   Hexadecimal ($ prefix)
  7Fh                   Hexadecimal (h suffix)
  0b1010                Binary (0b prefix)

Comments:
  ; This is a comment

Labels:
  label:                Define label at current address
  JUN label             Jump to label

═══════════════════════════════════════════════════════════════════════════════
Neural Splines LLC - "Intelligence needs no cathedral."
""")

def main() -> None:
    parser = argparse.ArgumentParser(
        description="asm4004 - Intel 4004 Assembler (Python Port)",
        add_help=False # We use a custom help printer
    )
    parser.add_argument('input_file', nargs='?', help="Input .asm file")
    parser.add_argument('-o', '--output', help="Output binary file")
    parser.add_argument('-l', '--listing', help="Output listing file (optional)")
    parser.add_argument('-q', '--quiet', action='store_true', help="Suppress verbose output")
    parser.add_argument('-v', '--verbose', action='store_true', help="Enable verbose output (default)")
    parser.add_argument('-h', '--help', action='store_true', help="Show this help message")
    
    args = parser.parse_args()
    
    if args.help or not args.input_file:
        print_usage()
        sys.exit(0 if args.help else 1)
        
    verbose = (not args.quiet) or args.verbose
    
    # Set default output file
    output_file = args.output
    if not output_file:
        output_file = fs.path.splitext(args.input_file)[0] + ".bin"
        
    if verbose:
        print("asm4004 - Intel 4004 Assembler (Python Port)\n")
        print(f"Input:   {args.input_file}")
        print(f"Output:  {output_file}")
        if args.listing:
            print(f"Listing: {args.listing}")
        print("═══════════════════════════════════════════════════════════════\n")

    assembler = Assembler(verbose=verbose)
    
    if not assembler.assemble_file(args.input_file, output_file, args.listing or ""):
        print("\n✗ Assembly failed", file=sys.stderr)
        sys.exit(1)
    
    if verbose:
        print("\n✓ Assembly complete")

if __name__ == '__main__':
    main()
