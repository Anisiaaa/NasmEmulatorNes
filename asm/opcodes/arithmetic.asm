; External functions from flags.asm
extern set_zn_flags
extern set_carry_flag
extern set_overflow_flag
extern get_carry_flag

; External function for memory read callback
extern read_memory_byte
extern write_memory_byte

section .text

; ADC - Add with Carry ($69 immediate) - 2 cycles
global adc_immediate
adc_immediate:
    push rbx
    push r12
    push r13
    push r14
    push r15
    
    mov r12, rdi        ; r12 = memory*
    mov r14, rdx        ; r14 = A*
    mov r15, rcx        ; r15 = P*
    
    movzx ebx, word [rsi]        ; ebx = PC (zero-extended to 32-bit)
    mov r11, rbx                  ; r11 = address for read_memory_byte
    call read_memory_byte         ; Read operand via callback
    movzx r13d, al                ; r13 = operand (zero-extended to 32-bit)
    inc word [rsi]                ; Increment PC
    
    movzx ebx, byte [r14]         ; ebx = A (zero-extended)
    
    mov rdi, r15
    call get_carry_flag
    movzx edx, al                 ; edx = carry_in
    
    mov eax, ebx                  ; eax = A
    add al, r13b                  ; al = A + operand
    setc dh                       ; dh = 1 if A+op > 0xFF
    add al, dl                    ; al = A + operand + carry_in
    setc cl                       ; cl = 1 if final > 0xFF
    
    or cl, dh
    test cl, cl
    jz .adc_carry_0
    mov sil, 1
    mov rdi, r15
    call set_carry_flag
    jmp .adc_overflow
.adc_carry_0:
    mov sil, 0
    mov rdi, r15
    call set_carry_flag

.adc_overflow:
    mov cl, al                    ; cl = result
    
    mov sil, bl                   ; sil = A
    xor sil, cl                   ; sil = A ^ result
    mov dil, r13b                 ; dil = operand
    xor dil, cl                   ; dil = operand ^ result
    and sil, dil
    and sil, 0x80
    jz .adc_overflow_0
    mov sil, 1
    mov rdi, r15
    call set_overflow_flag
    jmp .adc_store
.adc_overflow_0:
    mov sil, 0
    mov rdi, r15
    call set_overflow_flag

.adc_store:
    mov [r14], al
    mov rdi, r15
    call set_zn_flags
    
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 2
    ret

; SBC - Subtract with Borrow ($E9 immediate) - 2 cycles
; SBC Immediate ($E9) - 2 cycles
global sbc_immediate
sbc_immediate:
    push rbx
    push r12
    push r13
    push r14         ; <- new: we need another reg for original A

    mov r12, rcx                 ; r12 = P*
    mov r14, rdx                 ; r14 = A*  (save for later)

    ; Read operand
    movzx rbx, word [rsi]
    mov r11, rbx
    call read_memory_byte
    movzx r13d, al                ; r13 = operand
    inc word [rsi]

    ; Get A
    movzx eax, byte [r14]         ; A

    ; Get carry flag
    movzx ebx, byte [r12]         ; P
    and ebx, 1                    ; carry (0 or 1)

    ; Calculate borrow = 1 - carry
    mov ecx, 1
    sub ecx, ebx                  ; borrow = 1 - C

    ; 16-bit subtraction
    sub eax, r13d                 ; A - operand
    sub eax, ecx                  ; subtract borrow

    ; Check for borrow
    cmp eax, 0
    jge .no_borrow_sbc
    add eax, 0x100                ; wrap around
    mov ebx, 0                    ; new carry = 0 (borrow occurred)
    jmp .set_carry_sbc
.no_borrow_sbc:
    mov ebx, 1                    ; new carry = 1 (no borrow)
    movzx eax, al                 ; keep low 8 bits

