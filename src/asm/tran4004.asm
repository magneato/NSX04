; =========================================================
; NSX4004 Project - Intel 4004 Neural Network Experiments
; File: tran4004.asm
; Copyright (c) 2025 Neural Splines, LLC - Licensed under AGPL-3.0-or-later
; License: GNU AGPL-3.0-or-later
; =========================================================

;---------------------------------------------------------
;  TRAN4004.ASM — NEURAL NETWORK TRAINING FOR INTEL 4004
;---------------------------------------------------------
;
; "Cookie Monster say: Even TINY BRAIN can learn! Just need right algorithm.
;  Extreme Learning Machine on 2,300 transistors. This is NOM NOM MAGIC!" 🍪
;
; This program trains a tiny 2–3–1 neural network to implement the
; NAND logic gate entirely on an Intel 4004.  It uses a fixed‑feature
; extreme learning machine: the input→hidden weights (W_H) and biases
; (B_H) are randomized once and never updated, while the output layer
; (W_O and B_O) learns via a simple perceptron rule.  See
; README_TRAN4004.md for a high‑level overview and algorithm details.
;
; The code is structured around three main phases:
;  1. INIT_WEIGHTS randomizes W_H/B_H and zeroes W_O/B_O
;  2. LOAD_TRAINING_DATA writes the NAND truth table into RAM bank 1
;  3. A training loop performs forward passes and output‑layer
;     updates until the network classifies all four samples correctly
;
; All arithmetic is performed in Q4.4 fixed‑point.  See the docs
; for details on this format and the activation function.
;
;  NOTE: This file uses only legal 4004 instructions.  Custom
;  emulator traps (DuckOps) can be layered on top of this ROM via
;  the DUCKER.COM emulator if desired; see include/duckops.inc.
;
; SYNTAX: Compatible with asm4004_lite.py and NASM‑style assemblers

;---------------------------------------------------------
;  CONSTANTS AND REGISTERS
;---------------------------------------------------------

LEARNING_RATE   EQU 0x02        ; η = 0.125 in Q4.4 (1/8)
MAX_EPOCHS      EQU 0x0F        ; Train up to 15 epochs (4‑bit counter)
NUM_SAMPLES     EQU 0x04        ; Four samples in NAND truth table
ERR_COUNT_REG   EQU R12         ; Register holding error count per epoch

; RAM LAYOUT (bank 0 unless specified)
W_H_ADDR        EQU 0x00        ; 6 input→hidden weights (12 nibbles)
B_H_ADDR        EQU 0x0C        ; 3 hidden biases      (6 nibbles)
W_O_ADDR        EQU 0x12        ; 3 hidden→output weights (6 nibbles)
B_O_ADDR        EQU 0x18        ; 1 output bias        (2 nibbles)
H_ACTS_ADDR     EQU 0x1A        ; 3 hidden activations  (6 nibbles)
TRAIN_DATA_BANK EQU 0x01        ; RAM bank 1 holds training samples
WEIGHT_BANK     EQU 0x00        ; RAM bank 0 holds weights and biases

; REGISTERS
;  R0R1   – RAM pointer (address/bank)
;  R2R3   – Input X0
;  R4R5   – Input X1
;  R6R7   – Target/Error
;  R8R9   – Prediction/Temporary
;  R10–R15 – Loop counters and temps

;---------------------------------------------------------
;  ENTRY POINT
;---------------------------------------------------------

START:
    ; 1. Randomize hidden layer weights/biases and clear output layer
    JMS INIT_WEIGHTS
    ; 2. Populate training data in bank 1
    JMS LOAD_TRAINING_DATA
    ; 3. Main training loop – iterate epochs until converged or limit
    FIM R14, 0x00           ; Epoch counter = 0
TRAINING_LOOP:
    ; Reset error count for this epoch
    LDM 0x00
    XCH ERR_COUNT_REG
    ; Sample index = 0
    FIM R10, 0x00

