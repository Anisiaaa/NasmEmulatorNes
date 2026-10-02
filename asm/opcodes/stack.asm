; NES Emulator - 6502 Stack Opcodes (FINAL)
extern set_zn_flags
extern sp_pointer
extern read_memory_byte
extern write_memory_byte

section .text
    bits 64

global pha_instr
pha_instr:
    push rbx
    mov r12, [rel sp_pointer]
    movzx ebx, byte [r12]
    mov r11, rbx
    add r11, 0x100            ; Force Stack Page 1
    mov bl, [rdx]             ; A value
    mov r12b, bl
    call write_memory_byte    ; Trigger PPU/APU via callback
    mov r12, [rel sp_pointer]
    dec byte [r12]
    mov eax, 3
    pop rbx
    ret

global php_instr
php_instr:
    push rbx
    mov r12, [rel sp_pointer]
    movzx ebx, byte [r12]
    mov r11, rbx
    add r11, 0x100
    mov bl, [rcx]             ; P value
    or bl, 0x30
    mov r12b, bl
    call write_memory_byte
    mov r12, [rel sp_pointer]
    dec byte [r12]
    mov eax, 3
    pop rbx
    ret

global pla_instr
pla_instr:
    mov r12, [rel sp_pointer]
    inc byte [r12]
    movzx r11, byte [r12]
    add r11, 0x100
    call read_memory_byte
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    mov eax, 4
    ret

global plp_instr
plp_instr:
    mov r12, [rel sp_pointer]
    inc byte [r12]
    movzx r11, byte [r12]
    add r11, 0x100
    call read_memory_byte
    and al, 0xEF
    or al, 0x20
    mov [rcx], al
    mov eax, 4
    ret

global jsr_absolute
jsr_absolute:
    push rbx
    push r12
    push r13
    
    ; 1. Read low byte of target address
    mov rbx, [rsi]       ; rsi points to PC
    mov r11w, bx
    call read_memory_byte
    mov r12b, al         ; r12b = target low byte
    
    ; 2. Read high byte of target address
    inc bx               ; bx is now PC + 1 (the address of the high byte)
    mov r11w, bx
    call read_memory_byte
    mov r13b, al         ; r13b = target high byte
    
    ; 3. Push Return Address (High Byte) to Stack
    mov r14, [rel sp_pointer]
    movzx eax, byte [r14]
    mov r11, rax
    add r11, 0x100
    
    push r12             ; Save target low byte temporarily
    mov r12w, bx         ; <- FIX: Copy full 16-bit advanced PC
    shr r12w, 8          ; <- FIX: Shift right 8 bits to safely isolate the high byte in r12b
    call write_memory_byte
    pop r12              ; Restore target low byte
    
    dec byte [r14]       ; Decrement Stack Pointer
    
    ; 4. Push Return Address (Low Byte) to Stack
    movzx eax, byte [r14]
    mov r11, rax
    add r11, 0x100
    
    push r12
    mov r12b, bl         ; bl is a low-byte register, completely legal with REX!
    call write_memory_byte
    pop r12
    
    dec byte [r14]       ; Decrement Stack Pointer
    
    ; 5. Update PC to new target address
    shl r13w, 8          ; Shift high byte up
    mov r13b, r12b       ; Combine with low byte in r13w
    mov word [rsi], r13w ; Write new 16-bit address to PC
    
    pop r13
    pop r12
    pop rbx
    mov eax, 6           ; Return 6 cycles
    ret


global rts_instr
rts_instr:
    push rbx
    push r12
    push r13
    
    ; 1. Pull Low Byte of PC
    mov r14, [rel sp_pointer]
    inc byte [r14]
    movzx r11, byte [r14]
    add r11, 0x100
    call read_memory_byte
    mov r12b, al         ; r12b = PC low
    
    ; 2. Pull High Byte of PC
    inc byte [r14]
    movzx r11, byte [r14]
    add r11, 0x100
    call read_memory_byte
    mov r13b, al         ; r13b = PC high
    
    ; 3. Combine and Add 1
    shl r13w, 8          ; Shift high byte up
    mov r13b, r12b       ; Combine with low byte
    inc r13w             ; RTS pulls PC-1, so we must add 1
    
    ; 4. Update PC
    mov word [rsi], r13w
    
    pop r13
    pop r12
    pop rbx
    mov eax, 6           ; RTS takes 6 cycles
    ret
section .note.GNU-stack