.set_carry_sbc:
        ; Result stays in al, operand stays in r13b
        ; FIX: Keep result in al, do NOT overwrite r13 (operand must survive for V calc)

    ; Update P with new carry
    movzx ecx, byte [r12]
    and ecx, 0xFE
    or ecx, ebx
    mov [r12], cl

    ; Compute V flag: V = ((A ^ operand) & (A ^ result) & 0x80)
    movzx ecx, byte [r14]         ; original A
    mov bl, al                    ; result (from al, not r13b!)
    mov sil, cl                   ; A
    xor sil, r13b                 ; A ^ operand
    xor cl, bl                    ; A ^ result
    and sil, cl                   ; (A ^ operand) & (A ^ result)
    and sil, 0x80
    jz .sbc_imm_overflow_0
    mov sil, 1
    mov rdi, r12
    call set_overflow_flag
    jmp .sbc_imm_store
.sbc_imm_overflow_0:
    mov sil, 0
    mov rdi, r12
    call set_overflow_flag

.sbc_imm_store:
    ; Store result in A
    mov [r14], al

    ; Update Z and N flags
    mov rdi, r12
    call set_zn_flags

    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 2
    ret
    
global inc_zeropage
inc_zeropage:
    push rbx
    push r12
    push r13

    movzx ebx, word [rsi]         ; ebx = PC
    mov r11, rbx
    call read_memory_byte         ; read zp address via callback
    movzx r13d, al                ; r13d = zp address (preserved)
    inc word [rsi]                ; PC++

    mov r11, r13                  ; r11 = zp address
    call read_memory_byte         ; read current value
    inc al
    mov r12b, al                  ; value for write

    mov rdi, rcx                  ; P*
    call set_zn_flags

    mov r11, r13                  ; address in r11
    call write_memory_byte        ; write back via bus

    pop r13
    pop r12
    pop rbx
    mov eax, 5
    ret

; DEC - Decrement Memory Zeropage ($C6) - 5 cycles
global dec_zeropage
dec_zeropage:
    push rbx
    push r12
    push r13

    movzx ebx, word [rsi]
    mov r11, rbx
    call read_memory_byte
    movzx r13d, al                ; zp addr
    inc word [rsi]

    mov r11, r13
    call read_memory_byte
    dec al
    mov r12b, al

    mov rdi, rcx
    call set_zn_flags

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 5
    ret

; Additional addressing modes — include the shared macro library
%include "addr_modes.inc"

; ADC Zeropage ($65) - 3 cycles
global adc_zeropage
adc_zeropage:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi        ; r12 = memory*
    mov r14, rdx        ; r14 = A*
    mov r15, rcx        ; r15 = P*

    ADDR_ZEROPAGE               ; rbx = zeropage address; PC advanced
    mov r11, rbx                ; r11 = zeropage address for read_memory_byte
    call read_memory_byte       ; Read operand via callback
    movzx r13d, al              ; r13 = operand

    jmp .do_adc_zp
.do_adc_zp:
    ; Get carry_in
    movzx ebx, byte [r14]       ; ebx = A
    mov rdi, r15
    call get_carry_flag
    movzx edx, al               ; edx = carry_in

    mov eax, ebx                ; eax = A
    add al, r13b                ; al = A + operand
    setc dh                     ; dh = intermediate carry
    add al, dl                  ; al = A + operand + carry_in
    setc cl                     ; cl = final carry

    or cl, dh                   ; cl = 1 if any carry
    test cl, cl
    jz .adc_zp_carry_0
    mov sil, 1
    mov rdi, r15
    call set_carry_flag
    jmp .adc_zp_overflow
.adc_zp_carry_0:
    mov sil, 0
    mov rdi, r15
    call set_carry_flag

.adc_zp_overflow:
    mov cl, al                  ; cl = result
    mov sil, bl                 ; sil = A
    xor sil, cl                 ; sil = A ^ result
    mov dil, r13b               ; dil = operand
    xor dil, cl                 ; dil = operand ^ result
    and sil, dil
    and sil, 0x80
    jz .adc_zp_overflow_0
    mov sil, 1
    mov rdi, r15
    call set_overflow_flag
    jmp .adc_zp_store
.adc_zp_overflow_0:
    mov sil, 0
    mov rdi, r15
    call set_overflow_flag

.adc_zp_store:
    mov [r14], al
    mov rdi, r15
    call set_zn_flags

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 3
    ret

