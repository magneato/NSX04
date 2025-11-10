;---------------------------------------------------------
;  DUCKER.ASM — Intel 4004 Emulator for 8086
;---------------------------------------------------------
;
; "Cookie Monster say: Run old CPU inside old CPU inside new CPU!
;  Is like nesting doll of CONSCIOUSNESS! Nom nom nom!"
;
; Emulates Intel 4004 (1971) on 8086 (1978)
;
; Usage: DUCKER.COM [rom_file.ROM]
;        (Defaults to INFR4004.ROM if no arg given)
;
; "Consciousness needs no cathedral. This CPU needs no transistors."
;---------------------------------------------------------
BITS 16
ORG 0x100
section .text
start:
    ; Print banner
    mov     dx, banner
    mov     ah, 0x09
    int     0x21
    ; Parse command line for ROM name
    call    parse_command_tail
    ; Load ROM into emulated 4004 ROM
    call    load_rom
    ; Initialize 4004 state
    call    init_4004
    ; Execute until halt
    call    execute_4004
    ; Print halt message
    mov     dx, halt_msg
    mov     ah, 0x09
    int     0x21
    ; Exit to DOS
    mov     ax, 0x4C00
    int     0x21
;---------------------------------------------------------
;  4004 STATE (Emulated in 8086 Memory)
;---------------------------------------------------------
section .bss
; 4004 Registers (16 × 4-bit registers, stored as bytes)
regs:           resb 16         ; R0-R15 (only lower nibble used)
; 4004 Accumulator & Carry
acc:            resb 1          ; Accumulator (4 bits)
carry:          resb 1          ; Carry flag (1 bit)
; 4004 Program Counter (12 bits, stored as word)
pc:             resw 1          ; Program counter (0x000-0xFFF)
; 4004 Stack (3-level, 12-bit addresses)
stack:          resw 3          ; 3-level call stack
stack_ptr:      resb 1          ; Stack pointer (0-2)
; 4004 ROM (4KB = 4096 bytes)
rom:            resb 4096       ; Program memory
; 4004 RAM (1024 bytes for 8 banks)
ram:            resb 1024       ; Data memory
; RAM address selection
ram_addr:       resb 1          ; 8-bit RAM address (Reg + Char)
ram_bank:       resb 1          ; 3-bit RAM bank (0-7)
; Instruction decode helpers
opcode:         resb 1          ; Current opcode
operand:        resb 1          ; Current operand
; Execution control
halted:         resb 1          ; Halt flag
section .data
banner:         db 'DUCKER v1.0 — Intel 4004 Emulator for 8086', 13, 10
                db 'Loading ROM: $'
rom_filename:   db 'INFR4004.ROM', 0  ; Default ROM
filename_end:   db '$'
loaded_msg:     db 13, 10, 'ROM loaded. Executing neural logic on 4004!', 13, 10, '$'
halt_msg:       db 13, 10, 'Inference complete. NAND output: $'
error_msg:      db 13, 10, 'Error: ROM file not found!', 13, 10, '$'

;---------------------------------------------------------
;  COMMAND LINE PARSING
;---------------------------------------------------------
parse_command_tail:
    ; Check if a command tail is present (length at 0x80)
    mov     cl, [0x80]
    test    cl, cl
    jz      .use_default        ; No args, use default ROM
    ; Find start of filename (skip spaces)
    mov     si, 0x81
    mov     di, rom_filename
.skip_spaces:
    cmp     cl, 0
    je      .use_default        ; No non-space chars found
    mov     al, [si]
    cmp     al, ' '
    jne     .copy_loop          ; Found start of filename
    inc     si
    dec     cl
    jmp     .skip_spaces
.copy_loop:
    ; Copy filename until space, CR, or end
    cmp     cl, 0
    je      .done_copy
    mov     al, [si]
    cmp     al, ' '
    je      .done_copy
    cmp     al, 0x0D
    je      .done_copy
    stosb                   ; Copy byte [SI] to [DI]
    inc     si
    dec     cl
    jmp     .copy_loop
.done_copy:
    ; Null-terminate the new filename
    mov     byte [di], 0
    mov     byte [di+1], '$' ; For printing
.use_default:
    ; Print ROM name we are loading
    mov     dx, rom_filename
    mov     ah, 0x09
    int     0x21
    ret
;---------------------------------------------------------
;  ROM LOADING
;---------------------------------------------------------
load_rom:
    ; Open ROM file
    mov     dx, rom_filename
    mov     ax, 0x3D00          ; Open file, read-only
    int     0x21
    jc      .error
    mov     bx, ax              ; File handle in BX
    ; Read ROM into memory
    mov     dx, rom
    mov     cx, 4096            ; Read up to 4KB
    mov     ah, 0x3F
    int     0x21
    jc      .error_close
    ; Close file
    mov     ah, 0x3E
    int     0x21
    ; Print success
    mov     dx, loaded_msg
    mov     ah, 0x09
    int     0x21
    ret
