; External functions from flags.asm
extern set_zn_flags
extern set_carry_flag
extern get_carry_flag

; External helper for memory reads/writes via callback
extern read_memory_byte
extern write_memory_byte

section .text
    bits 64

%include "addr_modes.inc"

; AND - Logical AND
; AND Immediate ($29) - 2 cycles
global and_immediate
and_immediate:
    push rbx
    movzx r11, word [rsi]
    call read_memory_byte
    and al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    inc word [rsi]
    pop rbx
    mov eax, 2
    ret

; ORA - Logical OR
; ORA Immediate ($09) - 2 cycles
global ora_immediate
ora_immediate:
    push rbx
    movzx r11, word [rsi]
    call read_memory_byte
    or al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    inc word [rsi]
    pop rbx
    mov eax, 2
    ret

; EOR - Logical XOR
; EOR Immediate ($49) - 2 cycles
global eor_immediate
eor_immediate:
    push rbx
    movzx r11, word [rsi]
    call read_memory_byte
    xor al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    inc word [rsi]
    pop rbx
    mov eax, 2
    ret

; ASL - Arithmetic Shift Left (Accumulator) ($0A) - 2 cycles
global asl_accumulator
asl_accumulator:
    push rbx
    mov al, [rdx]
    test al, 0x80
    jz .asl_no_carry
    mov sil, 1
    mov rdi, rcx
    call set_carry_flag
    jmp .asl_shift
.asl_no_carry:
    mov sil, 0
    mov rdi, rcx
    call set_carry_flag
.asl_shift:
    shl byte [rdx], 1
    movzx eax, byte [rdx]
    mov rdi, rcx
    call set_zn_flags
    pop rbx
    mov eax, 2
    ret

; LSR - Logical Shift Right (Accumulator) ($4A) - 2 cycles
global lsr_accumulator
lsr_accumulator:
    push rbx
    mov al, [rdx]
    test al, 0x01
    jz .lsr_no_carry
    mov sil, 1
    mov rdi, rcx
    call set_carry_flag
    jmp .lsr_shift
.lsr_no_carry:
    mov sil, 0
    mov rdi, rcx
    call set_carry_flag
.lsr_shift:
    shr byte [rdx], 1
    movzx eax, byte [rdx]
    mov rdi, rcx
    call set_zn_flags
    and byte [rcx], 0x7F
    pop rbx
    mov eax, 2
    ret

; ROL - Rotate Left (Accumulator) ($2A) - 2 cycles
global rol_accumulator
rol_accumulator:
    push rbx
    mov al, [rdx]
    mov bl, al
    shr bl, 7
    shl al, 1
    mov ah, [rcx]
    and ah, 0x01
    add al, ah
    mov [rdx], al
    movzx esi, bl
    mov rdi, rcx
    call set_carry_flag
    mov al, [rdx]
    mov rdi, rcx
    call set_zn_flags
    pop rbx
    mov eax, 2
    ret

; ROR - Rotate Right (Accumulator) ($6A) - 2 cycles
global ror_accumulator
ror_accumulator:
    push rbx
    mov al, [rdx]
    mov bl, al
    and bl, 0x01
    shr al, 1
    mov ah, [rcx]
    and ah, 0x01
    shl ah, 7
    add al, ah
    mov [rdx], al
    movzx esi, bl
    mov rdi, rcx
    call set_carry_flag
    mov al, [rdx]
    mov rdi, rcx
    call set_zn_flags
    pop rbx
    mov eax, 2
    ret

; -------------------------------------------------------------------
; AND — additional addressing modes (read-only, no write needed)
; -------------------------------------------------------------------
global and_zeropage
and_zeropage:
    push rbx
    mov r12, rdi
    ADDR_ZEROPAGE
    mov r11, rbx
    call read_memory_byte
    and al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    pop rbx
    mov eax, 3
    ret

global and_zeropage_x
and_zeropage_x:
    push rbx
    mov r12, rdi
    ADDR_ZEROPAGE_X
    mov r11, rbx
    call read_memory_byte
    and al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    pop rbx
    mov eax, 4
    ret

global and_absolute
and_absolute:
    push rbx
    mov r12, rdi
    ADDR_ABSOLUTE
    mov r11, rbx
    call read_memory_byte
    and al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    pop rbx
    mov eax, 4
    ret

global and_absolute_x
and_absolute_x:
    push rbx
    push r13
    mov r12, rdi
    ADDR_ABSOLUTE_X
    mov r11, rbx
    call read_memory_byte
    and al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    mov eax, 4
    add eax, r13d
    pop r13
    pop rbx
    ret