; ADC Zeropage,X ($75) - 4 cycles
global adc_zeropage_x
adc_zeropage_x:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r14, rdx
    mov r15, rcx

    ADDR_ZEROPAGE_X             ; rbx = (base+X)&0xFF; PC advanced
    mov r11, rbx                ; r11 = address for read_memory_byte
    call read_memory_byte       ; Read operand via callback
    movzx r13d, al              ; r13 = operand

    movzx ebx, byte [r14]
    mov rdi, r15
    call get_carry_flag
    movzx edx, al

    mov eax, ebx
    add al, r13b
    setc dh
    add al, dl
    setc cl
    or cl, dh
    test cl, cl
    jz .adc_zpx_carry_0
    mov sil, 1
    mov rdi, r15
    call set_carry_flag
    jmp .adc_zpx_overflow
.adc_zpx_carry_0:
    mov sil, 0
    mov rdi, r15
    call set_carry_flag

.adc_zpx_overflow:
    mov cl, al
    mov sil, bl
    xor sil, cl
    mov dil, r13b
    xor dil, cl
    and sil, dil
    and sil, 0x80
    jz .adc_zpx_overflow_0
    mov sil, 1
    mov rdi, r15
    call set_overflow_flag
    jmp .adc_zpx_store
.adc_zpx_overflow_0:
    mov sil, 0
    mov rdi, r15
    call set_overflow_flag

.adc_zpx_store:
    mov [r14], al
    mov rdi, r15
    call set_zn_flags

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 4
    ret

; ADC Absolute ($6D) - 4 cycles
global adc_absolute
adc_absolute:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r14, rdx
    mov r15, rcx

    ADDR_ABSOLUTE               ; rbx = 16-bit absolute address; PC advanced
    mov r11, rbx                ; r11 = address for read_memory_byte
    call read_memory_byte       ; Read operand via callback
    movzx r13d, al              ; r13 = operand

    movzx ebx, byte [r14]
    mov rdi, r15
    call get_carry_flag
    movzx edx, al

    mov eax, ebx
    add al, r13b
    setc dh
    add al, dl
    setc cl
    or cl, dh
    test cl, cl
    jz .adc_abs_carry_0
    mov sil, 1
    mov rdi, r15
    call set_carry_flag
    jmp .adc_abs_overflow
.adc_abs_carry_0:
    mov sil, 0
    mov rdi, r15
    call set_carry_flag

.adc_abs_overflow:
    mov cl, al
    mov sil, bl
    xor sil, cl
    mov dil, r13b
    xor dil, cl
    and sil, dil
    and sil, 0x80
    jz .adc_abs_overflow_0
    mov sil, 1
    mov rdi, r15
    call set_overflow_flag
    jmp .adc_abs_store
.adc_abs_overflow_0:
    mov sil, 0
    mov rdi, r15
    call set_overflow_flag

.adc_abs_store:
    mov [r14], al
    mov rdi, r15
    call set_zn_flags

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 4
    ret

; ADC Absolute,X ($7D) - 4+1 cycles (page-cross penalty)
global adc_absolute_x
adc_absolute_x:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r14, rdx
    mov r15, rcx

    ADDR_ABSOLUTE_X             ; rbx = effective addr; r13d = page-crossed flag
    push r13                    ; save page-cross flag
    mov r11, rbx                ; r11 = address for read_memory_byte
    call read_memory_byte       ; Read operand via callback
    movzx r13d, al              ; r13 = operand (overwrites, but we saved flag)

    ; We need page-cross flag after. Let's use stack:
    ; [rsp] = page-cross flag (saved just before)
    ; Save operand elsewhere before restoring page flag
    movzx ebx, byte [r14]       ; ebx = A
    mov rdi, r15
    call get_carry_flag
    movzx edx, al               ; edx = carry_in

    mov eax, ebx
    add al, r13b
    setc dh
    add al, dl
    setc cl
    or cl, dh
    test cl, cl
    jz .adc_absx_carry_0
    mov sil, 1
    mov rdi, r15
    call set_carry_flag
    jmp .adc_absx_overflow
.adc_absx_carry_0:
    mov sil, 0
    mov rdi, r15
    call set_carry_flag

