#!/usr/bin/env python3
"""Simple hex dump utility.

Usage:
  python3 python/utils/hexdump.py <file>
"""

import sys


def hexdump(path: str, width: int = 16) -> None:
    try:
        with open(path, 'rb') as f:
            offset = 0
            while True:
                chunk = f.read(width)
                if not chunk:
                    break
                hex_bytes = ' '.join(f"{b:02X}" for b in chunk)
                ascii_rep = ''.join(chr(b) if 32 <= b < 127 else '.' for b in chunk)
                print(f"{offset:08X}  {hex_bytes:<{width*3}}  |{ascii_rep}|")
                offset += len(chunk)
    except FileNotFoundError:
        print(f"error: file not found: {path}", file=sys.stderr)
        sys.exit(1)


def main(argv: list[str]) -> int:
    if len(argv) != 2:
        print(__doc__.strip())
        return 2
    hexdump(argv[1])
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))