global and_absolute_y
and_absolute_y:
    push rbx
    push r13
    mov r12, rdi
    ADDR_ABSOLUTE_Y
    mov r11, rbx
    call read_memory_byte
    and al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    mov eax, 4
    add eax, r13d
    pop r13
    pop rbx
    ret

global and_indirect_x
and_indirect_x:
    push rbx
    mov r12, rdi
    ADDR_INDIRECT_X
    mov r11, rbx
    call read_memory_byte
    and al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    pop rbx
    mov eax, 6
    ret

global and_indirect_y
and_indirect_y:
    push rbx
    push r13
    mov r12, rdi
    ADDR_INDIRECT_Y
    mov r11, rbx
    call read_memory_byte
    and al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    mov eax, 5
    add eax, r13d
    pop r13
    pop rbx
    ret

; -------------------------------------------------------------------
; ORA — additional addressing modes
; -------------------------------------------------------------------
global ora_zeropage
ora_zeropage:
    push rbx
    mov r12, rdi
    ADDR_ZEROPAGE
    mov r11, rbx
    call read_memory_byte
    or al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    pop rbx
    mov eax, 3
    ret

global ora_zeropage_x
ora_zeropage_x:
    push rbx
    mov r12, rdi
    ADDR_ZEROPAGE_X
    mov r11, rbx
    call read_memory_byte
    or al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    pop rbx
    mov eax, 4
    ret

global ora_absolute
ora_absolute:
    push rbx
    mov r12, rdi
    ADDR_ABSOLUTE
    mov r11, rbx
    call read_memory_byte
    or al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    pop rbx
    mov eax, 4
    ret

global ora_absolute_x
ora_absolute_x:
    push rbx
    push r13
    mov r12, rdi
    ADDR_ABSOLUTE_X
    mov r11, rbx
    call read_memory_byte
    or al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    mov eax, 4
    add eax, r13d
    pop r13
    pop rbx
    ret

global ora_absolute_y
ora_absolute_y:
    push rbx
    push r13
    mov r12, rdi
    ADDR_ABSOLUTE_Y
    mov r11, rbx
    call read_memory_byte
    or al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    mov eax, 4
    add eax, r13d
    pop r13
    pop rbx
    ret

global ora_indirect_x
ora_indirect_x:
    push rbx
    mov r12, rdi
    ADDR_INDIRECT_X
    mov r11, rbx
    call read_memory_byte
    or al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    pop rbx
    mov eax, 6
    ret

global ora_indirect_y
ora_indirect_y:
    push rbx
    push r13
    mov r12, rdi
    ADDR_INDIRECT_Y
    mov r11, rbx
    call read_memory_byte
    or al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    mov eax, 5
    add eax, r13d
    pop r13
    pop rbx
    ret

; -------------------------------------------------------------------
; EOR — additional addressing modes
; -------------------------------------------------------------------
global eor_zeropage
eor_zeropage:
    push rbx
    mov r12, rdi
    ADDR_ZEROPAGE
    mov r11, rbx
    call read_memory_byte
    xor al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    pop rbx
    mov eax, 3
    ret

global eor_zeropage_x
eor_zeropage_x:
    push rbx
    mov r12, rdi
    ADDR_ZEROPAGE_X
    mov r11, rbx
    call read_memory_byte
    xor al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    pop rbx
    mov eax, 4
    ret

global eor_absolute
eor_absolute:
    push rbx
    mov r12, rdi
    ADDR_ABSOLUTE
    mov r11, rbx
    call read_memory_byte
    xor al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    pop rbx
    mov eax, 4
    ret

global eor_absolute_x
eor_absolute_x:
    push rbx
    push r13
    mov r12, rdi
    ADDR_ABSOLUTE_X
    mov r11, rbx
    call read_memory_byte
    xor al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    mov eax, 4
    add eax, r13d
    pop r13
    pop rbx
    ret

global eor_absolute_y
eor_absolute_y:
    push rbx
    push r13
    mov r12, rdi
    ADDR_ABSOLUTE_Y
    mov r11, rbx
    call read_memory_byte
    xor al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    mov eax, 4
    add eax, r13d
    pop r13
    pop rbx
    ret

global eor_indirect_x
eor_indirect_x:
    push rbx
    mov r12, rdi
    ADDR_INDIRECT_X
    mov r11, rbx
    call read_memory_byte
    xor al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    pop rbx
    mov eax, 6
    ret

global eor_indirect_y
eor_indirect_y:
    push rbx
    push r13
    mov r12, rdi
    ADDR_INDIRECT_Y
    mov r11, rbx
    call read_memory_byte
    xor al, [rdx]
    mov [rdx], al
    mov rdi, rcx
    call set_zn_flags
    mov eax, 5
    add eax, r13d
    pop r13
    pop rbx
    ret

