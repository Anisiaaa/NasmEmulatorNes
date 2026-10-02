

; External function from flags.asm
extern set_zn_flags
; External functions from cpu.asm for memory bus callbacks
extern read_memory_byte
extern write_memory_byte

bits 64
section .text

; LDA - Load Accumulator

; LDA Immediate ($A9) - 2 cycles
global lda_immediate
lda_immediate:
    push rbx
    
    ; Get PC value
    movzx r11, word [rsi]
    
    ; Read operand from memory[PC] via callback
    call read_memory_byte       ; address in r11, result in al
    
    ; Store in A
    mov [rdx], al
    
    ; Increment PC
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Set Z and N flags
    mov rdi, rcx        ; rdi = P ptr for set_zn_flags
    call set_zn_flags
    
    pop rbx
    mov eax, 2          ; 2 cycles
    ret

; LDA Zeropage ($A5) - 3 cycles
global lda_zeropage
lda_zeropage:
    push rbx
    
    ; Get PC value
    movzx r11, word [rsi]
    
    ; Read address from memory[PC] (zeropage, so only low byte) via callback
    call read_memory_byte       ; address in r11, result in al
    
    ; Increment PC
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Save address in r11 for second read
    movzx r11, al
    
    ; Read value from zeropage address via callback
    call read_memory_byte       ; address in r11, result in al
    
    ; Store in A
    mov [rdx], al
    
    ; Set Z and N flags
    mov rdi, rcx
    call set_zn_flags
    
    pop rbx
    mov eax, 3          ; 3 cycles
    ret

; LDA Absolute ($AD) - 4 cycles
global lda_absolute
lda_absolute:
    push rbx
    push r12
    
    ; Get PC value and read low byte of address via callback
    movzx r11, word [rsi]
    call read_memory_byte       ; address in r11, result in al
    movzx r12, al               ; save low byte
    
    ; Increment PC and read high byte
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    movzx r11, bx
    call read_memory_byte       ; address in r11, result in al
    
    ; Combine to form 16-bit address
    movzx rax, al
    shl rax, 8
    or rax, r12                 ; rax = full 16-bit address
    
    ; Increment PC by 1 more (total +2)
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Read value from absolute address via callback
    mov r11, rax
    call read_memory_byte       ; address in r11, result in al
    
    ; Store in A
    mov [rdx], al
    
    ; Set Z and N flags
    mov rdi, rcx
    call set_zn_flags
    
    pop r12
    pop rbx
    mov eax, 4          ; 4 cycles
    ret

; LDX - Load X Register

; LDX Immediate ($A2) - 2 cycles
; X pointer is in r8
global ldx_immediate
ldx_immediate:
    push rbx
    
    ; Get PC value
    movzx r11, word [rsi]
    
    ; Read operand from memory[PC] via callback
    call read_memory_byte       ; address in r11, result in al
    
    ; Store in X (r8 = X pointer)
    mov [r8], al
    
    ; Increment PC
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Set Z and N flags
    mov rdi, rcx
    call set_zn_flags
    
    pop rbx
    mov eax, 2          ; 2 cycles
    ret

; LDX Zeropage ($A6) - 3 cycles
global ldx_zeropage
ldx_zeropage:
    push rbx
    
    ; Get PC value
    movzx r11, word [rsi]
    
    ; Read address from memory[PC] via callback
    call read_memory_byte       ; address in r11, result in al
    
    ; Increment PC
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Save address in r11 for second read
    movzx r11, al
    
    ; Read value from zeropage address via callback
    call read_memory_byte       ; address in r11, result in al
    
    ; Store in X (r8 = X pointer)
    mov [r8], al
    
    ; Set Z and N flags
    mov rdi, rcx
    call set_zn_flags
    
    pop rbx
    mov eax, 3          ; 3 cycles
    ret

; LDX Absolute ($AE) - 4 cycles
global ldx_absolute
ldx_absolute:
    push rbx
    push r12
    
    ; Get PC value and read low byte of address via callback
    movzx r11, word [rsi]
    call read_memory_byte       ; address in r11, result in al
    movzx r12, al               ; save low byte
    
    ; Increment PC and read high byte
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    movzx r11, bx
    call read_memory_byte       ; address in r11, result in al
    
    ; Combine to form 16-bit address
    movzx rax, al
    shl rax, 8
    or rax, r12                 ; rax = full 16-bit address
    
    ; Increment PC by 1 more (total +2)
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Read value from absolute address via callback
    mov r11, rax
    call read_memory_byte       ; address in r11, result in al
    
    ; Store in X (r8 = X pointer)
    mov [r8], al
    
    ; Set Z and N flags
    mov rdi, rcx
    call set_zn_flags
    
    pop r12
    pop rbx
    mov eax, 4          ; 4 cycles
    ret