.adc_absx_overflow:
    mov cl, al
    mov sil, bl
    xor sil, cl
    mov dil, r13b
    xor dil, cl
    and sil, dil
    and sil, 0x80
    jz .adc_absx_overflow_0
    mov sil, 1
    mov rdi, r15
    call set_overflow_flag
    jmp .adc_absx_store
.adc_absx_overflow_0:
    mov sil, 0
    mov rdi, r15
    call set_overflow_flag

.adc_absx_store:
    mov [r14], al
    mov rdi, r15
    call set_zn_flags

    pop r13                     ; restore page-cross flag
    mov eax, 4
    add eax, r13d               ; +1 if page crossed

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ADC Absolute,Y ($79) - 4+1 cycles (page-cross penalty)
global adc_absolute_y
adc_absolute_y:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r14, rdx
    mov r15, rcx

    ADDR_ABSOLUTE_Y             ; rbx = effective addr; r13d = page-crossed flag
    push r13                    ; save page-cross flag
    mov r11, rbx                ; r11 = address for read_memory_byte
    call read_memory_byte       ; Read operand via callback
    movzx r13d, al              ; r13 = operand

    movzx ebx, byte [r14]
    mov rdi, r15
    call get_carry_flag
    movzx edx, al

    mov eax, ebx
    add al, r13b
    setc dh
    add al, dl
    setc cl
    or cl, dh
    test cl, cl
    jz .adc_absy_carry_0
    mov sil, 1
    mov rdi, r15
    call set_carry_flag
    jmp .adc_absy_overflow
.adc_absy_carry_0:
    mov sil, 0
    mov rdi, r15
    call set_carry_flag

.adc_absy_overflow:
    mov cl, al
    mov sil, bl
    xor sil, cl
    mov dil, r13b
    xor dil, cl
    and sil, dil
    and sil, 0x80
    jz .adc_absy_overflow_0
    mov sil, 1
    mov rdi, r15
    call set_overflow_flag
    jmp .adc_absy_store
.adc_absy_overflow_0:
    mov sil, 0
    mov rdi, r15
    call set_overflow_flag

.adc_absy_store:
    mov [r14], al
    mov rdi, r15
    call set_zn_flags

    pop r13                     ; restore page-cross flag
    mov eax, 4
    add eax, r13d               ; +1 if page crossed

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; ADC (Indirect,X) ($61) - 6 cycles
global adc_indirect_x
adc_indirect_x:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r14, rdx
    mov r15, rcx

    ADDR_INDIRECT_X             ; rbx = effective address; PC advanced
    mov r11, rbx                ; r11 = address for read_memory_byte
    call read_memory_byte       ; Read operand via callback
    movzx r13d, al              ; r13 = operand

    movzx ebx, byte [r14]
    mov rdi, r15
    call get_carry_flag
    movzx edx, al

    mov eax, ebx
    add al, r13b
    setc dh
    add al, dl
    setc cl
    or cl, dh
    test cl, cl
    jz .adc_indx_carry_0
    mov sil, 1
    mov rdi, r15
    call set_carry_flag
    jmp .adc_indx_overflow
.adc_indx_carry_0:
    mov sil, 0
    mov rdi, r15
    call set_carry_flag

.adc_indx_overflow:
    mov cl, al
    mov sil, bl
    xor sil, cl
    mov dil, r13b
    xor dil, cl
    and sil, dil
    and sil, 0x80
    jz .adc_indx_overflow_0
    mov sil, 1
    mov rdi, r15
    call set_overflow_flag
    jmp .adc_indx_store
.adc_indx_overflow_0:
    mov sil, 0
    mov rdi, r15
    call set_overflow_flag

.adc_indx_store:
    mov [r14], al
    mov rdi, r15
    call set_zn_flags

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 6
    ret

; ADC (Indirect),Y ($71) - 5+1 cycles (page-cross penalty)
global adc_indirect_y
adc_indirect_y:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r14, rdx
    mov r15, rcx

    ADDR_INDIRECT_Y             ; rbx = effective addr; r13d = page-crossed flag
    push r13                    ; save page-cross flag
    mov r11, rbx                ; r11 = address for read_memory_byte
    call read_memory_byte       ; Read operand via callback
    movzx r13d, al              ; r13 = operand

    movzx ebx, byte [r14]
    mov rdi, r15
    call get_carry_flag
    movzx edx, al

    mov eax, ebx
    add al, r13b
    setc dh
    add al, dl
    setc cl
    or cl, dh
    test cl, cl
    jz .adc_indy_carry_0
    mov sil, 1
    mov rdi, r15
    call set_carry_flag
    jmp .adc_indy_overflow