; ASL — Arithmetic Shift Left: memory modes (RMW) — now uses write_memory_byte

; ASL Zeropage ($06) - 5 cycles
global asl_zeropage
asl_zeropage:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ZEROPAGE               ; rbx = zeropage address
    mov r13, rbx                ; preserve address

    mov r11, r13
    call read_memory_byte       ; read value
    test al, 0x80
    setnz r10b
    movzx esi, r10b
    push rdi
    mov rdi, rcx
    call set_carry_flag
    pop rdi

    shl al, 1                   ; modify in al
    mov r12b, al                ; r12b = new value

    mov rdi, rcx
    call set_zn_flags

    mov r11, r13                ; address in r11
    call write_memory_byte      ; write back via bus

    pop r13
    pop r12
    pop rbx
    mov eax, 5
    ret

; ASL Zeropage,X ($16) - 6 cycles
global asl_zeropage_x
asl_zeropage_x:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ZEROPAGE_X
    mov r13, rbx

    mov r11, r13
    call read_memory_byte
    test al, 0x80
    setnz r10b
    movzx esi, r10b
    push rdi
    mov rdi, rcx
    call set_carry_flag
    pop rdi

    shl al, 1
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

; ASL Absolute ($0E) - 6 cycles
global asl_absolute
asl_absolute:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ABSOLUTE
    mov r13, rbx

    mov r11, r13
    call read_memory_byte
    test al, 0x80
    setnz r10b
    movzx esi, r10b
    push rdi
    mov rdi, rcx
    call set_carry_flag
    pop rdi

    shl al, 1
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

; ASL Absolute,X ($1E) - 7 cycles
global asl_absolute_x
asl_absolute_x:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ABSOLUTE_X
    mov r13, rbx

    mov r11, r13
    call read_memory_byte
    test al, 0x80
    setnz r10b
    movzx esi, r10b
    push rdi
    mov rdi, rcx
    call set_carry_flag
    pop rdi

    shl al, 1
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

; LSR — Logical Shift Right: memory modes (RMW) — now uses write_memory_byte

; LSR Zeropage ($46) - 5 cycles
global lsr_zeropage
lsr_zeropage:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ZEROPAGE
    mov r13, rbx

    mov r11, r13
    call read_memory_byte
    test al, 0x01
    setnz r10b
    movzx esi, r10b
    push rdi
    mov rdi, rcx
    call set_carry_flag
    pop rdi

    shr al, 1
    mov r12b, al

    mov rdi, rcx
    call set_zn_flags
    and byte [rcx], 0x7F

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 5
    ret

; LSR Zeropage,X ($56) - 6 cycles
global lsr_zeropage_x
lsr_zeropage_x:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ZEROPAGE_X
    mov r13, rbx

    mov r11, r13
    call read_memory_byte
    test al, 0x01
    setnz r10b
    movzx esi, r10b
    push rdi
    mov rdi, rcx
    call set_carry_flag
    pop rdi

    shr al, 1
    mov r12b, al

    mov rdi, rcx
    call set_zn_flags
    and byte [rcx], 0x7F

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 6
    ret

; LSR Absolute ($4E) - 6 cycles
global lsr_absolute
lsr_absolute:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ABSOLUTE
    mov r13, rbx

    mov r11, r13
    call read_memory_byte
    test al, 0x01
    setnz r10b
    movzx esi, r10b
    push rdi
    mov rdi, rcx
    call set_carry_flag
    pop rdi

    shr al, 1
    mov r12b, al

    mov rdi, rcx
    call set_zn_flags
    and byte [rcx], 0x7F

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 6
    ret

; LSR Absolute,X ($5E) - 7 cycles
global lsr_absolute_x
lsr_absolute_x:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ABSOLUTE_X
    mov r13, rbx

    mov r11, r13
    call read_memory_byte
    test al, 0x01
    setnz r10b
    movzx esi, r10b
    push rdi
    mov rdi, rcx
    call set_carry_flag
    pop rdi

    shr al, 1
    mov r12b, al

    mov rdi, rcx
    call set_zn_flags
    and byte [rcx], 0x7F

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 7
    ret

; ROL — Rotate Left through carry: memory modes (RMW) — now uses write_memory_byte

; ROL Zeropage ($26) - 5 cycles
global rol_zeropage
rol_zeropage:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ZEROPAGE
    mov r13, rbx

    mov r11, r13
    call read_memory_byte
    movzx eax, al
    mov bl, al
    shr bl, 7                  ; new carry
    mov ah, [rcx]
    and ah, 0x01
    shl al, 1
    or al, ah
    mov r12b, al               ; new value

    movzx esi, bl
    push rdi
    mov rdi, rcx
    call set_carry_flag
    pop rdi

    mov rdi, rcx
    call set_zn_flags

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 5
    ret