; LDY - Load Y Register

; LDY Immediate ($A0) - 2 cycles
; Y pointer is in r9
global ldy_immediate
ldy_immediate:
    push rbx
    
    ; Get PC value
    movzx r11, word [rsi]
    
    ; Read operand from memory[PC] via callback
    call read_memory_byte       ; address in r11, result in al
    
    ; Store in Y (r9 = Y pointer)
    mov [r9], al
    
    ; Increment PC
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Set Z and N flags
    mov rdi, rcx
    call set_zn_flags
    
    pop rbx
    mov eax, 2          ; 2 cycles
    ret

; LDY Zeropage ($A4) - 3 cycles
global ldy_zeropage
ldy_zeropage:
    push rbx
    
    ; Get PC value
    movzx r11, word [rsi]
    
    ; Read address from memory[PC] via callback
    call read_memory_byte       ; address in r11, result in al
    
    ; Increment PC
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Save address in r11 for second read
    movzx r11, al
    
    ; Read value from zeropage address via callback
    call read_memory_byte       ; address in r11, result in al
    
    ; Store in Y (r9 = Y pointer)
    mov [r9], al
    
    ; Set Z and N flags
    mov rdi, rcx
    call set_zn_flags
    
    pop rbx
    mov eax, 3          ; 3 cycles
    ret

; LDY Absolute ($AC) - 4 cycles
global ldy_absolute
ldy_absolute:
    push rbx
    push r12
    
    ; Get PC value and read low byte of address via callback
    movzx r11, word [rsi]
    call read_memory_byte       ; address in r11, result in al
    movzx r12, al               ; save low byte
    
    ; Increment PC and read high byte
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    movzx r11, bx
    call read_memory_byte       ; address in r11, result in al
    
    ; Combine to form 16-bit address
    movzx rax, al
    shl rax, 8
    or rax, r12                 ; rax = full 16-bit address
    
    ; Increment PC by 1 more (total +2)
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Read value from absolute address via callback
    mov r11, rax
    call read_memory_byte       ; address in r11, result in al
    
    ; Store in Y (r9 = Y pointer)
    mov [r9], al
    
    ; Set Z and N flags
    mov rdi, rcx
    call set_zn_flags
    
    pop r12
    pop rbx
    mov eax, 4          ; 4 cycles
    ret

; STA - Store Accumulator

; STA Zeropage ($85) - 3 cycles
global sta_zeropage
sta_zeropage:
    push rbx
    push r12
    
    ; Get PC value
    movzx rbx, word [rsi]
    
    ; Read target address from memory[PC]
    movzx r11, byte [rdi+rbx]   ; r11w = Address
    
    ; Increment PC
    inc bx
    mov word [rsi], bx
    
    ; Get value from A (rdx = A pointer)
    mov r12b, [rdx]             ; r12b = Value
    
    ; Write to Memory Bus
    call write_memory_byte
    
    pop r12
    pop rbx
    mov eax, 3          ; 3 cycles
    ret

; STA Absolute ($8D) - 4 cycles
global sta_absolute
sta_absolute:
    push rbx
    push r12
    push r13
    
    ; Get PC value
    movzx rbx, word [rsi]
    
    ; Read low byte of target address
    movzx r11, byte [rdi+rbx]
    inc bx
    
    ; Read high byte of target address
    movzx r13, byte [rdi+rbx]
    shl r13, 8
    or r11, r13         ; r11 = full 16-bit target address
    
    ; Increment PC by 2
    inc bx
    mov word [rsi], bx
    
    ; Get value from A
    mov r12b, [rdx]     ; r12b = Value
    
    ; Write to Memory Bus
    call write_memory_byte
    
    pop r13
    pop r12
    pop rbx
    mov eax, 4          ; 4 cycles
    ret

; STX - Store X Register

; STX Zeropage ($86) - 3 cycles
global stx_zeropage
stx_zeropage:
    push rbx
    push r12
    
    ; Get PC value
    movzx rbx, word [rsi]
    
    ; Read target address from memory[PC]
    movzx r11, byte [rdi+rbx]
    
    ; Increment PC
    inc bx
    mov word [rsi], bx
    
    ; Store X at zeropage address (X is in r8)
    mov r12b, [r8]
    call write_memory_byte
    
    pop r12
    pop rbx
    mov eax, 3          ; 3 cycles
    ret

; STX Absolute ($8E) - 4 cycles
global stx_absolute
stx_absolute:
    push rbx
    push r12
    push r13
    
    ; Get PC value
    movzx rbx, word [rsi]
    
    ; Read low byte of target address
    movzx r11, byte [rdi+rbx]
    inc bx
    
    ; Read high byte of target address
    movzx r13, byte [rdi+rbx]
    shl r13, 8
    or r11, r13
    
    ; Increment PC by 2
    inc bx
    mov word [rsi], bx
    
    ; Store X at absolute address
    mov r12b, [r8]
    call write_memory_byte
    
    pop r13
    pop r12
    pop rbx
    mov eax, 4          ; 4 cycles
    ret

