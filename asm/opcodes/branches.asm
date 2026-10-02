
; External helper function
extern read_memory_byte

section .text
bits 64

; BEQ - Branch if Equal (Zero flag set)

; BEQ ($F0) - 2 cycles (3 if taken, +1 if page crossed)
global beq_instr
beq_instr:
    push rbx
    push r8
    
    ; Check if Zero flag is set
    mov al, [rcx]
    test al, 0x02                 ; Test Z flag
    jz .beq_not_taken
    
    ; Branch is taken - save old PC
    movzx rbx, word [rsi]
    mov r8w, bx                   ; Save oldPC in r8w
    
    ; Read offset using callback
    mov r11w, bx                  ; Address to read from
    call read_memory_byte         ; Returns byte in al
    movzx eax, al                 ; Zero-extend to eax
    
    inc bx                        ; Increment PC past offset
    
    ; Sign extend offset to 16 bits
    test al, 0x80                 ; Check if negative
    jz .beq_positive
    ; Negative offset - extend sign
    mov ah, 0xFF
    jmp .beq_extend_done
.beq_positive:
    mov ah, 0x00
.beq_extend_done:
    
    ; Add offset to PC (ax = signed offset)
    movsx eax, al                 ; Sign extend al to eax
    add bx, ax                    ; Add to PC (newPC)
    
    ; Check for page cross: (oldPC >> 8) != (newPC >> 8)
    mov eax, 3                    ; Base cycles = 3
    mov r8w, r8w                  ; oldPC high byte
    shr r8w, 8
    movzx edx, bx                 ; newPC
    shr edx, 8                    ; newPC high byte
    cmp r8w, dx
    je .beq_no_page_cross
    inc eax                       ; +1 cycle for page cross
.beq_no_page_cross:
    
    ; Store updated PC
    mov word [rsi], bx
    
    pop r8
    pop rbx
    ret
    
.beq_not_taken:
    ; Branch not taken - just skip offset byte
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    pop r8
    pop rbx
    mov eax, 2                    ; 2 cycles when not taken
    ret

; BNE - Branch if Not Equal (Zero flag clear)

; BNE ($D0) - 2 cycles (3 if taken, +1 if page crossed)
global bne_instr
bne_instr:
    push rbx
    push r8
    
    ; Check if Zero flag is clear
    mov al, [rcx]
    test al, 0x02                 ; Test Z flag
    jnz .bne_not_taken
    
    ; Branch is taken - save old PC
    movzx rbx, word [rsi]
    mov r8w, bx                   ; Save oldPC in r8w
    
    ; Read offset using callback
    mov r11w, bx                  ; Address to read from
    call read_memory_byte         ; Returns byte in al
    movzx eax, al                 ; Zero-extend to eax
    
    inc bx                        ; Increment PC past offset
    
    ; Sign extend and add offset to PC
    movsx eax, al                 ; Sign extend al to eax
    add bx, ax                    ; Add to PC (newPC)
    
    ; Check for page cross: (oldPC >> 8) != (newPC >> 8)
    mov eax, 3                    ; Base cycles = 3
    mov r8w, r8w                  ; oldPC high byte
    shr r8w, 8
    movzx edx, bx                 ; newPC
    shr edx, 8                    ; newPC high byte
    cmp r8w, dx
    je .bne_no_page_cross
    inc eax                       ; +1 cycle for page cross
.bne_no_page_cross:
    
    ; Store updated PC
    mov word [rsi], bx
    
    pop r8
    pop rbx
    ret
    
.bne_not_taken:
    ; Branch not taken
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    pop r8
    pop rbx
    mov eax, 2                    ; 2 cycles when not taken
    ret

; BPL - Branch if Positive (Negative flag clear)