; ROL Zeropage,X ($36) - 6 cycles
global rol_zeropage_x
rol_zeropage_x:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ZEROPAGE_X
    mov r13, rbx

    mov r11, r13
    call read_memory_byte
    movzx eax, al
    mov bl, al
    shr bl, 7
    mov ah, [rcx]
    and ah, 0x01
    shl al, 1
    or al, ah
    mov r12b, al

    movzx esi, bl
    push rdi
    mov rdi, rcx
    call set_carry_flag
    pop rdi

    mov rdi, rcx
    call set_zn_flags

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 6
    ret

; ROL Absolute ($2E) - 6 cycles
global rol_absolute
rol_absolute:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ABSOLUTE
    mov r13, rbx

    mov r11, r13
    call read_memory_byte
    movzx eax, al
    mov bl, al
    shr bl, 7
    mov ah, [rcx]
    and ah, 0x01
    shl al, 1
    or al, ah
    mov r12b, al

    movzx esi, bl
    push rdi
    mov rdi, rcx
    call set_carry_flag
    pop rdi

    mov rdi, rcx
    call set_zn_flags

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 6
    ret

; ROL Absolute,X ($3E) - 7 cycles
global rol_absolute_x
rol_absolute_x:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ABSOLUTE_X
    mov r13, rbx

    mov r11, r13
    call read_memory_byte
    movzx eax, al
    mov bl, al
    shr bl, 7
    mov ah, [rcx]
    and ah, 0x01
    shl al, 1
    or al, ah
    mov r12b, al

    movzx esi, bl
    push rdi
    mov rdi, rcx
    call set_carry_flag
    pop rdi

    mov rdi, rcx
    call set_zn_flags

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 7
    ret

; ROR — Rotate Right through carry: memory modes (RMW) — now uses write_memory_byte

; ROR Zeropage ($66) - 5 cycles
global ror_zeropage
ror_zeropage:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ZEROPAGE
    mov r13, rbx

    mov r11, r13
    call read_memory_byte
    movzx eax, al
    mov bl, al
    and bl, 0x01               ; new carry
    mov ah, [rcx]
    and ah, 0x01
    shl ah, 7
    shr al, 1
    or al, ah
    mov r12b, al

    movzx esi, bl
    push rdi
    mov rdi, rcx
    call set_carry_flag
    pop rdi

    mov rdi, rcx
    call set_zn_flags

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 5
    ret

; ROR Zeropage,X ($76) - 6 cycles
global ror_zeropage_x
ror_zeropage_x:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ZEROPAGE_X
    mov r13, rbx

    mov r11, r13
    call read_memory_byte
    movzx eax, al
    mov bl, al
    and bl, 0x01
    mov ah, [rcx]
    and ah, 0x01
    shl ah, 7
    shr al, 1
    or al, ah
    mov r12b, al

    movzx esi, bl
    push rdi
    mov rdi, rcx
    call set_carry_flag
    pop rdi

    mov rdi, rcx
    call set_zn_flags

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 6
    ret

; ROR Absolute ($6E) - 6 cycles
global ror_absolute
ror_absolute:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ABSOLUTE
    mov r13, rbx

    mov r11, r13
    call read_memory_byte
    movzx eax, al
    mov bl, al
    and bl, 0x01
    mov ah, [rcx]
    and ah, 0x01
    shl ah, 7
    shr al, 1
    or al, ah
    mov r12b, al

    movzx esi, bl
    push rdi
    mov rdi, rcx
    call set_carry_flag
    pop rdi

    mov rdi, rcx
    call set_zn_flags

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 6
    ret

; ROR Absolute,X ($7E) - 7 cycles
global ror_absolute_x
ror_absolute_x:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ABSOLUTE_X
    mov r13, rbx

    mov r11, r13
    call read_memory_byte
    movzx eax, al
    mov bl, al
    and bl, 0x01
    mov ah, [rcx]
    and ah, 0x01
    shl ah, 7
    shr al, 1
    or al, ah
    mov r12b, al

    movzx esi, bl
    push rdi
    mov rdi, rcx
    call set_carry_flag
    pop rdi

    mov rdi, rcx
    call set_zn_flags

    mov r11, r13
    call write_memory_byte

    pop r13
    pop r12
    pop rbx
    mov eax, 7
    ret

; Mark stack as non-executable
section .note.GNU-stack noalloc noexec nowrite progbits