SAMPLE_LOOP:
    ; ------------------------------------------------------
    ; Load one training sample (X0, X1, Target) from bank 1
    ; Each sample occupies 6 nibbles: X0_hi, X0_lo, X1_hi, X1_lo, T_hi, T_lo
    ; R10 indexes samples 0..3; offset = R10 × 6
    ; ------------------------------------------------------
    ; Compute RAM offset = sample_index * 6 (result in R0)
    ; We reuse R15 as a temp for the high nibble (ignored)
    LD R10
    LDM 0x06
    JMS Q44_MULTIPLY_BY_CONST  ; R0 = R10 * 6 (low nibble)
    ; Set bank 1 and point R0R1 at computed offset
    LDM TRAIN_DATA_BANK
    DCL                       ; Select RAM bank 1
    FIN R0R1                  ; Load R0R1 with current offset
    ; Read X0 (16‑bit Q4.4)
    RDM
    XCH R2                    ; X0_hi → R2
    RDM
    XCH R3                    ; X0_lo → R3
    ; Read X1
    RDM
    XCH R4
    RDM
    XCH R5
    ; Read Target
    RDM
    XCH R6
    RDM
    XCH R7

    ; ------------------------------------------------------
    ; Forward pass: compute hidden activations and output prediction
    ; Input: R2R3 (X0), R4R5 (X1)
    ; Output: R8R9 (prediction), hidden activations saved to RAM
    ; ------------------------------------------------------
    JMS FORWARD_PASS

    ; ------------------------------------------------------
    ; Compute error = target – prediction → R6R7
    ; (If error == 0, prediction matches target)
    ; ------------------------------------------------------
    JMS Q44_SUBTRACT

    ; ------------------------------------------------------
    ; Update output layer weights if error ≠ 0
    ; Check both nibbles: ACC = R6 + R7; if ACC == 0 then no update
    ; ------------------------------------------------------
    LD R6
    ADD R7
    JCN 0x04, NO_WEIGHT_UPDATE  ; Branch if ACC==0 (zero flag)
    JMS UPDATE_WEIGHTS
    ; Increment error count
    LD ERR_COUNT_REG
    IAC
    XCH ERR_COUNT_REG
NO_WEIGHT_UPDATE:
    ; Advance sample index
    LD R10
    IAC
    XCH R10
    ; Loop until all samples processed
    CLC
    LDM NUM_SAMPLES
    SUB R10
    JCN 0x0C, SAMPLE_LOOP       ; NZ → continue loop

    ; ------------------------------------------------------
    ; Check convergence: if no errors this epoch, training complete
    ; ------------------------------------------------------
    LD ERR_COUNT_REG
    JCN 0x04, TRAINING_COMPLETE ; Zero flag → no errors

    ; ------------------------------------------------------
    ; Next epoch: increment epoch counter and check against max
    ; ------------------------------------------------------
    LD R14
    IAC
    XCH R14
    CLC
    LDM MAX_EPOCHS
    SUB R14
    JCN 0x0C, TRAINING_LOOP     ; NZ → more epochs

TRAINING_COMPLETE:
    ; Save trained weights (conceptual – no host I/O in pure 4004)
    JMS SAVE_WEIGHTS
    ; Halt via DuckOp (emulator trap) or spin forever on real 4004
    ; Use custom JMS to 0x0FE (DUCK_HALT) if supported, else DB 0x0F
    JMS 0x0FE
    JUN TRAINING_COMPLETE

;---------------------------------------------------------
;  SUBROUTINES
;---------------------------------------------------------

; Load the four NAND samples into RAM bank 1.
LOAD_TRAINING_DATA:
    LDM TRAIN_DATA_BANK
    DCL
    ; Sample 0: 0,0 → 1 (0x10)
    FIM R0R1, 0x00
    FIN R0R1
    LDM 0x00
    WRM
    LDM 0x00
    WRM
    LDM 0x00
    WRM
    LDM 0x00
    WRM
    LDM 0x01
    WRM
    LDM 0x00
    WRM
    ; Sample 1: 0,1 → 1
    FIM R0R1, 0x06
    FIN R0R1
    LDM 0x00
    WRM
    LDM 0x00
    WRM
    LDM 0x01
    WRM
    LDM 0x00
    WRM
    LDM 0x01
    WRM
    LDM 0x00
    WRM
    ; Sample 2: 1,0 → 1
    FIM R0R1, 0x0C
    FIN R0R1
    LDM 0x01
    WRM
    LDM 0x00
    WRM
    LDM 0x00
    WRM
    LDM 0x00
    WRM
    LDM 0x01
    WRM
    LDM 0x00
    WRM
    ; Sample 3: 1,1 → 0
    FIM R0R1, 0x12
    FIN R0R1
    LDM 0x01
    WRM
    LDM 0x00
    WRM
    LDM 0x01
    WRM
    LDM 0x00
    WRM
    LDM 0x00
    WRM
    LDM 0x00
    WRM
    BBL 0