.error_close:
    mov     ah, 0x3E
    int     0x21
.error:
    mov     dx, error_msg
    mov     ah, 0x09
    int     0x21
    mov     ax, 0x4C01
    int     0x21
;---------------------------------------------------------
;  4004 INITIALIZATION
;---------------------------------------------------------
init_4004:
    mov     di, regs
    mov     cx, 16
    xor     al, al
    rep     stosb
    mov     byte [acc], 0
    mov     byte [carry], 0
    mov     word [pc], 0
    mov     byte [stack_ptr], 0
    mov     di, ram
    mov     cx, 1024
    xor     al, al
    rep     stosb
    mov     byte [ram_addr], 0
    mov     byte [ram_bank], 0
    mov     byte [halted], 0
    ret
;---------------------------------------------------------
;  4004 EXECUTION ENGINE
;---------------------------------------------------------
execute_4004:
.exec_loop:
    cmp     byte [halted], 0
    jne     .done
    call    fetch_instruction
    call    decode_execute
    jmp     .exec_loop
.done:
    ret
;---------------------------------------------------------
;  INSTRUCTION FETCH
;---------------------------------------------------------
fetch_instruction:
    mov     bx, [pc]
    cmp     bx, 4096
    jae     .halt
    mov     al, [rom + bx]
    mov     [opcode], al
    inc     word [pc]
    and     word [pc], 0x0FFF
    ret
.halt:
    mov     byte [halted], 1
    ret
;---------------------------------------------------------
;  INSTRUCTION DECODE & EXECUTE
;---------------------------------------------------------
decode_execute:
    mov     al, [opcode]
    mov     ah, al
    shr     ah, 4
    and     al, 0x0F
    mov     [operand], al
    ; Jump table based on high nibble
    cmp     ah, 0x00
    je      .op_00
    cmp     ah, 0x01
    je      .op_jcn
    cmp     ah, 0x02
    je      .op_2x
    cmp     ah, 0x03
    je      .op_3x
    cmp     ah, 0x04
    je      .op_jun
    cmp     ah, 0x05
    je      .op_jms
    cmp     ah, 0x06
    je      .op_inc
    cmp     ah, 0x07
    je      .op_isz           ; Added ISZ
    cmp     ah, 0x08
    je      .op_add
    cmp     ah, 0x09
    je      .op_sub
    cmp     ah, 0x0A
    je      .op_ld
    cmp     ah, 0x0B
    je      .op_xch
    cmp     ah, 0x0C
    je      .op_bbl
    cmp     ah, 0x0E
    je      .op_ex
    cmp     ah, 0x0F
    je      .op_fx
    ret
;---------------------------------------------------------
; JCN - Jump Conditional (0x1X ADDR)
;---------------------------------------------------------
.op_jcn:
    mov     al, [operand]
    mov     cl, 0
    ; C3 (bit 1) = Jump if CARRY == 1
    test    al, 0x02
    jz      .jcn_check_acc
    cmp     byte [carry], 1
    je      .jcn_condition_met
.jcn_check_acc:
    ; C2 (bit 2) = Jump if ACC == 0
    test    al, 0x04
    jz      .jcn_invert
    cmp     byte [acc], 0
    je      .jcn_condition_met
    jmp     .jcn_invert
.jcn_condition_met:
    mov     cl, 1
.jcn_invert:
    ; C1 (bit 3) = Invert jump
    test    al, 0x08
    jz      .jcn_do_jump
    xor     cl, 1
.jcn_do_jump:
    test    cl, cl
    jz      .jcn_no_jump
    call    fetch_instruction
    mov     al, [opcode]
    mov     bx, [pc]
    and     bx, 0x0F00
    xor     ah, ah
    or      bx, ax
    mov     [pc], bx
    ret
.jcn_no_jump:
    call    fetch_instruction
    ret
;---------------------------------------------------------
; FIM (0x2X DATA) / SRC (0x2X+1)
;---------------------------------------------------------
.op_2x:

    mov     al, [operand]
    test    al, 1
    jnz     .src
.fim:
    mov     al, [operand]
    shr     al, 1
    mov     bl, al
    shl     bl, 1
    call    fetch_instruction
    mov     al, [opcode]
    mov     ah, al
    shr     ah, 4
    and     ah, 0x0F
    xor     bh, bh
    mov     [regs + bx], ah
    and     al, 0x0F
    inc     bx
    mov     [regs + bx], al
    ret
.src:
    mov     al, [operand]
    shr     al, 1
    mov     bl, al
    shl     bl, 1
    xor     bh, bh
    mov     al, [regs + bx]
    shl     al, 4
    inc     bx
    or      al, [regs + bx]
    mov     [ram_addr], al
    ret
