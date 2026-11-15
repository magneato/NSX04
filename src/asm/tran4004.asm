; =========================================================
; NSX4004 Project - Intel 4004 Neural Network Experiments
; File: src/asm/tran4004.asm
; Author: Robert L. Sitton, Jr. of Neural Splines, LLC
; Copyright (c) 2025 Robert L. Sitton, Jr. of Neural Splines, LLC
; License: GNU AGPL-3.0-or-later
; =========================================================

;---------------------------------------------------------
;  TRAN4004.ASM — OPTIMIZED 4004 ELM / PERCEPTRON TRAINER
;---------------------------------------------------------
;  Synthesizes 4-bit optimizations across NSX4004, tsundoku, bit2 & XORNets:
;   1. True 4004 ISA: SRC for RAM, FIN on Page 1 for ROM LUTs, BBL imm4
;   2. Nibble-packed truth table (1 byte/sample) in ROM
;   3. NomNom Direct Codebook LUT for hidden activations H[0..2] (zero MUL!)
;   4. Zero-multiply binary-gate forward pass & sign-selected delta (+/-0x02)
;   5. Dual-chiral soliton rupture tracker (R13) + LFSR escape state (R15)
;
;  RAM Bank 0 Layout (8 nibbles = 4 bytes):
;   0x00, 0x01 : W_O[0] (hi, lo) in signed Q4.4
;   0x02, 0x03 : W_O[1] (hi, lo)
;   0x04, 0x05 : W_O[2] (hi, lo)
;   0x06, 0x07 : B_O    (hi, lo)
;
;  Registers:
;   R0R1 : FIN/SRC pointer     R10 : Sample index (0..3)
;   R2   : Target (0 or 1)     R11 : Prediction (0 or 1)
;   R3   : Hidden mask H[2:0]  R12 : Epoch error count
;   R4R5 : Accumulator (lo,hi) R13 : Chiral soliton rupture (CW^CCW)
;   R6R7 : Loop / temp         R14 : Epoch counter
;   R8R9 : Delta (hi, lo)      R15 : 4-bit LFSR state
;---------------------------------------------------------

MAX_EPOCHS      EQU 0x0F
NUM_SAMPLES     EQU 0x04
ERR_COUNT_REG   EQU R12

START:
    JMS INIT_WEIGHTS
    FIM R14R15, 0x05        ; R14 = epoch = 0, R15 = 4-bit LFSR seed = 0x5

TRAINING_LOOP:
    LDM 0x00
    XCH ERR_COUNT_REG       ; R12 = 0 errors
    LDM 0x00
    XCH R13                 ; R13 = 0 chiral rupture
    LDM 0x00
    XCH R10                 ; R10 = sample index 0

SAMPLE_LOOP:
    ; 1. Fetch packed sample & NomNom hidden LUT from Page 1
    LD R10
    JMS FETCH_SAMPLE        ; R2 = target (0/1), R3 = H[2:0] mask

    ; 2. Zero-multiply forward pass: sum = B_O + sum_k(H_k ? W_O[k] : 0)
    JMS FORWARD_PASS        ; R11 = pred (0/1)

    ; 3. Check prediction vs target (chiral phase comparison)
    CLC
    LD R2
    SUB R11                 ; ACC = target - pred (0 if equal)
    JCN 0x04, SAMPLE_OK     ; Zero flag -> exact match

    ; Mismatch: record error & soliton rupture bit
    LD ERR_COUNT_REG
    IAC
    XCH ERR_COUNT_REG
    LD R13
    IAC
    XCH R13

    ; 4. Sign-selected perceptron update (delta = +0x02 or -0x02 = 0xFE)
    JMS UPDATE_WEIGHTS

SAMPLE_OK:
    ; Next sample (0..3)
    LD R10
    IAC
    XCH R10
    CLC
    LDM NUM_SAMPLES
    SUB R10
    JCN 0x0C, SAMPLE_LOOP   ; Continue if R10 < 4

    ; 5. Soliton equilibrium check: if R12 == 0, converged!
    LD ERR_COUNT_REG
    JCN 0x04, TRAINING_COMPLETE

    ; Next epoch (advance LFSR & epoch counter)
    LD R15
    RAL
    XCH R15
    LD R14
    IAC
    XCH R14
    CLC
    LDM MAX_EPOCHS
    SUB R14
    JCN 0x0C, TRAINING_LOOP

TRAINING_COMPLETE:
    JMS 0x0FE               ; DUCK_HALT trap
    JUN TRAINING_COMPLETE

;---------------------------------------------------------
;  INIT_WEIGHTS — zero W_O[0..2] and B_O (8 nibbles in Bank 0)
;---------------------------------------------------------
INIT_WEIGHTS:
    LDM 0x00
    DCL
    FIM R0R1, 0x00
IW_LOOP:
    SRC R0R1
    LDM 0x00
    WRM
    INC R1
    LDM 0x08
    CLC
    SUB R1
    JCN 0x0C, IW_LOOP
    BBL 0

;---------------------------------------------------------
;  FORWARD_PASS — compute pred = act(B_O + sum_k H_k * W_O[k])
;  Input:  R3 = H[2:0] bitmask
;  Output: R11 = prediction (0 or 1)
;---------------------------------------------------------
FORWARD_PASS:
    LDM 0x00
    DCL
    FIM R4R5, 0x00          ; R4 = sum_lo, R5 = sum_hi
    LD R3
    XCH R6                  ; R6 = working copy of H[2:0]

    ; H0 -> W_O[0] at RAM 0x00
    FIM R0R1, 0x00
    JMS ADD_RAM_IF_HBIT
    ; H1 -> W_O[1] at RAM 0x02
    FIM R0R1, 0x02
    JMS ADD_RAM_IF_HBIT
    ; H2 -> W_O[2] at RAM 0x04
    FIM R0R1, 0x04
    JMS ADD_RAM_IF_HBIT
    ; B_O at RAM 0x06
    FIM R0R1, 0x06
    JMS ADD_RAM_TO_SUM
    ; Activation -> R11
    JMS ACTIVATION
    XCH R11
    BBL 0

