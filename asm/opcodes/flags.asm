; NES Emulator - 6502 Flag Operations
; Helper functions for setting/clearing flags and flag-related instructions

section .text
bits 64
; Flag Setting/Checking Helper Functions
; These are called by other opcode implementations

; set_negative_flag - Set N flag based on bit 7 of result
; Input: rdi = P pointer, al = result value
global set_negative_flag
set_negative_flag:
    test al, 0x80           ; Check bit 7
    jnz .set_neg
    and byte [rdi], 0x7F    ; Clear N flag (0x7F = ~0x80)
    ret
.set_neg:
    or byte [rdi], 0x80     ; Set N flag
    ret

; set_zero_flag - Set Z flag based on whether result is 0
; Input: rdi = P pointer, al = result value
global set_zero_flag
set_zero_flag:
    test al, al
    jnz .not_zero
    or byte [rdi], 0x02     ; Set Z flag
    ret
.not_zero:
    and byte [rdi], 0xFD    ; Clear Z flag (0xFD = ~0x02)
    ret

; set_zn_flags - Set both Z and N flags based on result
; Input: rdi = P pointer, al = result value
global set_zn_flags
set_zn_flags:
    push rdx
    movzx edx, al           ; Copy value to edx (zero extended)
    
    ; Set N flag based on bit 7
    test al, 0x80
    jnz .zn_set_neg
    and byte [rdi], 0x7F    ; Clear N flag
    jmp .zn_check_zero
.zn_set_neg:
    or byte [rdi], 0x80     ; Set N flag
    
.zn_check_zero:
    ; Set Z flag based on zero
    test edx, edx
    jnz .zn_not_zero
    or byte [rdi], 0x02     ; Set Z flag
    jmp .zn_done
.zn_not_zero:
    and byte [rdi], 0xFD    ; Clear Z flag
    
.zn_done:
    pop rdx
    ret

; set_carry_flag - Set or clear C flag
; Input: rdi = P pointer, sil = 0 to clear, non-zero to set
global set_carry_flag
set_carry_flag:
    test sil, sil
    jz .clear_carry
    or byte [rdi], 0x01     ; Set C flag
    ret
.clear_carry:
    and byte [rdi], 0xFE    ; Clear C flag (0xFE = ~0x01)
    ret

; set_overflow_flag - Set or clear V flag  
; Input: rdi = P pointer, sil = 0 to clear, non-zero to set
global set_overflow_flag
set_overflow_flag:
    test sil, sil
    jz .clear_overflow
    or byte [rdi], 0x40     ; Set V flag
    ret
.clear_overflow:
    and byte [rdi], 0xBF    ; Clear V flag (0xBF = ~0x40)
    ret

; get_carry_flag - Get carry flag value
; Input: rdi = P pointer
; Output: al = 0 or 1
global get_carry_flag
get_carry_flag:
    mov al, [rdi]
    and al, 0x01
    ret

; get_overflow_flag - Get overflow flag value
; Input: rdi = P pointer
; Output: al = 0 or 1
global get_overflow_flag
get_overflow_flag:
    mov al, [rdi]
    and al, 0x40
    shr al, 6
    ret

; Flag Instructions (CLC, SEC, CLI, SEI, CLV, CLD, SED)
; These modify the P register directly
; Parameters: rdi = P pointer
; Returns: cycles in eax

; CLC - Clear Carry Flag (opcode $18)
; Parameters: rdi=memory*, rsi=PC*, rdx=A*, rcx=P*, r8=X*, r9=Y*
global clc_instr
clc_instr:
    and byte [rcx], 0xFE    ; Clear C flag (flags in rcx!)
    mov eax, 2              ; 2 cycles
    ret

; SEC - Set Carry Flag (opcode $38)
global sec_instr
sec_instr:
    or byte [rcx], 0x01     ; Set C flag
    mov eax, 2              ; 2 cycles
    ret

; CLI - Clear Interrupt Disable (opcode $58)
global cli_instr
cli_instr:
    and byte [rcx], 0xFB    ; Clear I flag (0xFB = ~0x04)
    mov eax, 2              ; 2 cycles
    ret

; SEI - Set Interrupt Disable (opcode $78)
global sei_instr
sei_instr:
    or byte [rcx], 0x04     ; Set I flag
    mov eax, 2              ; 2 cycles
    ret

; CLV - Clear Overflow Flag (opcode $B8)
global clv_instr
clv_instr:
    and byte [rcx], 0xBF    ; Clear V flag
    mov eax, 2              ; 2 cycles
    ret

; CLD - Clear Decimal Flag (opcode $D8)
global cld_instr
cld_instr:
    and byte [rcx], 0xF7    ; Clear D flag (0xF7 = ~0x08)
    mov eax, 2              ; 2 cycles
    ret

; SED - Set Decimal Flag (opcode $F8)
global sed_instr
sed_instr:
    or byte [rcx], 0x08     ; Set D flag
    mov eax, 2              ; 2 cycles
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