; BPL ($10) - 2 cycles (3 if taken, +1 if page crossed)
global bpl_instr
bpl_instr:
    push rbx
    push r8
    
    ; Check if Negative flag is clear
    mov al, [rcx]
    test al, 0x80                 ; Test N flag
    jnz .bpl_not_taken
    
    ; Branch is taken - save old PC
    movzx rbx, word [rsi]
    mov r8w, bx                   ; Save oldPC
    
    ; Read offset using callback
    mov r11w, bx                  ; Address to read from
    call read_memory_byte         ; Returns byte in al
    movzx eax, al                 ; Zero-extend to eax
    
    inc bx
    movsx eax, al
    add bx, ax                    ; newPC
    
    ; Check for page cross: (oldPC >> 8) != (newPC >> 8)
    mov eax, 3                    ; Base cycles = 3
    shr r8w, 8                    ; oldPC high byte
    movzx edx, bx                 ; newPC
    shr edx, 8                    ; newPC high byte
    cmp r8w, dx
    je .bpl_no_page_cross
    inc eax                       ; +1 cycle for page cross
.bpl_no_page_cross:
    
    mov word [rsi], bx
    
    pop r8
    pop rbx
    ret
    
.bpl_not_taken:
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    pop r8
    pop rbx
    mov eax, 2
    ret

; BMI - Branch if Minus (Negative flag set)

; BMI ($30) - 2 cycles (3 if taken, +1 if page crossed)
global bmi_instr
bmi_instr:
    push rbx
    push r8
    
    ; Check if Negative flag is set
    mov al, [rcx]
    test al, 0x80                 ; Test N flag
    jz .bmi_not_taken
    
    ; Branch is taken - save old PC
    movzx rbx, word [rsi]
    mov r8w, bx                   ; Save oldPC
    
    ; Read offset using callback
    mov r11w, bx                  ; Address to read from
    call read_memory_byte         ; Returns byte in al
    movzx eax, al                 ; Zero-extend to eax
    
    inc bx
    movsx eax, al
    add bx, ax                    ; newPC
    
    ; Check for page cross: (oldPC >> 8) != (newPC >> 8)
    mov eax, 3                    ; Base cycles = 3
    shr r8w, 8                    ; oldPC high byte
    movzx edx, bx                 ; newPC
    shr edx, 8                    ; newPC high byte
    cmp r8w, dx
    je .bmi_no_page_cross
    inc eax                       ; +1 cycle for page cross
.bmi_no_page_cross:
    
    mov word [rsi], bx
    
    pop r8
    pop rbx
    ret
    
.bmi_not_taken:
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    pop r8
    pop rbx
    mov eax, 2
    ret

; BCS - Branch if Carry Set

; BCS ($B0) - 2 cycles (3 if taken, +1 if page crossed)
global bcs_instr
bcs_instr:
    push rbx
    push r8
    
    ; Check if Carry flag is set
    mov al, [rcx]
    test al, 0x01                 ; Test C flag
    jz .bcs_not_taken
    
    ; Branch is taken - save old PC
    movzx rbx, word [rsi]
    mov r8w, bx                   ; Save oldPC
    
    ; Read offset using callback
    mov r11w, bx                  ; Address to read from
    call read_memory_byte         ; Returns byte in al
    movzx eax, al                 ; Zero-extend to eax
    
    inc bx
    movsx eax, al
    add bx, ax                    ; newPC
    
    ; Check for page cross: (oldPC >> 8) != (newPC >> 8)
    mov eax, 3                    ; Base cycles = 3
    shr r8w, 8                    ; oldPC high byte
    movzx edx, bx                 ; newPC
    shr edx, 8                    ; newPC high byte
    cmp r8w, dx
    je .bcs_no_page_cross
    inc eax                       ; +1 cycle for page cross
.bcs_no_page_cross:
    
    mov word [rsi], bx
    
    pop r8
    pop rbx
    ret
    
.bcs_not_taken:
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    pop r8
    pop rbx
    mov eax, 2
    ret

; BCC - Branch if Carry Clear