.adc_indy_carry_0:
    mov sil, 0
    mov rdi, r15
    call set_carry_flag

.adc_indy_overflow:
    mov cl, al
    mov sil, bl
    xor sil, cl
    mov dil, r13b
    xor dil, cl
    and sil, dil
    and sil, 0x80
    jz .adc_indy_overflow_0
    mov sil, 1
    mov rdi, r15
    call set_overflow_flag
    jmp .adc_indy_store
.adc_indy_overflow_0:
    mov sil, 0
    mov rdi, r15
    call set_overflow_flag

.adc_indy_store:
    mov [r14], al
    mov rdi, r15
    call set_zn_flags

    pop r13                     ; restore page-cross flag
    mov eax, 5
    add eax, r13d               ; +1 if page crossed

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; SBC — Subtract with Borrow: additional addressing modes

; SBC Zeropage ($E5) - 3 cycles
global sbc_zeropage
sbc_zeropage:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r14, rdx        ; r14 = A*
    mov r15, rcx        ; r15 = P*

    ADDR_ZEROPAGE               ; rbx = zeropage address
    mov r11, rbx                ; r11 = address for read_memory_byte
    call read_memory_byte       ; Read operand via callback
    movzx r13d, al              ; r13 = operand

    ; Get carry (borrow_in = 1 - C)
    movzx eax, byte [r14]       ; eax = A
    movzx ebx, byte [r15]       ; ebx = P
    and ebx, 1                  ; ebx = C flag
    mov ecx, 1
    sub ecx, ebx                ; ecx = borrow = 1 - C

    ; Compute A - operand - borrow in 16-bit to detect borrow out
    movzx eax, al               ; zero-extend A
    sub eax, r13d               ; eax = A - operand
    sub eax, ecx                ; eax = A - operand - borrow

    ; C_out = 1 if no borrow (result >= 0 before masking)
    test eax, eax
    jge .sbc_zp_no_borrow
    add eax, 0x100              ; two's complement wrap
    mov ebx, 0                  ; C = 0 (borrow occurred)
    jmp .sbc_zp_set_carry
.sbc_zp_no_borrow:
    mov ebx, 1                  ; C = 1 (no borrow)

.sbc_zp_set_carry:
    ; Store carry in P directly (bit 0)
    movzx ecx, byte [r15]
    and ecx, 0xFE
    or ecx, ebx
    mov [r15], cl

    ; Compute overflow: V = ((A ^ operand) & (A ^ result)) & 0x80
    movzx ecx, byte [r14]       ; ecx = original A
    mov bl, al                  ; bl = result
    mov sil, cl                 ; sil = A
    xor sil, r13b               ; sil = A ^ operand
    xor cl, bl                  ; cl  = A ^ result
    and sil, cl                 ; sil = (A^operand) & (A^result)
    and sil, 0x80
    jz .sbc_zp_overflow_0
    mov sil, 1
    mov rdi, r15
    call set_overflow_flag
    jmp .sbc_zp_store
.sbc_zp_overflow_0:
    mov sil, 0
    mov rdi, r15
    call set_overflow_flag

.sbc_zp_store:
    mov [r14], al               ; store result in A
    mov rdi, r15
    call set_zn_flags

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 3
    ret

; SBC Zeropage,X ($F5) - 4 cycles
global sbc_zeropage_x
sbc_zeropage_x:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r14, rdx
    mov r15, rcx

    ADDR_ZEROPAGE_X             ; rbx = (base+X)&0xFF
    mov r11, rbx                ; r11 = address for read_memory_byte
    call read_memory_byte       ; Read operand via callback
    movzx r13d, al              ; r13 = operand

    movzx eax, byte [r14]
    movzx ebx, byte [r15]
    and ebx, 1
    mov ecx, 1
    sub ecx, ebx

    movzx eax, al
    sub eax, r13d
    sub eax, ecx

    test eax, eax
    jge .sbc_zpx_no_borrow
    add eax, 0x100
    mov ebx, 0
    jmp .sbc_zpx_set_carry