;---------------------------------------------------------
; FIN (0x3X) / JIN (0x3X+1)
;---------------------------------------------------------
.op_3x:
    mov     al, [operand]
    test    al, 1
    jnz     .jin
.fin:
    mov     bx, [pc]
    and     bx, 0x0F00
    mov     al, [regs + 0]
    shl     al, 4
    or      al, [regs + 1]
    xor     ah, ah
    add     bx, ax
    mov     al, [rom + bx]
    mov     cl, [operand]
    shr     cl, 1
    mov     bl, cl
    shl     bl, 1
    mov     ah, al
    shr     ah, 4
    xor     bh, bh
    mov     [regs + bx], ah
    inc     bx
    and     al, 0x0F
    mov     [regs + bx], al
    ret
.jin:
    mov     al, [operand]
    shr     al, 1
    mov     bl, al
    shl     bl, 1
    xor     bh, bh
    mov     al, [regs + bx]
    shl     al, 4
    inc     bx
    or      al, [regs + bx]
    mov     bx, [pc]
    and     bx, 0x0F00
    xor     ah, ah
    or      bx, ax
    mov     [pc], bx
    ret
;---------------------------------------------------------
; JUN (0x4X ADDR)
;---------------------------------------------------------
.op_jun:
    mov     al, [operand]
    mov     ah, al
    call    fetch_instruction
    mov     al, [opcode]
    shl     ah, 4
    xor     bh, bh
    mov     bl, al
    or      ax, bx
    and     ax, 0x0FFF
    mov     [pc], ax
    ret
;---------------------------------------------------------
; JMS (0x5X ADDR)
;---------------------------------------------------------
.op_jms:
    mov     al, [stack_ptr]
    cmp     al, 3
    jae     .stack_overflow
    mov     bl, al
    xor     bh, bh
    shl     bx, 1
    mov     ax, [pc]
    mov     [stack + bx], ax
    inc     byte [stack_ptr]
    jmp     .op_jun
.stack_overflow:
    mov     byte [halted], 1
    ret
;---------------------------------------------------------
; INC - Increment Register (0x6R)
;---------------------------------------------------------
.op_inc:
    mov     al, [operand]
    mov     bl, al
    xor     bh, bh
    mov     al, [regs + bx]
    inc     al
    and     al, 0x0F
    mov     [regs + bx], al
    ret
;---------------------------------------------------------
; ISZ - Increment and Skip if Zero (0x7R ADDR)
;---------------------------------------------------------
.op_isz:
    ; Increment register
    mov     al, [operand]
    mov     bl, al
    xor     bh, bh
    mov     al, [regs + bx]
    inc     al
    and     al, 0x0F
    mov     [regs + bx], al
    ; Fetch address byte
    call    fetch_instruction
    ; Test if result is zero
    test    al, al
    jnz     .isz_jump       ; If not zero, jump
    ; Is zero, skip
    ret
.isz_jump:
    ; Not zero, jump to 8-bit addr
    mov     al, [opcode]
    mov     bx, [pc]
    and     bx, 0x0F00
    xor     ah, ah
    or      bx, ax
    mov     [pc], bx
    ret
;---------------------------------------------------------
; ADD (0x8R) / SUB (0x9R)
;---------------------------------------------------------
.op_add:
    mov     al, [operand]
    mov     bl, al
    xor     bh, bh
    mov     al, [acc]
    add     al, [regs + bx]
    add     al, [carry]
    mov     byte [carry], 0
    cmp     al, 0x0F
    jbe     .op_add_nocarry
    mov     byte [carry], 1
.op_add_nocarry:
    and     al, 0x0F
    mov     [acc], al
    ret
.op_sub:
    mov     al, [operand]
    mov     bl, al
    xor     bh, bh
    mov     cl, [regs + bx]
    not     cl
    and     cl, 0x0F
    mov     al, [acc]
    add     al, cl
    add     al, [carry]
    mov     byte [carry], 0
    cmp     al, 0x0F
    jbe     .op_sub_noborrow
    mov     byte [carry], 1
.op_sub_noborrow:
    and     al, 0x0F
    mov     [acc], al
    ret
;---------------------------------------------------------
; LD (0xAR) / XCH (0xBR)
;---------------------------------------------------------
.op_ld:
    mov     al, [operand]
    mov     bl, al
    xor     bh, bh
    mov     al, [regs + bx]
    mov     [acc], al
    ret
.op_xch:
    mov     al, [operand]
    mov     bl, al
    xor     bh, bh
    mov     al, [acc]
    mov     ah, [regs + bx]
    mov     [acc], ah
    mov     [regs + bx], al
    ret