; STY - Store Y Register

; STY Zeropage ($84) - 3 cycles
global sty_zeropage
sty_zeropage:
    push rbx
    push r12
    
    ; Get PC value
    movzx rbx, word [rsi]
    
    ; Read target address from memory[PC]
    movzx r11, byte [rdi+rbx]
    
    ; Increment PC
    inc bx
    mov word [rsi], bx
    
    ; Store Y at zeropage address (Y is in r9)
    mov r12b, [r9]
    call write_memory_byte
    
    pop r12
    pop rbx
    mov eax, 3          ; 3 cycles
    ret

; STY Absolute ($8C) - 4 cycles
global sty_absolute
sty_absolute:
    push rbx
    push r12
    push r13
    
    ; Get PC value
    movzx rbx, word [rsi]
    
    ; Read low byte of target address
    movzx r11, byte [rdi+rbx]
    inc bx
    
    ; Read high byte of target address
    movzx r13, byte [rdi+rbx]
    shl r13, 8
    or r11, r13
    
    ; Increment PC by 2
    inc bx
    mov word [rsi], bx
    
    ; Store Y at absolute address
    mov r12b, [r9]
    call write_memory_byte
    
    pop r13
    pop r12
    pop rbx
    mov eax, 4          ; 4 cycles
    ret

; Additional LDA / LDX / LDY / STA / STX / STY addressing modes
; Generated for cpu-complete-opcodes task 2
%include "addr_modes.inc"

; LDA - additional addressing modes

; LDA Zeropage,X ($B5) - 4 cycles
global lda_zeropage_x
lda_zeropage_x:
    push rbx
    push r12

    mov r12, rdi                ; save memory pointer (rdi clobbered by set_zn_flags)
    ADDR_ZEROPAGE_X             ; rbx = (base + X) & 0xFF; PC advanced
    mov r11, rbx                ; r11 = effective address
    call read_memory_byte       ; al = memory[effective address] via callback
    mov [rdx], al               ; store in A
    mov rdi, rcx                ; rdi = P pointer for set_zn_flags
    call set_zn_flags

    pop r12
    pop rbx
    mov eax, 4
    ret

; LDA Absolute,X ($BD) - 4+1 cycles (page-cross penalty)
global lda_absolute_x
lda_absolute_x:
    push rbx
    push r12
    push r13

    mov r12, rdi                ; save memory pointer
    ADDR_ABSOLUTE_X             ; rbx = effective addr; r13d = page-crossed flag
    mov r11, rbx                ; r11 = effective address
    call read_memory_byte       ; al = memory[effective address] via callback
    mov [rdx], al               ; store in A
    mov rdi, rcx
    call set_zn_flags

    mov eax, 4
    add eax, r13d               ; +1 if page crossed
    pop r13
    pop r12
    pop rbx
    ret

; LDA Absolute,Y ($B9) - 4+1 cycles (page-cross penalty)
global lda_absolute_y
lda_absolute_y:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ABSOLUTE_Y             ; rbx = effective addr; r13d = page-crossed flag
    mov r11, rbx                ; r11 = effective address
    call read_memory_byte       ; al = memory[effective address] via callback
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags

    mov eax, 4
    add eax, r13d
    pop r13
    pop r12
    pop rbx
    ret

; LDA (Indirect,X) ($A1) - 6 cycles
global lda_indirect_x
lda_indirect_x:
    push rbx
    push r12

    mov r12, rdi
    ADDR_INDIRECT_X             ; rbx = effective address
    mov r11, rbx                ; r11 = effective address
    call read_memory_byte       ; al = memory[effective address] via callback
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags

    pop r12
    pop rbx
    mov eax, 6
    ret

; LDA (Indirect),Y ($B1) - 5+1 cycles (page-cross penalty)
global lda_indirect_y
lda_indirect_y:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_INDIRECT_Y             ; rbx = effective addr; r13d = page-crossed flag
    mov r11, rbx                ; r11 = effective address
    call read_memory_byte       ; al = memory[effective address] via callback
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags

    mov eax, 5
    add eax, r13d
    pop r13
    pop r12
    pop rbx
    ret

; LDX - additional addressing modes

; LDX Zeropage,Y ($B6) - 4 cycles
global ldx_zeropage_y
ldx_zeropage_y:
    push rbx
    push r12

    mov r12, rdi
    ADDR_ZEROPAGE_Y             ; rbx = (base + Y) & 0xFF
    mov r11, rbx                ; r11 = effective address
    call read_memory_byte       ; al = memory[effective address] via callback
    mov [r8], al                ; store in X
    mov rdi, rcx
    call set_zn_flags

    pop r12
    pop rbx
    mov eax, 4
    ret