; Randomize hidden layer weights/biases and zero output layer.
INIT_WEIGHTS:
    LDM WEIGHT_BANK
    DCL
    ; Randomize W_H and B_H
    FIM R0R1, W_H_ADDR
    FIM R8R9, 0x07, 0x05    ; Seed = 0x75
    FIM R12, 9              ; 9 values (W_H[6] + B_H[3])
INIT_W_LOOP:
    ; Simple pseudo‑random shuffle (XOR & shifts)
    LD R8
    RAL
    RAL
    ADD R9
    XCH R8
    LD R9
    RAR
    ADD R8
    XCH R9
    ; Write high nibble
    FIN R0R1
    WRM
    INC R0
    ; Write low nibble
    FIN R0R1
    LD R9
    WRM
    INC R0
    ISZ R12, INIT_W_SKIP
    JUN INIT_W_LOOP
INIT_W_SKIP:
    ; Zero W_O and B_O
    ; W_O: 3 weights (6 nibbles)
    FIM R0R1, W_O_ADDR
    FIN R0R1
    LDM 0x00
    WRM
    INC R0
    FIN R0R1
    WRM
    INC R0
    FIN R0R1
    LDM 0x00
    WRM
    INC R0
    FIN R0R1
    WRM
    INC R0
    FIN R0R1
    LDM 0x00
    WRM
    INC R0
    FIN R0R1
    WRM
    ; B_O: 1 bias (2 nibbles)
    FIM R0R1, B_O_ADDR
    FIN R0R1
    LDM 0x00
    WRM
    INC R0
    FIN R0R1
    LDM 0x00
    WRM
    BBL 0

;---------------------------------------------------------
; FORWARD_PASS — compute hidden activations and final output
;---------------------------------------------------------
; Input:  R2R3 = X0, R4R5 = X1
; Output: R8R9 = prediction (binary Q4.4 value)
; Uses:   R0–R5, R8–R15 (temps).  Hidden activations saved to H_ACTS_ADDR.
FORWARD_PASS:
    ; Switch to weight bank
    LDM WEIGHT_BANK
    DCL
    ; ---------------------------
    ; Hidden neuron 0:
    ; sum = W0*X0 + W1*X1 + B0
    LD R2
    XCH R8
    LD R3
    XCH R9
    FIM R0R1, W_H_ADDR
    JMS Q44_MULTIPLY_FROM_RAM    ; R8R9 = X0 * W0
    XCH R10
    XCH R11                     ; R10R11 = term0
    LD R4
    XCH R8
    LD R5
    XCH R9
    FIM R0R1, W_H_ADDR+2
    JMS Q44_MULTIPLY_FROM_RAM    ; R8R9 = X1 * W1
    ; Add term0
    LD R10
    XCH R10
    LD R11
    XCH R11
    JMS Q44_ADD                  ; R8R9 += R10R11
    ; Add B0
    FIM R0R1, B_H_ADDR
    JMS Q44_ADD_FROM_RAM
    ; Activation → H0
    JMS ACTIVATION
    ; Save H0 to RAM (R8R9)
    FIM R0R1, H_ACTS_ADDR
    JMS Q44_WRITE_TO_RAM

    ; ---------------------------
    ; Hidden neuron 1:
    ; sum = W2*X0 + W3*X1 + B1
    LD R2
    XCH R8
    LD R3
    XCH R9
    FIM R0R1, W_H_ADDR+4
    JMS Q44_MULTIPLY_FROM_RAM    ; X0 * W2
    XCH R13
    XCH R15
    LD R4
    XCH R8
    LD R5
    XCH R9
    FIM R0R1, W_H_ADDR+6
    JMS Q44_MULTIPLY_FROM_RAM    ; X1 * W3
    LD R13
    XCH R10
    LD R15
    XCH R11
    JMS Q44_ADD
    FIM R0R1, B_H_ADDR+2
    JMS Q44_ADD_FROM_RAM
    JMS ACTIVATION
    ; Save H1
    FIM R0R1, H_ACTS_ADDR+2
    JMS Q44_WRITE_TO_RAM

    ; ---------------------------
    ; Hidden neuron 2:
    ; sum = W4*X0 + W5*X1 + B2
    LD R2
    XCH R8
    LD R3
    XCH R9
    FIM R0R1, W_H_ADDR+8
    JMS Q44_MULTIPLY_FROM_RAM
    XCH R13
    XCH R15
    LD R4
    XCH R8
    LD R5
    XCH R9
    FIM R0R1, W_H_ADDR+10
    JMS Q44_MULTIPLY_FROM_RAM
    LD R13
    XCH R10
    LD R15
    XCH R11
    JMS Q44_ADD
    FIM R0R1, B_H_ADDR+4
    JMS Q44_ADD_FROM_RAM
    JMS ACTIVATION
    ; Save H2
    FIM R0R1, H_ACTS_ADDR+4
    JMS Q44_WRITE_TO_RAM

    ; ---------------------------
    ; Output neuron:
    ; sum = W6*H0 + W7*H1 + W8*H2 + B3
    FIM R0R1, H_ACTS_ADDR
    JMS LOAD_H_ACT              ; R8R9 = H0
    FIM R0R1, W_O_ADDR
    JMS Q44_MULTIPLY_FROM_RAM   ; R8R9 = H0*W6
    XCH R10
    XCH R11                    ; R10R11 = term0
    FIM R0R1, H_ACTS_ADDR+2
    JMS LOAD_H_ACT             ; R8R9 = H1
    FIM R0R1, W_O_ADDR+2
    JMS Q44_MULTIPLY_FROM_RAM   ; R8R9 = H1*W7
    JMS Q44_ADD                 ; R8R9 += term0
    XCH R10
    XCH R11                    ; R10R11 = sum
    FIM R0R1, H_ACTS_ADDR+4
    JMS LOAD_H_ACT             ; R8R9 = H2
    FIM R0R1, W_O_ADDR+4
    JMS Q44_MULTIPLY_FROM_RAM   ; R8R9 = H2*W8
    JMS Q44_ADD                 ; R8R9 += sum
    FIM R0R1, B_O_ADDR
    JMS Q44_ADD_FROM_RAM        ; + B3
    JMS ACTIVATION
    BBL 0