; Shift bit 0 of R6 into carry; if 1, add RAM[R0R1] to R4R5
ADD_RAM_IF_HBIT:
    CLC
    LD R6
    RAR
    XCH R6
    JCN 0x0A, ARH_SKIP      ; Skip if CY == 0
    JUN ADD_RAM_TO_SUM
ARH_SKIP:
    BBL 0

; Add 8-bit RAM[R0R1] (hi, lo) to (R5=hi, R4=lo)
ADD_RAM_TO_SUM:
    SRC R0R1
    RDM                     ; hi nibble
    XCH R7                  ; R7 = hi
    INC R1
    SRC R0R1
    RDM                     ; lo nibble
    CLC
    ADD R4
    XCH R4                  ; R4 = lo sum, CY = carry
    LD R5
    ADD R7                  ; R5 + hi + CY
    XCH R5
    BBL 0

;---------------------------------------------------------
;  UPDATE_WEIGHTS — W_O[k] += delta (for H_k=1), B_O += delta
;  Input:  R2 = target (0 or 1), R3 = H[2:0]
;---------------------------------------------------------
UPDATE_WEIGHTS:
    LD R2
    JCN 0x04, UW_NEG        ; target == 0 (pred was 1) -> delta = -0x02 (0xFE)
    FIM R8R9, 0x00, 0x02    ; target == 1 (pred was 0) -> delta = +0x02
    JUN UW_APPLY
UW_NEG:
    FIM R8R9, 0x0F, 0x0E    ; -0x02 in 8-bit two's complement
UW_APPLY:
    LD R3
    XCH R6                  ; R6 = working copy of H[2:0]

    FIM R0R1, 0x00
    JMS UPD_RAM_IF_HBIT
    FIM R0R1, 0x02
    JMS UPD_RAM_IF_HBIT
    FIM R0R1, 0x04
    JMS UPD_RAM_IF_HBIT
    FIM R0R1, 0x06
    JMS ADD_DELTA_TO_RAM
    BBL 0

UPD_RAM_IF_HBIT:
    CLC
    LD R6
    RAR
    XCH R6
    JCN 0x0A, URH_SKIP
    JUN ADD_DELTA_TO_RAM
URH_SKIP:
    BBL 0

; RAM[R0R1] (hi, lo) += R8R9 (delta_hi, delta_lo)
ADD_DELTA_TO_RAM:
    SRC R0R1
    RDM
    XCH R4                  ; R4 = old_hi
    INC R1
    SRC R0R1
    RDM                     ; ACC = old_lo
    CLC
    ADD R9                  ; old_lo + delta_lo
    WRM                     ; write new_lo
    LD R4
    ADD R8                  ; old_hi + delta_hi + CY
    XCH R4
    ; Back up R1 by 1 (R1 += 0xF) to write new_hi
    LD R1
    CLC
    DAC
    XCH R1
    SRC R0R1
    LD R4
    WRM
    BBL 0

;---------------------------------------------------------
;  ACTIVATION — signed 8-bit Q4.4 step at +0.5 (0x08)
;  Input:  R4 = lo, R5 = hi
;  Output: ACC = 1 if 0x08 <= (R5,R4) <= 0x7F, else 0
;---------------------------------------------------------
ACTIVATION:
    CLC
    LDM 0x08
    SUB R5
    JCN 0x0A, ACT_ZERO      ; Negative if R5 >= 8
    LD R5
    JCN 0x0C, ACT_ONE       ; Positive >= 1.0
    CLC
    LDM 0x08
    SUB R4
    JCN 0x04, ACT_ONE       ; R4 == 8
    JCN 0x0A, ACT_ONE       ; R4 > 8
ACT_ZERO:
    BBL 0
ACT_ONE:
    BBL 1

;---------------------------------------------------------
;  PAGE 1 (0x100): PACKED SAMPLES & NOMNOM HIDDEN LUT
;---------------------------------------------------------
    ORG 0x100
; Packed NAND samples: bits [2:0] = (Target, X1, X0)
NAND_SAMPLES:
    DB 0x04                 ; (0,0) -> 1
    DB 0x06                 ; (0,1) -> 1
    DB 0x05                 ; (1,0) -> 1
    DB 0x03                 ; (1,1) -> 0

; NomNom 2-bit -> 3-bit ELM hidden feature codebook
HIDDEN_LUT:
    DB 0x01                 ; (0,0) -> H = 001
    DB 0x02                 ; (0,1) -> H = 010
    DB 0x04                 ; (1,0) -> H = 100
    DB 0x07                 ; (1,1) -> H = 111

; Fetch sample ACC (0..3) -> R2 = Target (0/1), R3 = H[2:0]
FETCH_SAMPLE:
    XCH R7                  ; Save sample index in R7
    LDM 0x00
    XCH R0
    LD R7
    XCH R1
    FIN R0R1                ; R1 = (Target << 2) | (X1 << 1) | X0
    LD R1
    RAR
    RAR
    RAR                     ; CY = Target bit (bit 2)
    TCC
    XCH R2                  ; R2 = Target (0 or 1)

    ; Fetch NomNom hidden mask from HIDDEN_LUT (0x104 + sample_index)
    LDM 0x00
    XCH R0
    LD R7
    CLC
    ADD R0                  ; CY=0
    LDM 0x04
    ADD R7
    XCH R1
    FIN R0R1
    LD R1
    XCH R3                  ; R3 = H[2:0]
    BBL 0