.sbc_zpx_no_borrow:
    mov ebx, 1

.sbc_zpx_set_carry:
    movzx ecx, byte [r15]
    and ecx, 0xFE
    or ecx, ebx
    mov [r15], cl

    movzx ecx, byte [r14]
    mov bl, al
    mov sil, cl
    xor sil, r13b
    xor cl, bl
    and sil, cl
    and sil, 0x80
    jz .sbc_zpx_overflow_0
    mov sil, 1
    mov rdi, r15
    call set_overflow_flag
    jmp .sbc_zpx_store
.sbc_zpx_overflow_0:
    mov sil, 0
    mov rdi, r15
    call set_overflow_flag

.sbc_zpx_store:
    mov [r14], al
    mov rdi, r15
    call set_zn_flags

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 4
    ret

; SBC Absolute ($ED) - 4 cycles
global sbc_absolute
sbc_absolute:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r14, rdx
    mov r15, rcx

    ADDR_ABSOLUTE               ; rbx = 16-bit address
    mov r11, rbx                ; r11 = address for read_memory_byte
    call read_memory_byte       ; Read operand via callback
    movzx r13d, al              ; r13 = operand

    movzx eax, byte [r14]
    movzx ebx, byte [r15]
    and ebx, 1
    mov ecx, 1
    sub ecx, ebx

    movzx eax, al
    sub eax, r13d
    sub eax, ecx

    test eax, eax
    jge .sbc_abs_no_borrow
    add eax, 0x100
    mov ebx, 0
    jmp .sbc_abs_set_carry
.sbc_abs_no_borrow:
    mov ebx, 1

.sbc_abs_set_carry:
    movzx ecx, byte [r15]
    and ecx, 0xFE
    or ecx, ebx
    mov [r15], cl

    movzx ecx, byte [r14]
    mov bl, al
    mov sil, cl
    xor sil, r13b
    xor cl, bl
    and sil, cl
    and sil, 0x80
    jz .sbc_abs_overflow_0
    mov sil, 1
    mov rdi, r15
    call set_overflow_flag
    jmp .sbc_abs_store
.sbc_abs_overflow_0:
    mov sil, 0
    mov rdi, r15
    call set_overflow_flag

.sbc_abs_store:
    mov [r14], al
    mov rdi, r15
    call set_zn_flags

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 4
    ret

; SBC Absolute,X ($FD) - 4+1 cycles (page-cross penalty)
global sbc_absolute_x
sbc_absolute_x:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r14, rdx
    mov r15, rcx

    ADDR_ABSOLUTE_X             ; rbx = effective addr; r13d = page-crossed
    push r13                    ; save page-cross flag
    mov r11, rbx                ; r11 = address for read_memory_byte
    call read_memory_byte       ; Read operand via callback
    movzx r13d, al              ; r13 = operand

    movzx eax, byte [r14]
    movzx ebx, byte [r15]
    and ebx, 1
    mov ecx, 1
    sub ecx, ebx

    movzx eax, al
    sub eax, r13d
    sub eax, ecx

    test eax, eax
    jge .sbc_absx_no_borrow
    add eax, 0x100
    mov ebx, 0
    jmp .sbc_absx_set_carry
.sbc_absx_no_borrow:
    mov ebx, 1

.sbc_absx_set_carry:
    movzx ecx, byte [r15]
    and ecx, 0xFE
    or ecx, ebx
    mov [r15], cl

    movzx ecx, byte [r14]
    mov bl, al
    mov sil, cl
    xor sil, r13b
    xor cl, bl
    and sil, cl
    and sil, 0x80
    jz .sbc_absx_overflow_0
    mov sil, 1
    mov rdi, r15
    call set_overflow_flag
    jmp .sbc_absx_store
.sbc_absx_overflow_0:
    mov sil, 0
    mov rdi, r15
    call set_overflow_flag

