;---------------------------------------------------------
;  INFR4004.ASM — NEURAL NETWORK INFERENCE FOR INTEL 4004
;---------------------------------------------------------
;
; "Cookie Monster say: Run NEURAL NETWORK on 1971 CPU with 4-BIT ALU!
;  This prove consciousness needs NO CATHEDRAL! Just ALGORITHM! Nom nom!" 🍪
;
; EXECUTES A PRE-TRAINED 2-3-1 NEURAL NETWORK (NAND).
; SYNTAX: COMPATIBLE WITH ASM4004 (C++23)
;---------------------------------------------------------
;---------------------------------------------------------
;  CONSTANTS AND REGISTERS
;---------------------------------------------------------
; ROM MAP:
;   0x000: START
;   0x010: INFER
;   0x080: INIT_WEIGHTS
;   0x0A0: MUL_WEIGHT
;   0x0B0: ADD_BIAS
;   0x0C0: ACTIVATION
;   0x100: WEIGHT_DATA (13 BYTES, 26 NIBBLES)
;
; REGISTERS:
;   R0, R1: INPUTS (0x0 OR 0x1)
;   R2, R3: RAM ADDRESS POINTER (R2=LOW, R3=BANK)
;   R4: TEMP (LOW NIBBLE OF 8-BIT VALUE)
;   R5: TEMP (HIGH NIBBLE OF 8-BIT VALUE) / H0
;   R6: H1
;   R7: H2
;   R12, R13: LOOP COUNTER
;   R14, R15: ROM ADDRESS POINTER
;---------------------------------------------------------
;---------------------------------------------------------
;  ENTRY POINT (ORG 0x000)
;---------------------------------------------------------
START:
    FIM R0R1, 0x00          ; INPUT 0 = 0, INPUT 1 = 0
    JMS INFER               ; JUMP TO 0x010
    ; CHANGED 'DATA' TO 'DB' FOR ASM4004
    DB 0x0F                 ; HLT MARKER (FOR EMULATOR)
    NOP                     ; PAD
;---------------------------------------------------------
;  NEURAL NETWORK INFERENCE (ORG 0x010)
;---------------------------------------------------------
INFER:
    ORG 0x010
    JMS INIT_WEIGHTS        ; JUMP TO 0x080
    ; --- HIDDEN NEURON 0: H0 = W0*X0 + W1*X1 + B0 ---
    LD R0                   ; LOAD X0
    FIM R2R3, 0x00, 0x00    ; RAM ADDR 0 (W0) IN BANK 0
    JMS MUL_WEIGHT          ; JUMP TO 0x0A0. (R5,ACC) = W0*X0
    XCH R4                  ; STORE ACC (LOW) IN R4
    ; R5 ALREADY HAS HIGH NIBBLE
    LD R1                   ; LOAD X1
    FIM R2R3, 0x02, 0x00    ; RAM ADDR 2 (W1)
    JMS MUL_WEIGHT          ; (R5,ACC) = W1*X1
    ADD R4                  ; ADD LOW NIBBLES (ACC = W0*X0_L + W1*X1_L)
    XCH R4                  ; STORE (SUM_LOW) IN R4
    LD R5                   ; LOAD (W0*X0)_HIGH
    ADD R0                  ; ADD (W1*X1)_HIGH (IN R0 FROM MUL)
    XCH R5                  ; STORE (SUM_HIGH) IN R5
    FIM R2R3, 0x0C, 0x00    ; RAM ADDR 0x0C (B0)
    JMS ADD_BIAS            ; JUMP TO 0x0B0. (R5,ACC) = SUM + B0
    JMS ACTIVATION          ; JUMP TO 0x0C0. ACC = 0 OR 1
    XCH R5                  ; STORE H0 IN R5 (R5 = 0 OR 1)
    ; --- HIDDEN NEURON 1: H1 = W2*X0 + W3*X1 + B1 ---
    LD R0
    FIM R2R3, 0x04, 0x00    ; W2
    JMS MUL_WEIGHT
    XCH R4
    ; R5 has high
    LD R1
    FIM R2R3, 0x06, 0x00    ; W3
    JMS MUL_WEIGHT
    ADD R4
    XCH R4
    LD R5
    ADD R0
    XCH R5
    FIM R2R3, 0x0E, 0x00    ; B1
    JMS ADD_BIAS
    JMS ACTIVATION
    XCH R6                  ; STORE H1 IN R6
    ; --- HIDDEN NEURON 2: H2 = W4*X0 + W5*X1 + B2 ---
    LD R0
    FIM R2R3, 0x08, 0x00    ; W4
    JMS MUL_WEIGHT
    XCH R4
    ; R5 has high
    LD R1
    FIM R2R3, 0x0A, 0x00    ; W5
    JMS MUL_WEIGHT
    ADD R4
    XCH R4
    LD R5
    ADD R0
    XCH R5
    FIM R2R3, 0x10, 0x00    ; B2
    JMS ADD_BIAS
    JMS ACTIVATION
    XCH R7                  ; STORE H2 IN R7
    ;-------------------------------------------------
    ; LAYER 2: HIDDEN -> OUTPUT (3 -> 1 NEURON)
    ;-------------------------------------------------
    ; --- OUTPUT: Y = W6*H0 + W7*H1 + W8*H2 + B3 ---
    LD R5                   ; LOAD H0
    FIM R2R3, 0x12, 0x00    ; W6
    JMS MUL_WEIGHT
    XCH R4                  ; STORE SUM_LOW
    ; R5 has sum_high
    LD R6                   ; LOAD H1
    FIM R2R3, 0x14, 0x00    ; W7
    JMS MUL_WEIGHT
    ADD R4
    XCH R4
    LD R5
    ADD R0
    XCH R5
    LD R7                   ; LOAD H2
    FIM R2R3, 0x16, 0x00    ; W8
    JMS MUL_WEIGHT
    ADD R4
    XCH R4
    LD R5
    ADD R0
    XCH R5
    FIM R2R3, 0x18, 0x00    ; B3
    JMS ADD_BIAS
    JMS ACTIVATION
    BBL 0                   ; RETURN FROM SUBROUTINE