; LDX Absolute,Y ($BE) - 4+1 cycles (page-cross penalty)
global ldx_absolute_y
ldx_absolute_y:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ABSOLUTE_Y             ; rbx = effective addr; r13d = page-crossed flag
    mov r11, rbx                ; r11 = effective address
    call read_memory_byte       ; al = memory[effective address] via callback
    mov [r8], al                ; store in X
    mov rdi, rcx
    call set_zn_flags

    mov eax, 4
    add eax, r13d
    pop r13
    pop r12
    pop rbx
    ret

; LDY - additional addressing modes

; LDY Zeropage,X ($B4) - 4 cycles
global ldy_zeropage_x
ldy_zeropage_x:
    push rbx
    push r12

    mov r12, rdi
    ADDR_ZEROPAGE_X             ; rbx = (base + X) & 0xFF
    mov r11, rbx                ; r11 = effective address
    call read_memory_byte       ; al = memory[effective address] via callback
    mov [r9], al                ; store in Y
    mov rdi, rcx
    call set_zn_flags

    pop r12
    pop rbx
    mov eax, 4
    ret

; LDY Absolute,X ($BC) - 4+1 cycles (page-cross penalty)
global ldy_absolute_x
ldy_absolute_x:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ABSOLUTE_X             ; rbx = effective addr; r13d = page-crossed flag
    mov r11, rbx                ; r11 = effective address
    call read_memory_byte       ; al = memory[effective address] via callback
    mov [r9], al                ; store in Y
    mov rdi, rcx
    call set_zn_flags

    mov eax, 4
    add eax, r13d
    pop r13
    pop r12
    pop rbx
    ret

; STA - additional addressing modes

; STA Zeropage,X ($95) - 4 cycles
global sta_zeropage_x
sta_zeropage_x:
    push rbx
    push r12                  ; Must push r12 because we use it for the value

    ADDR_ZEROPAGE_X             ; rbx = (base + X) & 0xFF
    mov r11w, bx                ; address in r11
    mov r12b, [rdx]             ; value in r12b (A is in rdx)
    call write_memory_byte

    pop r12
    pop rbx
    mov eax, 4
    ret

; STA Absolute,X ($9D) - 5 cycles (NO page penalty — write)
global sta_absolute_x
sta_absolute_x:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ABSOLUTE_X             ; rbx = effective addr
    mov r11w, bx
    mov r12b, [rdx]
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 5
    ret

; STA Absolute,Y ($99) - 5 cycles (NO page penalty — write)
global sta_absolute_y
sta_absolute_y:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ABSOLUTE_Y             ; rbx = effective addr
    mov r11w, bx
    mov r12b, [rdx]
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 5
    ret

; STA (Indirect,X) ($81) - 6 cycles
global sta_indirect_x
sta_indirect_x:
    push rbx
    push r12                    ; Added push

    ADDR_INDIRECT_X             ; rbx = effective address
    mov r11w, bx
    mov r12b, [rdx]
    call write_memory_byte

    pop r12                     ; Added pop
    pop rbx
    mov eax, 6
    ret

; STA (Indirect),Y ($91) - 6 cycles (NO page penalty — write)
global sta_indirect_y
sta_indirect_y:
    push rbx
    push r12                    ; Added push
    push r13

    ADDR_INDIRECT_Y             ; rbx = effective addr
    mov r11w, bx
    mov r12b, [rdx]
    call write_memory_byte

    pop r13
    pop r12                     ; Added pop
    pop rbx
    mov eax, 6
    ret

; STX - additional addressing modes

; STX Zeropage,Y ($96) - 4 cycles
global stx_zeropage_y
stx_zeropage_y:
    push rbx
    push r12                    ; Added push

    ADDR_ZEROPAGE_Y             ; rbx = (base + Y) & 0xFF
    mov r11w, bx
    mov r12b, [r8]              ; X is in r8
    call write_memory_byte

    pop r12                     ; Added pop
    pop rbx
    mov eax, 4
    ret

; STY - additional addressing modes

; STY Zeropage,X ($94) - 4 cycles
global sty_zeropage_x
sty_zeropage_x:
    push rbx
    push r12                    ; Added push

    ADDR_ZEROPAGE_X             ; rbx = (base + X) & 0xFF
    mov r11w, bx
    mov r12b, [r9]              ; Y is in r9
    call write_memory_byte

    pop r12                     ; Added pop
    pop rbx
    mov eax, 4
    ret

section .note.GNU-stack noalloc noexec nowrite progbits