;---------------------------------------------------------
; BBL - Branch Back and Load (0xCX)
;---------------------------------------------------------
.op_bbl:
    mov     al, [stack_ptr]
    test    al, al
    jz      .stack_underflow
    dec     byte [stack_ptr]
    mov     al, [stack_ptr]
    mov     bl, al
    xor     bh, bh
    shl     bx, 1
    mov     ax, [stack + bx]
    mov     [pc], ax
    mov     al, [operand]
    mov     [acc], al
    ret
.stack_underflow:
    mov     byte [halted], 1
    ret
;---------------------------------------------------------
; RAM and IO Opcodes (0xEX)
;---------------------------------------------------------
.op_ex:
    mov     al, [operand]
    cmp     al, 0x00
    je      .wrm
    cmp     al, 0x09
    je      .rdm
    ret ; Others not implemented
.wrm:
    ; WRM: Write ACC to RAM
    ; Addr = (bank * 128) + (ram_addr / 2)
    mov     cl, [ram_bank]      ; Bank (0-7)
    xor     ch, ch
    mov     bx, 128
    mul     cl                  ; ax = bank * 128
    mov     bx, ax              ; bx = bank_offset
    mov     al, [ram_addr]
    shr     al, 1               ; ram_addr / 2 = byte offset
    xor     ah, ah
    add     bx, ax              ; bx = final byte address
    mov     cl, [acc]
    and     cl, 0x0F
    mov     al, [ram_addr]
    test    al, 1
    jz      .wrm_low
.wrm_high:
    shl     cl, 4
    mov     al, [ram + bx]
    and     al, 0x0F
    or      al, cl
    mov     [ram + bx], al
    ret
.wrm_low:
    mov     al, [ram + bx]
    and     al, 0xF0
    or      al, cl
    mov     [ram + bx], al
    ret
.rdm:
    ; RDM: Read RAM to ACC
    mov     cl, [ram_bank]
    xor     ch, ch
    mov     bx, 128
    mul     cl
    mov     bx, ax
    mov     al, [ram_addr]
    shr     al, 1
    xor     ah, ah
    add     bx, ax
    mov     al, [ram + bx]
    mov     cl, [ram_addr]
    test    cl, 1
    jz      .rdm_low
.rdm_high:
    shr     al, 4
    and     al, 0x0F
    mov     [acc], al
    ret
.rdm_low:
    and     al, 0x0F
    mov     [acc], al
    ret
;---------------------------------------------------------
; Accumulator Group Opcodes (0xFX)
;---------------------------------------------------------
.op_fx:
    mov     al, [operand]
    cmp     al, 0x00
    je      .clb
    cmp     al, 0x01
    je      .clc
    cmp     al, 0x02
    je      .iac
    cmp     al, 0x05
    je      .ral
    cmp     al, 0x06
    je      .rar
    cmp     al, 0x08
    je      .dac
    cmp     al, 0x0D
    je      .dcl
    ret ; Others not implemented
.clb:
    mov     byte [acc], 0
    mov     byte [carry], 0
    ret
.clc:
    mov     byte [carry], 0
    ret
.iac:
    mov     al, [acc]
    inc     al
    mov     byte [carry], 0
    cmp     al, 0x0F
    jbe     .iac_no_carry
    mov     byte [carry], 1
.iac_no_carry:
    and     al, 0x0F
    mov     [acc], al
    ret
.ral:
    mov     al, [acc]
    shl     al, 1
    or      al, [carry]
    mov     byte [carry], 0
    cmp     al, 0x0F
    jbe     .ral_no_carry
    mov     byte [carry], 1
.ral_no_carry:
    and     al, 0x0F
    mov     [acc], al
    ret
.rar:
    mov     al, [acc]
    mov     cl, [carry]
    shl     cl, 4
    mov     ah, al
    and     ah, 1
    shr     al, 1
    or      al, cl
    and     al, 0x0F
    mov     [acc], al
    mov     [carry], ah
    ret
.dac:
    mov     al, [acc]
    add     al, 0x0F
    mov     byte [carry], 0
    cmp     al, 0x0F
    jbe     .dac_no_carry
    mov     byte [carry], 1
.dac_no_carry:
    and     al, 0x0F
    mov     [acc], al
    ret
.dcl:
    mov     al, [acc]
    and     al, 0x07
    mov     [ram_bank], al
    ret
;---------------------------------------------------------
; NOP / HLT (0x00 / 0x0F)
;---------------------------------------------------------
.op_00:
    mov     al, [operand]
    cmp     al, 0x0F
    je      .hlt
.nop:
    ret
.hlt:
    mov     byte [halted], 1
    mov     dl, [acc]
    add     dl, '0'
    mov     ah, 0x02
    int     0x21
    ret

; What the Duck?