;---------------------------------------------------------
;  INIT WEIGHTS (ORG 0x080)
;---------------------------------------------------------
; LOADS 13 8-BIT WEIGHTS (26 NIBBLES) FROM ROM 0x100
; INTO RAM BANK 0, ADDR 0x00-0x19
;
INIT_WEIGHTS:
    ORG 0x080
    FIM R0R1, 0x00, 0x00    ; R0=RAM ADDR, R1=RAM BANK
    FIM R14R15, 0x01, 0x00  ; ROM PAGE 1, ADDR 0x00
    FIM R12, 13             ; LOOP COUNTER (R12 = 13)
IW_LOOP:
    JIN R14R15              ; POINT PC TO ROM ADDR
    RDR                     ; READ HIGH NIBBLE FROM ROM
    XCH R5                  ; STORE IN R5 (TEMP)
    LD R1                   ; LOAD BANK (0)
    DCL                     ; SET RAM BANK
    FIN R0R1                ; POINT TO RAM ADDR
    LD R5                   ; LOAD NIBBLE
    WRM                     ; WRITE HIGH NIBBLE TO RAM
    INC R14                 ; BUMP ROM ADDR
    INC R0                  ; BUMP RAM ADDR
    JIN R14R15              ; POINT PC TO ROM ADDR
    RDR                     ; READ LOW NIBBLE FROM ROM
    XCH R5                  ; STORE IN R5 (TEMP)
    LD R1                   ; LOAD BANK (0)
    DCL                     ; SET RAM BANK
    FIN R0R1                ; POINT TO RAM ADDR
    LD R5                   ; LOAD NIBBLE
    WRM                     ; WRITE LOW NIBBLE TO RAM
    INC R14                 ; BUMP ROM ADDR
    INC R0                  ; BUMP RAM ADDR
    ; LOOP 13 TIMES
    ; ISZ SKIPS *NEXT* INSTRUCTION IF R12 INCR TO 0
    ISZ R12, IW_SKIP        ; INCR R12. IF 13->14..15->0, SKIP JUMP
    JUN IW_LOOP             ; JUMP BACK TO LOOP
