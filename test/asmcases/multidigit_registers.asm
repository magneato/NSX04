; =========================================================
; NSX4004 Project - Intel 4004 Neural Network Experiments
; File: test/asmcases/multidigit_registers.asm
; Copyright (c) 2025 NSX4004 Project Authors
; License: GNU AGPL-3.0-or-later
; =========================================================

ORG 0x000

ENTRY:
    FIM R10R11, 0x3C
    SRC R14R15
    FIN R12R13
    ISZ R12, ENTRY
