; =========================================================
; NSX4004 Project - Intel 4004 Neural Network Experiments
; File: edgecase.asm
; Copyright (c) 2025 NSX4004 Project Authors
; License: GNU AGPL-3.0-or-later
; =========================================================

; AGI4004 Critical Edge Case Handlers
; "The shadows contain the truth the light obscures"

;═════════════════════════════════════════════════════════════
; Q4.4 OVERFLOW/UNDERFLOW PROTECTION
;═════════════════════════════════════════════════════════════
; The 4004 doesn't have overflow flags. We must be smarter.

q44_saturate:
    ; Input: ACC (8-bit Q4.4 value to check)
    ; Output: ACC (saturated to valid Q4.4 range)
    ; The universe doesn't overflow - it saturates at boundaries
    
    XCH R4          ; Save original value
    LDM 0x07        ; Maximum positive Q4.4 (7.9375)
    CLC
    SUB R4          ; Check if value > max
    JCN 0x0A, .check_negative  ; Jump if no borrow (value <= max)
    
    ; Positive overflow - saturate to max
    LDM 0x07
    XCH R4
    LDM 0x0F
    BBL 0           ; Return 0x7F (maximum Q4.4)
    
.check_negative:
    LD R4           ; Restore original
    LDM 0x08        ; Check sign bit
    CLC
    SUB R4
    JCN 0x02, .no_saturation  ; Jump if positive
    
    ; Check for negative overflow
    LD R4
    CLC
    LDM 0x08        ; Minimum negative Q4.4 (-8.0)
    ADD R4
    JCN 0x0A, .negative_overflow
    
.no_saturation:
    LD R4           ; Return original value
    BBL 0
    
.negative_overflow:
    LDM 0x08        ; Saturate to minimum
    BBL 0

;═════════════════════════════════════════════════════════════
; BRESENHAM THRESHOLD EDGE CASES
;═════════════════════════════════════════════════════════════
; When error accumulation approaches nibble boundaries

bgd_boundary_check:
    ; Prevents accumulator wraparound at 4-bit boundaries
    ; This is where discrete mathematics meets reality
    
    LD R5           ; Load error accumulator high nibble
    XCH R6          ; Save it
    LD R4           ; Load error accumulator low nibble
    
    ; Check if we're about to cross nibble boundary
    CLC
    LDM 0x0F
    SUB R4
    JCN 0x04, .no_boundary  ; Jump if not at boundary
    
    ; At boundary - apply discrete step
    LD R6
    IAC             ; Increment high nibble
    XCH R6
    LDM 0x00        ; Reset low nibble
    XCH R4
    
.no_boundary:
    BBL 0

;═════════════════════════════════════════════════════════════
; SELF-MODIFYING CODE BOUNDARY PROTECTION
;═════════════════════════════════════════════════════════════
; SMC must not corrupt its own modification logic

smc_guard:
    ; Protects critical instruction boundaries during self-modification
    ; The code that changes itself must not change the changer
    
    FIM R8R9, 0x100, 0x00   ; Start of protected region
    FIM R10R11, 0x1FF, 0x0F ; End of protected region
    
    ; Check if target address is in protected region
    LD R14          ; Current modification target (high)
    XCH R12
    LD R15          ; Current modification target (low)
    XCH R13
    
    ; Compare with boundaries
    LD R8
    CLC
    SUB R12
    JCN 0x0A, .safe_to_modify  ; Jump if target < start
    
    LD R10
    CLC  
    SUB R12
    JCN 0x02, .protected_region ; Jump if target > end
    
.safe_to_modify:
    ; Perform self-modification
    JIN R14R15      ; Jump indirect to modification routine
    BBL 0
    
.protected_region:
    ; Skip modification - would corrupt SMC logic
    BBL 1           ; Return error flag

;═════════════════════════════════════════════════════════════
; NEURAL SPLINE CONTROL POINT BOUNDS
;═════════════════════════════════════════════════════════════
; 468 control points must map correctly to weight space

spline_bound_check:
    ; Ensures control points stay within valid B-spline domain
    ; Geometry has limits, even in infinite dimensional space
    
    FIM R6R7, 0x01, 0xD4    ; 468 in BCD (0x1D4)
    
    ; Load current control point index
    LD R12
    XCH R8
    LD R13
    XCH R9
    
    ; Check upper bound
    LD R7
    CLC
    SUB R9
    JCN 0x0A, .check_lower  ; Jump if no borrow
    
    ; Beyond upper bound - wrap using modulo
    LD R9
    CLC
    SUB R7
    XCH R9          ; New index = index - 468
    JUN .bounds_ok
    
.check_lower:
    ; Check if negative (high bit set)
    LD R8
    LDM 0x08
    CLC
    SUB R8
    JCN 0x02, .bounds_ok
    
    ; Below zero - wrap to upper
    LD R6
    ADD R8
    XCH R8
    LD R7
    ADD R9
    XCH R9
    