.sbc_absx_store:
    mov [r14], al
    mov rdi, r15
    call set_zn_flags

    pop r13                     ; restore page-cross flag
    mov eax, 4
    add eax, r13d               ; +1 if page crossed

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; SBC Absolute,Y ($F9) - 4+1 cycles (page-cross penalty)
global sbc_absolute_y
sbc_absolute_y:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r14, rdx
    mov r15, rcx

    ADDR_ABSOLUTE_Y             ; rbx = effective addr; r13d = page-crossed
    push r13                    ; save page-cross flag
    mov r11, rbx                ; r11 = address for read_memory_byte
    call read_memory_byte       ; Read operand via callback
    movzx r13d, al              ; r13 = operand

    movzx eax, byte [r14]
    movzx ebx, byte [r15]
    and ebx, 1
    mov ecx, 1
    sub ecx, ebx

    movzx eax, al
    sub eax, r13d
    sub eax, ecx

    test eax, eax
    jge .sbc_absy_no_borrow
    add eax, 0x100
    mov ebx, 0
    jmp .sbc_absy_set_carry
.sbc_absy_no_borrow:
    mov ebx, 1

.sbc_absy_set_carry:
    movzx ecx, byte [r15]
    and ecx, 0xFE
    or ecx, ebx
    mov [r15], cl

    movzx ecx, byte [r14]
    mov bl, al
    mov sil, cl
    xor sil, r13b
    xor cl, bl
    and sil, cl
    and sil, 0x80
    jz .sbc_absy_overflow_0
    mov sil, 1
    mov rdi, r15
    call set_overflow_flag
    jmp .sbc_absy_store
.sbc_absy_overflow_0:
    mov sil, 0
    mov rdi, r15
    call set_overflow_flag

.sbc_absy_store:
    mov [r14], al
    mov rdi, r15
    call set_zn_flags

    pop r13                     ; restore page-cross flag
    mov eax, 4
    add eax, r13d               ; +1 if page crossed

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; SBC (Indirect,X) ($E1) - 6 cycles
global sbc_indirect_x
sbc_indirect_x:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r14, rdx
    mov r15, rcx

    ADDR_INDIRECT_X             ; rbx = effective address
    mov r11, rbx                ; r11 = address for read_memory_byte
    call read_memory_byte       ; Read operand via callback
    movzx r13d, al              ; r13 = operand

    movzx eax, byte [r14]
    movzx ebx, byte [r15]
    and ebx, 1
    mov ecx, 1
    sub ecx, ebx

    movzx eax, al
    sub eax, r13d
    sub eax, ecx

    test eax, eax
    jge .sbc_indx_no_borrow
    add eax, 0x100
    mov ebx, 0
    jmp .sbc_indx_set_carry
.sbc_indx_no_borrow:
    mov ebx, 1

.sbc_indx_set_carry:
    movzx ecx, byte [r15]
    and ecx, 0xFE
    or ecx, ebx
    mov [r15], cl

    movzx ecx, byte [r14]
    mov bl, al
    mov sil, cl
    xor sil, r13b
    xor cl, bl
    and sil, cl
    and sil, 0x80
    jz .sbc_indx_overflow_0
    mov sil, 1
    mov rdi, r15
    call set_overflow_flag
    jmp .sbc_indx_store
.sbc_indx_overflow_0:
    mov sil, 0
    mov rdi, r15
    call set_overflow_flag

.sbc_indx_store:
    mov [r14], al
    mov rdi, r15
    call set_zn_flags

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 6
    ret

; SBC (Indirect),Y ($F1) - 5+1 cycles (page-cross penalty)
global sbc_indirect_y
sbc_indirect_y:
    push rbx
    push r12
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r14, rdx
    mov r15, rcx

    ADDR_INDIRECT_Y             ; rbx = effective addr; r13d = page-crossed
    push r13                    ; save page-cross flag
    mov r11, rbx                ; r11 = address for read_memory_byte
    call read_memory_byte       ; Read operand via callback
    movzx r13d, al              ; r13 = operand

    movzx eax, byte [r14]
    movzx ebx, byte [r15]
    and ebx, 1
    mov ecx, 1
    sub ecx, ebx

    movzx eax, al
    sub eax, r13d
    sub eax, ecx

    test eax, eax
    jge .sbc_indy_no_borrow
    add eax, 0x100
    mov ebx, 0
    jmp .sbc_indy_set_carry
