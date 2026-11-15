; =========================================================
; NSX4004 Project - Intel 4004 Neural Network Experiments
; File: src/asm/infr4004.asm
; Author: Robert L. Sitton, Jr. of Neural Splines, LLC
; Copyright (c) 2025 Robert L. Sitton, Jr. of Neural Splines, LLC
; License: GNU AGPL-3.0-or-later
; =========================================================

;---------------------------------------------------------
;  INFR4004.ASM — OPTIMIZED 4004 NEURAL INFERENCE ROM
;---------------------------------------------------------
;  Executes a pre-trained 2-3-1 Q4.4 NAND network on Intel 4004:
;   - Zero-multiply binary-gate forward pass (conditional add)
;   - Direct ROM LUT reads via FIN (zero RAM copy overhead)
;   - Signed 8-bit Q4.4 step activation (threshold >= 0x08)
;
;  INPUT:  R0 = X0 (0 or 1), R1 = X1 (0 or 1)
;  OUTPUT: ACC = NAND(X0, X1) (0 or 1)
;---------------------------------------------------------

START:
    FIM R0R1, 0x00          ; Default input (X0=0, X1=0); patchable at 0x001
    JMS INFER
    LD R11                  ; Load output Y into ACC
    DB 0x0F                 ; Emulator HLT marker

;---------------------------------------------------------
;  INFER (Page 0)
;---------------------------------------------------------
INFER:
    ; Save inputs X0, X1 in R2, R3
    LD R0
    XCH R2                  ; R2 = X0
    LD R1
    XCH R3                  ; R3 = X1

    ; --- Hidden Neuron 0: H0 = act(W0*X0 + W1*X1 + B0) ---
    FIM R4R5, 0x00          ; R4 = sum_lo, R5 = sum_hi
    FIM R6R7, 0x00          ; R6 = ROM index in page 1 (0x00 = W0)
    LD R2
    JMS ADD_IF_BIT          ; + W0 if X0 == 1
    FIM R6R7, 0x01          ; W1
    LD R3
    JMS ADD_IF_BIT          ; + W1 if X1 == 1
    FIM R6R7, 0x02          ; B0
    JMS ADD_ROM_WEIGHT      ; + B0
    JMS ACTIVATION
    XCH R8                  ; R8 = H0

    ; --- Hidden Neuron 1: H1 = act(W2*X0 + W3*X1 + B1) ---
    FIM R4R5, 0x00
    FIM R6R7, 0x03          ; W2
    LD R2
    JMS ADD_IF_BIT
    FIM R6R7, 0x04          ; W3
    LD R3
    JMS ADD_IF_BIT
    FIM R6R7, 0x05          ; B1
    JMS ADD_ROM_WEIGHT
    JMS ACTIVATION
    XCH R9                  ; R9 = H1

    ; --- Hidden Neuron 2: H2 = act(W4*X0 + W5*X1 + B2) ---
    FIM R4R5, 0x00
    FIM R6R7, 0x06          ; W4
    LD R2
    JMS ADD_IF_BIT
    FIM R6R7, 0x07          ; W5
    LD R3
    JMS ADD_IF_BIT
    FIM R6R7, 0x08          ; B2
    JMS ADD_ROM_WEIGHT
    JMS ACTIVATION
    XCH R10                 ; R10 = H2

    ; --- Output Neuron: Y = act(W6*H0 + W7*H1 + W8*H2 + B3) ---
    FIM R4R5, 0x00
    FIM R6R7, 0x09          ; W6
    LD R8
    JMS ADD_IF_BIT
    FIM R6R7, 0x0A          ; W7
    LD R9
    JMS ADD_IF_BIT
    FIM R6R7, 0x0B          ; W8
    LD R10
    JMS ADD_IF_BIT
    FIM R6R7, 0x0C          ; B3
    JMS ADD_ROM_WEIGHT
    JMS ACTIVATION
    XCH R11                 ; Store Y in R11
    BBL 0

;---------------------------------------------------------
;  ADD_IF_BIT — if ACC != 0, add ROM[0x100 + R6R7] to R4R5
;---------------------------------------------------------
ADD_IF_BIT:
    JCN 0x04, AIB_DONE      ; Skip if ACC == 0
    JUN ADD_ROM_WEIGHT
AIB_DONE:
    BBL 0

;---------------------------------------------------------
;  ACTIVATION — signed 8-bit Q4.4 step at +0.5 (0x08)
;  Input:  R4 = low nibble, R5 = high nibble
;  Output: ACC = 1 if 0x08 <= (R5,R4) <= 0x7F, else 0
;---------------------------------------------------------
ACTIVATION:
    ; Check sign bit: if R5 >= 8 (negative), return 0
    CLC
    LDM 0x08
    SUB R5                  ; borrow (CY=0) if R5 >= 8
    JCN 0x0A, ACT_ZERO      ; jump if CY == 0 (negative)
    ; Check if R5 > 0 (positive >= 1.0)
    LD R5
    JCN 0x0C, ACT_ONE       ; jump if R5 != 0
    ; R5 == 0: check R4 >= 0x08
    CLC
    LDM 0x08
    SUB R4                  ; borrow (CY=0) if R4 >= 8; if R4==8 -> CY=1, ACC=0!
    JCN 0x04, ACT_ONE       ; R4 == 8
    JCN 0x0A, ACT_ONE       ; R4 > 8 (CY == 0)
ACT_ZERO:
    BBL 0
ACT_ONE:
    BBL 1

;---------------------------------------------------------
;  PAGE 1 (0x100): PRE-TRAINED Q4.4 WEIGHTS & ROM READER
;---------------------------------------------------------
;  FIN reads from the CURRENT ROM page! Placing ADD_ROM_WEIGHT
;  on Page 1 lets FIN R0R1 read WEIGHT_DATA directly at 0x100..0x10C.
;---------------------------------------------------------
    ORG 0x100
WEIGHT_DATA:
    DB 0x08                 ; 0x00: W0 = +0.50
    DB 0x08                 ; 0x01: W1 = +0.50
    DB 0xFC                 ; 0x02: B0 = -0.25
    DB 0x10                 ; 0x03: W2 = +1.00
    DB 0x00                 ; 0x04: W3 =  0.00
    DB 0x00                 ; 0x05: B1 =  0.00
    DB 0x00                 ; 0x06: W4 =  0.00
    DB 0x10                 ; 0x07: W5 = +1.00
    DB 0x00                 ; 0x08: B2 =  0.00
    DB 0xE8                 ; 0x09: W6 = -1.50
    DB 0xFC                 ; 0x0A: W7 = -0.25
    DB 0xFC                 ; 0x0B: W8 = -0.25
    DB 0x10                 ; 0x0C: B3 = +1.00

;---------------------------------------------------------
;  ADD_ROM_WEIGHT — R4R5 += signed 8-bit ROM[0x100 + R7]
;  Uses R0R1 as FIN pointer; result in (R5=hi, R4=lo)
;---------------------------------------------------------
ADD_ROM_WEIGHT:
    LD R6
    XCH R0
    LD R7
    XCH R1
    FIN R0R1                ; R0 = high nibble, R1 = low nibble
    CLC
    LD R4
    ADD R1
    XCH R4                  ; R4 = low sum, CY = low carry
    LD R5
    ADD R0                  ; R5 + R0 + CY
    XCH R5
    BBL 0
