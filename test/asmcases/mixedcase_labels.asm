; =========================================================
; NSX4004 Project - Intel 4004 Neural Network Experiments
; File: test/asmcases/mixedcase_labels.asm
; Copyright (c) 2025 NSX4004 Project Authors
; License: GNU AGPL-3.0-or-later
; =========================================================

org 0x000

InitLabel:
    JUN runLoop

runloop:
    Kbp
    jCn 0x0F, endlabel
    JUN RUNLOOP

endLabel:
    BBL 0