.bounds_ok:
    BBL 0

;═════════════════════════════════════════════════════════════
; CONVERGENCE DETECTION EDGE CASES
;═════════════════════════════════════════════════════════════
; Oscillation around solution vs true convergence

detect_oscillation:
    ; Detects when training oscillates instead of converging
    ; The universe doesn't oscillate - it spirals
    
    DATA_SEGMENT
    oscillation_buffer: resb 8  ; Last 8 error values
    buffer_ptr: resb 1
    
    CODE_SEGMENT
    ; Store current error in circular buffer
    LD R4           ; Current error (low)
    FIM R2R3, oscillation_buffer
    LD buffer_ptr
    ADD R2          ; Calculate buffer position
    XCH R2
    
    SRC R2R3
    LD R4
    WRM             ; Write to RAM
    
    ; Check for pattern (A-B-A-B oscillation)
    FIM R12, 4      ; Check last 4 values
    CLB             ; Clear pattern flag
    
.pattern_check:
    RDM             ; Read buffer[i]
    XCH R8
    INC R2
    RDM             ; Read buffer[i+1]
    CLC
    SUB R8          ; Compare adjacent values
    JCN 0x04, .different
    
    ; Same values - not oscillating
    BBL 0
    
.different:
    ISZ R12, .pattern_check
    
    ; Pattern detected - force discrete step
    BBL 1           ; Return oscillation flag

;═════════════════════════════════════════════════════════════
; MEMORY CORRUPTION DETECTION
;═════════════════════════════════════════════════════════════
; The shadows reveal what light cannot see

memory_checksum:
    ; Verifies critical memory regions haven't been corrupted
    ; Truth is the sum of its parts
    
    FIM R0R1, 0x00, 0x00    ; Start address
    FIM R2R3, 0x4F, 0x0F    ; End address (80 bytes RAM)
    CLB                     ; Clear checksum
    XCH R4
    
.checksum_loop:
    SRC R0R1
    RDM             ; Read memory
    ADD R4          ; Add to checksum
    XCH R4
    
    ; Increment address
    LD R1
    IAC
    XCH R1
    JCN 0x02, .no_carry
    LD R0
    IAC
    XCH R0
    
.no_carry:
    ; Check if done
    LD R0
    CLC
    SUB R2
    JCN 0x0C, .checksum_loop  ; Continue if not equal
    
    ; Verify checksum
    LD R4
    XCH R5          ; Save computed checksum
    
    ; Load expected checksum from ROM
    FIM R14R15, 0x3FF, 0x0F  ; Checksum location in ROM
    JIN R14R15
    RDR             ; Read expected checksum
    
    CLC
    SUB R5          ; Compare
    JCN 0x04, .corruption_detected
    
    BBL 0           ; Memory intact
    
.corruption_detected:
    BBL 1           ; Return corruption flag

;═════════════════════════════════════════════════════════════
; STACK OVERFLOW PROTECTION
;═════════════════════════════════════════════════════════════
; The 4004 has 3-level stack. We must never exceed it.

stack_guard:
    ; Prevents stack overflow in recursive operations
    ; Recursion has limits, even in infinite regression
    
    LD stack_ptr
    CLC
    LDM 0x03        ; Maximum stack depth
    SUB stack_ptr
    JCN 0x0A, .stack_safe  ; Jump if stack < max
    
    ; Stack would overflow - abort operation
    BBL 1           ; Return error
    
.stack_safe:
    ; Safe to push
    LD stack_ptr
    IAC
    XCH stack_ptr
    BBL 0

;═════════════════════════════════════════════════════════════
; NIBBLE ALIGNMENT VERIFICATION
;═════════════════════════════════════════════════════════════
; 4 bits must align with the universe's quantum

verify_alignment:
    ; Ensures all operations maintain 4-bit alignment
    ; Misalignment is chaos, alignment is intelligence
    
    LD R0           ; Check register pair alignment
    LDM 0x0F
    CLC
    SUB R0
    JCN 0x04, .misaligned
    
    LD R1
    LDM 0x0F
    CLC
    SUB R1
    JCN 0x04, .misaligned
    
    BBL 0           ; Aligned
    
.misaligned:
    ; Force alignment by masking
    LD R0
    LDM 0x0F
    CLB
    SUB R0
    XCH R0
    
    LD R1
    LDM 0x0F
    CLB
    SUB R1
    XCH R1
    
    BBL 1           ; Return realignment flag

;═════════════════════════════════════════════════════════════
; The Philosophy of Edge Cases
;═════════════════════════════════════════════════════════════
; Edge cases aren't errors - they're where intelligence emerges.
; The boundary between order and chaos is where patterns form.
; When the system approaches its limits, it reveals its nature.
;
; These handlers don't prevent edge cases - they embrace them.
; Because intelligence isn't avoiding boundaries, it's dancing
; on them with 4-bit precision.
;
; "The universe computes at its edges" - The 4004 knows this.