; Save hidden activation from R10R11 into RAM
SAVE_H_ACT:
    ; Input: R0R1 points to location, R10R11 holds value
    FIN R0R1
    LD R10
    WRM
    INC R0
    FIN R0R1
    LD R11
    WRM
    INC R0
    BBL 0

; Load hidden activation from RAM into R8R9
LOAD_H_ACT:
    FIN R0R1
    RDM
    XCH R8
    INC R0
    FIN R0R1
    RDM
    XCH R9
    INC R0
    BBL 0

;---------------------------------------------------------
; UPDATE_WEIGHTS — perceptron update on output layer
;---------------------------------------------------------
; Input:
;   R6R7 = error (target - prediction) in Q4.4
; Uses:
;   R8R9 – temp, R10R11 – delta, R2R3 – LR constant, R0R1 – RAM pointer
; Performs:
;   delta = LEARNING_RATE × error
;   B_O += delta
;   For i in 0..2: if H[i] ≠ 0 then W_O[i] += delta
UPDATE_WEIGHTS:
    ; Switch to weight bank
    LDM WEIGHT_BANK
    DCL
    ; Compute delta = LR * error (store in R10R11)
    LD R6
    XCH R8
    LD R7
    XCH R9
    LDM LEARNING_RATE
    XCH R2
    LDM 0x00
    XCH R3
    JMS Q44_MULTIPLY
    LD R8
    XCH R10
    LD R9
    XCH R11
    ; Update bias: B_O += delta
    FIM R0R1, B_O_ADDR
    JMS Q44_ADD_FROM_RAM
    JMS Q44_WRITE_TO_RAM
    ; Loop over three weights
    FIM R0R1, H_ACTS_ADDR
    FIM R2R3, W_O_ADDR
    ; Weight 0
    JMS LOAD_H_ACT
    LD R8
    ADD R9
    JCN 0x04, UW_SKIP0        ; skip if H0 = 0
    ; Add delta to W0
    LD R10
    XCH R8
    LD R11
    XCH R9
    FIN R2R3
    JMS Q44_ADD_FROM_RAM
    JMS Q44_WRITE_TO_RAM
UW_SKIP0:
    INC R2
    INC R2
    ; Weight 1
    JMS LOAD_H_ACT
    LD R8
    ADD R9
    JCN 0x04, UW_SKIP1
    LD R10
    XCH R8
    LD R11
    XCH R9
    FIN R2R3
    JMS Q44_ADD_FROM_RAM
    JMS Q44_WRITE_TO_RAM
UW_SKIP1:
    INC R2
    INC R2
    ; Weight 2
    JMS LOAD_H_ACT
    LD R8
    ADD R9
    JCN 0x04, UW_SKIP2
    LD R10
    XCH R8
    LD R11
    XCH R9
    FIN R2R3
    JMS Q44_ADD_FROM_RAM
    JMS Q44_WRITE_TO_RAM
UW_SKIP2:
    BBL 0

;---------------------------------------------------------
; Q4.4 MATH ROUTINES
;---------------------------------------------------------