IW_SKIP:
    BBL 0                   ; RETURN
;---------------------------------------------------------
;  MULTIPLY WEIGHT (ORG 0x0A0)
;---------------------------------------------------------
; MULTIPLIES ACC (INPUT, 0 OR 1) BY 8-BIT WEIGHT
; INPUT: ACC (0 OR 1), R2R3 (RAM ADDR OF WEIGHT)
; OUTPUT: ACC (LOW NIBBLE), R0 (HIGH NIBBLE)
;
MUL_WEIGHT:
    ORG 0x0A0
    ; JCN Z -> JCN 0x04
    JCN 0x04, MW_ZERO       ; JUMP IF ACC == 0
    ; INPUT IS 1, RESULT = WEIGHT
    LD R3                   ; LOAD BANK (0)
    DCL
    FIN R2R3                ; POINT TO WEIGHT IN RAM
    RDM                     ; READ HIGH NIBBLE
    XCH R0                  ; STORE IN R0 (FOR ADD_BIAS)
    RDM                     ; READ LOW NIBBLE
    BBL 0                   ; RETURN (ACC=LOW, R0=HIGH)
MW_ZERO:
    CLB                     ; CLEAR ACC
    XCH R0                  ; R0 = 0
    BBL 0
;---------------------------------------------------------
;  ADD BIAS (ORG 0x0B0)
;---------------------------------------------------------
; ADDS 8-BIT BIAS TO 8-BIT SUM (IN R4, R5)
; INPUT: R2R3 (RAM ADDR), R4 (SUM_LOW), R5 (SUM_HIGH)
; OUTPUT: ACC (SUM_LOW), R5 (SUM_HIGH)
;
ADD_BIAS:
    ORG 0x0B0
    LD R3                   ; LOAD BANK
    DCL
    FIN R2R3                ; POINT TO BIAS IN RAM
    RDM                     ; READ BIAS_HIGH
    ADD R5                  ; ADD SUM_HIGH
    XCH R5                  ; STORE SUM_HIGH
    RDM                     ; READ BIAS_LOW
    ADD R4                  ; ADD SUM_LOW
    BBL 0                   ; RETURN (ACC=SUM_LOW)
;---------------------------------------------------------
;  ACTIVATION (ORG 0x0C0)
;---------------------------------------------------------
; STEP FUNCTION: IF SUM >= 0.5 (0x08), ACC=1, ELSE ACC=0
; INPUT: ACC (SUM_LOW), R5 (SUM_HIGH)
; OUTPUT: ACC (0 OR 1)
;
ACTIVATION:
    ORG 0x0C0
    XCH R4                  ; STORE ACC (SUM_LOW) TO R4
    LDM 0x08                ; LOAD 0.5 (Q4.4 = 0x8)
    CLC                     ; CLEAR CARRY (FOR BORROW)
    ; SUBTRACT SUM_HIGH (R5) FROM 0.5 (ACC)
    SUB R5                  ; ACC = 0.5 - SUM_HIGH
    ; CHECK CARRY. SUB SETS CARRY=0 IF BORROW.
    ; WE JUMP TO ACT_ONE IF SUM_HIGH >= 0.5 (I.E. BORROW)
    ; JUMP IF CARRY=0. CONDITION IS C3=1 (0x02). INVERT IS C1=1 (0x08).
    ; JCN 0x0A (JUMP IF NOT CARRY=1)
    JCN 0x0A, ACT_ONE
ACT_ZERO:
    CLB                     ; ACC = 0
    BBL 0
ACT_ONE:
    CLB                     ; CLEAR ACC
    IAC                     ; ACC = 1
    BBL 0
;---------------------------------------------------------
;  TRAINED WEIGHTS (ORG 0x100)
;---------------------------------------------------------
; 13 BYTES (26 NIBBLES) OF Q4.4 DATA
; GENERATED BY TRAIN4004.CPP
;
WEIGHT_DATA:
    ORG 0x100
    ; DB ... (DATA WILL BE FILLED IN BY TRAIN4004)