; BCC ($90) - 2 cycles (3 if taken, +1 if page crossed)
global bcc_instr
bcc_instr:
    push rbx
    push r8
    
    ; Check if Carry flag is clear
    mov al, [rcx]
    test al, 0x01                 ; Test C flag
    jnz .bcc_not_taken
    
    ; Branch is taken - save old PC
    movzx rbx, word [rsi]
    mov r8w, bx                   ; Save oldPC
    
    ; Read offset using callback
    mov r11w, bx                  ; Address to read from
    call read_memory_byte         ; Returns byte in al
    movzx eax, al                 ; Zero-extend to eax
    
    inc bx
    movsx eax, al
    add bx, ax                    ; newPC
    
    ; Check for page cross: (oldPC >> 8) != (newPC >> 8)
    mov eax, 3                    ; Base cycles = 3
    shr r8w, 8                    ; oldPC high byte
    movzx edx, bx                 ; newPC
    shr edx, 8                    ; newPC high byte
    cmp r8w, dx
    je .bcc_no_page_cross
    inc eax                       ; +1 cycle for page cross
.bcc_no_page_cross:
    
    mov word [rsi], bx
    
    pop r8
    pop rbx
    ret
    
.bcc_not_taken:
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    pop r8
    pop rbx
    mov eax, 2
    ret

; BVC - Branch if Overflow Clear

; BVC ($50) - 2 cycles (3 if taken, +1 if page crossed)
global bvc_instr
bvc_instr:
    push rbx
    push r8
    
    ; Check if Overflow flag is clear
    mov al, [rcx]
    test al, 0x40                 ; Test V flag
    jnz .bvc_not_taken
    
    ; Branch is taken - save old PC
    movzx rbx, word [rsi]
    mov r8w, bx                   ; Save oldPC
    
    ; Read offset using callback
    mov r11w, bx                  ; Address to read from
    call read_memory_byte         ; Returns byte in al
    movzx eax, al                 ; Zero-extend to eax
    
    inc bx
    movsx eax, al
    add bx, ax                    ; newPC
    
    ; Check for page cross: (oldPC >> 8) != (newPC >> 8)
    mov eax, 3                    ; Base cycles = 3
    shr r8w, 8                    ; oldPC high byte
    movzx edx, bx                 ; newPC
    shr edx, 8                    ; newPC high byte
    cmp r8w, dx
    je .bvc_no_page_cross
    inc eax                       ; +1 cycle for page cross
.bvc_no_page_cross:
    
    mov word [rsi], bx
    
    pop r8
    pop rbx
    ret
    
.bvc_not_taken:
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    pop r8
    pop rbx
    mov eax, 2
    ret

; BVS - Branch if Overflow Set

; BVS ($70) - 2 cycles (3 if taken, +1 if page crossed)
global bvs_instr
bvs_instr:
    push rbx
    push r8
    
    ; Check if Overflow flag is set
    mov al, [rcx]
    test al, 0x40                 ; Test V flag
    jz .bvs_not_taken
    
    ; Branch is taken - save old PC
    movzx rbx, word [rsi]
    mov r8w, bx                   ; Save oldPC
    
    ; Read offset using callback
    mov r11w, bx                  ; Address to read from
    call read_memory_byte         ; Returns byte in al
    movzx eax, al                 ; Zero-extend to eax
    
    inc bx
    movsx eax, al
    add bx, ax                    ; newPC
    
    ; Check for page cross: (oldPC >> 8) != (newPC >> 8)
    mov eax, 3                    ; Base cycles = 3
    shr r8w, 8                    ; oldPC high byte
    movzx edx, bx                 ; newPC
    shr edx, 8                    ; newPC high byte
    cmp r8w, dx
    je .bvs_no_page_cross
    inc eax                       ; +1 cycle for page cross
.bvs_no_page_cross:
    
    mov word [rsi], bx
    
    pop r8
    pop rbx
    ret
    
.bvs_not_taken:
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    pop r8
    pop rbx
    mov eax, 2
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