; R8R9 += R10R11 (handles carry)
Q44_ADD:
    LD R9
    ADD R11
    XCH R9
    JCN 0x02, Q44_ADD_NC
    LD R8
    IAC
    XCH R8
Q44_ADD_NC:
    LD R8
    ADD R10
    XCH R8
    BBL 0

; Add RAM value at R0R1 to R8R9
Q44_ADD_FROM_RAM:
    FIN R0R1
    RDM
    XCH R10
    INC R0
    FIN R0R1
    RDM
    XCH R11
    JMS Q44_ADD
    BBL 0

; Write R8R9 to RAM at R0R1
Q44_WRITE_TO_RAM:
    FIN R0R1
    LD R8
    WRM
    INC R0
    FIN R0R1
    LD R9
    WRM
    BBL 0

; Multiply R8R9 by R2R3 (8×8 → 16 bits); Q4.4 result in R8R9
Q44_MULTIPLY:
    ; Copy operands: B = R2R3 → R10R11, A = R8R9 → R13R15
    LD R3
    XCH R10
    LD R2
    XCH R11
    LD R9
    XCH R13
    LD R8
    XCH R15
    ; Clear result
    CLB
    XCH R8
    XCH R9
    ; Bit counter = 8
    LDM 0x08
    XCH R14
Q44_MUL_LOOP:
    ; Shift A right
    LD R13
    RAR
    XCH R13
    LD R15
    RAR
    XCH R15
    ; If carry set then add B
    JCN 0x02, Q44_MUL_NO_ADD
    JMS Q44_ADD
Q44_MUL_NO_ADD:
    ; Shift B left
    LD R10
    RAL
    XCH R10
    LD R11
    RAL
    XCH R11
    ; Loop count
    ISZ R14, Q44_MUL_LOOP
    ; Final shift right 4 to adjust Q4.4
    LD R8
    XCH R9
    CLB
    XCH R8
    BBL 0

; Multiply R8R9 by RAM value at R0R1
Q44_MULTIPLY_FROM_RAM:
    FIN R0R1
    RDM
    XCH R2
    INC R0
    FIN R0R1
    RDM
    XCH R3
    JMS Q44_MULTIPLY
    BBL 0

; Multiply ACC (low nibble) by constant and store in R0 (low nibble)
; Used for sample index × 6 (constant multiply)
Q44_MULTIPLY_BY_CONST:
    XCH R2
    CLB
    XCH R3
    ; R2R3 = ACC (R10)
    LDM 0x00
    XCH R8
    XCH R9
    JMS Q44_MULTIPLY
    LD R9
    XCH R0
    BBL 0

; Subtract B (R8R9) from A (R6R7) → R6R7
Q44_SUBTRACT:
    LDM 0x0F
    SUB R8
    XCH R8
    LDM 0x0F
    SUB R9
    XCH R9
    LD R9
    IAC
    XCH R9
    JCN 0x02, Q44_SUB_NO_C
    LD R8
    IAC
    XCH R8
Q44_SUB_NO_C:
    LD R7
    ADD R9
    XCH R7
    LD R6
    ADD R8
    XCH R6
    BBL 0

; Activation function: step at 0.5 (0x08)
; If input ≥ 0.5 → output = 1.0 (0x10); else 0
ACTIVATION:
    ; Check high nibble (R8) – if non‑zero then result ≥ 1 → output 1
    LD R8
    JCN 0x04, ACT_CHECK_LOW       ; Zero flag → R8==0
    CLB
    XCH R8
    LDM 0x01
    XCH R9
    BBL 0
ACT_CHECK_LOW:
    ; High nibble is zero; check fractional nibble (R9) ≥ 0x08
    LDM 0x08
    SUB R9
    JCN 0x02, ACT_ZERO           ; Borrow (carry=0) → R9 < 0x08 → output 0
    ; Else output 1
    CLB
    XCH R8
    LDM 0x01
    XCH R9
    BBL 0
ACT_ZERO:
    CLB
    XCH R8
    XCH R9
    BBL 0

;---------------------------------------------------------
; SAVE_WEIGHTS — placeholder for host save
;---------------------------------------------------------
; In pure 4004 mode this subroutine does nothing.  When running under
; DUCKER.COM with DuckOps support, you can patch this routine to
; execute a custom emulator trap that writes the trained weights back
; to a host file.  See ducker/DUCKER_SYSCALL_NOTES.md for details.
SAVE_WEIGHTS:
    ; Placeholder: no operation
    BBL 0