.sbc_indy_no_borrow:
    mov ebx, 1

.sbc_indy_set_carry:
    movzx ecx, byte [r15]
    and ecx, 0xFE
    or ecx, ebx
    mov [r15], cl

    movzx ecx, byte [r14]
    mov bl, al
    mov sil, cl
    xor sil, r13b
    xor cl, bl
    and sil, cl
    and sil, 0x80
    jz .sbc_indy_overflow_0
    mov sil, 1
    mov rdi, r15
    call set_overflow_flag
    jmp .sbc_indy_store
.sbc_indy_overflow_0:
    mov sil, 0
    mov rdi, r15
    call set_overflow_flag

.sbc_indy_store:
    mov [r14], al
    mov rdi, r15
    call set_zn_flags

    pop r13                     ; restore page-cross flag
    mov eax, 5
    add eax, r13d               ; +1 if page crossed

    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; INC — Increment Memory: additional addressing modes (RMW) — now uses write_memory_byte

; INC Absolute ($EE) - 6 cycles
global inc_absolute
inc_absolute:
    push rbx
    push r12
    push r13

    mov r12, rdi                  ; save memory pointer (unused, but keep convention)
    ADDR_ABSOLUTE                 ; rbx = 16-bit absolute address
    mov r13, rbx                  ; preserve address
    mov r11, rbx
    call read_memory_byte
    inc al
    mov r12b, al

    mov rdi, rcx
    call set_zn_flags

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 6
    ret

; INC Zeropage,X ($F6) - 6 cycles
global inc_zeropage_x
inc_zeropage_x:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ZEROPAGE_X               ; rbx = (base+X)&0xFF
    mov r13, rbx                  ; preserve address
    mov r11, rbx
    call read_memory_byte
    inc al
    mov r12b, al

    mov rdi, rcx
    call set_zn_flags

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 6
    ret

; INC Absolute,X ($FE) - 7 cycles
global inc_absolute_x
inc_absolute_x:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ABSOLUTE_X               ; rbx = effective addr, r13d = page flag (ignored for RMW)
    mov r13, rbx                  ; preserve effective address
    mov r11, rbx
    call read_memory_byte
    inc al
    mov r12b, al

    mov rdi, rcx
    call set_zn_flags

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 7
    ret

; DEC — Decrement Memory: additional addressing modes (RMW)

; DEC Absolute ($CE) - 6 cycles
global dec_absolute
dec_absolute:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ABSOLUTE
    mov r13, rbx
    mov r11, rbx
    call read_memory_byte
    dec al
    mov r12b, al

    mov rdi, rcx
    call set_zn_flags

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 6
    ret

; DEC Zeropage,X ($D6) - 6 cycles
global dec_zeropage_x
dec_zeropage_x:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ZEROPAGE_X
    mov r13, rbx
    mov r11, rbx
    call read_memory_byte
    dec al
    mov r12b, al

    mov rdi, rcx
    call set_zn_flags

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 6
    ret

; DEC Absolute,X ($DE) - 7 cycles
global dec_absolute_x
dec_absolute_x:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ABSOLUTE_X
    mov r13, rbx
    mov r11, rbx
    call read_memory_byte
    dec al
    mov r12b, al

    mov rdi, rcx
    call set_zn_flags

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 7
    ret

; INX ($E8), INY ($C8), DEX ($CA), DEY ($88) - 2 cycles each
global inx_instr
inx_instr:
    inc byte [r8]
    movzx eax, byte [r8]
    mov rdi, rcx
    call set_zn_flags
    mov eax, 2
    ret

global iny_instr
iny_instr:
    inc byte [r9]
    movzx eax, byte [r9]
    mov rdi, rcx
    call set_zn_flags
    mov eax, 2
    ret

global dex_instr
dex_instr:
    dec byte [r8]
    movzx eax, byte [r8]
    mov rdi, rcx
    call set_zn_flags
    mov eax, 2
    ret

global dey_instr
dey_instr:
    dec byte [r9]
    movzx eax, byte [r9]
    mov rdi, rcx
    call set_zn_flags
    mov eax, 2
    ret

section .note.GNU-stack noalloc noexec nowrite progbits