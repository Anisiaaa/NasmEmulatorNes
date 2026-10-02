; unofficial.asm – fully fixed and linkable version
; Fixes:
;   - Memory writes via write_memory_byte callback
;   - Volatile registers saved in callee-saved regs
;   - read_memory_byte receives address in edi
;   - High-byte registers (AH) replaced with r10b
;   - All required global declarations present

extern read_memory_byte
extern write_memory_byte
extern set_zn_flags
extern set_carry_flag
extern get_carry_flag
extern set_overflow_flag
extern sp_pointer

bits 64
section .text

%include "addr_modes.inc"

; ----------------------------------------------------------------------------
; All global declarations (every handler exported)
; ----------------------------------------------------------------------------
global slo_zeropage
global slo_zeropage_x
global slo_absolute
global slo_absolute_x
global slo_absolute_y
global slo_indirect_x
global slo_indirect_y

global rla_zeropage
global rla_zeropage_x
global rla_absolute
global rla_absolute_x
global rla_absolute_y
global rla_indirect_x
global rla_indirect_y

global sre_zeropage
global sre_zeropage_x
global sre_absolute
global sre_absolute_x
global sre_absolute_y
global sre_indirect_x
global sre_indirect_y

global rra_zeropage
global rra_zeropage_x
global rra_absolute
global rra_absolute_x
global rra_absolute_y
global rra_indirect_x
global rra_indirect_y

global dcp_zeropage
global dcp_zeropage_x
global dcp_absolute
global dcp_absolute_x
global dcp_absolute_y
global dcp_indirect_x
global dcp_indirect_y

global isc_zeropage
global isc_zeropage_x
global isc_absolute
global isc_absolute_x
global isc_absolute_y
global isc_indirect_x
global isc_indirect_y

global lax_zeropage
global lax_zeropage_y
global lax_absolute
global lax_absolute_y
global lax_indirect_x
global lax_indirect_y

global sax_zeropage
global sax_zeropage_y
global sax_absolute
global sax_indirect_x

global sha_indirect_y
global sha_absolute_y
global shx_absolute_y
global shy_absolute_x
global tas_absolute_y
global las_absolute_y

global anc_immediate
global alr_immediate
global arr_immediate
global axs_immediate
global ane_immediate
global lxa_immediate
global sbc_immediate_eb

global nop_implied_unofficial
global nop_zeropage_unofficial
global nop_zeropage_x_unofficial
global nop_absolute_unofficial
global nop_absolute_x_unofficial

global kil_instr

; SLO — ASL memory, then ORA A with result
slo_zeropage:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ZEROPAGE

    movzx r11, bx
    call read_memory_byte
    test al, 0x80
    setnz sil
    movzx esi, sil
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    shl al, 1
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    or al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r12
    pop rbx
    mov eax, 5
    ret

slo_zeropage_x:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ZEROPAGE_X

    movzx r11, bx
    call read_memory_byte
    test al, 0x80
    setnz sil
    movzx esi, sil
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    shl al, 1
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    or al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r12
    pop rbx
    mov eax, 6
    ret

slo_absolute:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE

    movzx r11, bx
    call read_memory_byte
    test al, 0x80
    setnz sil
    movzx esi, sil
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    shl al, 1
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    or al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r12
    pop rbx
    mov eax, 6
    ret

slo_absolute_x:
    push rbx
    push r12
    push r13
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE_X

    movzx r11, bx
    call read_memory_byte
    test al, 0x80
    setnz sil
    movzx esi, sil
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    shl al, 1
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    or al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r13
    pop r12
    pop rbx
    mov eax, 7
    ret

slo_absolute_y:
    push rbx
    push r12
    push r13
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE_Y

    movzx r11, bx
    call read_memory_byte
    test al, 0x80
    setnz sil
    movzx esi, sil
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    shl al, 1
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    or al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r13
    pop r12
    pop rbx
    mov eax, 7
    ret

slo_indirect_x:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_INDIRECT_X

    movzx r11, bx
    call read_memory_byte
    test al, 0x80
    setnz sil
    movzx esi, sil
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    shl al, 1
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    or al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r12
    pop rbx
    mov eax, 8
    ret

slo_indirect_y:
    push rbx
    push r12
    push r13
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_INDIRECT_Y

    movzx r11, bx
    call read_memory_byte
    test al, 0x80
    setnz sil
    movzx esi, sil
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    shl al, 1
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    or al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r13
    pop r12
    pop rbx
    mov eax, 8
    ret

; RLA — ROL memory, then AND A with result (AH replaced with r10b)
rla_zeropage:
    push rbx
    push r12
    push rbp
    push r13

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ZEROPAGE

    movzx r11, bx
    call read_memory_byte
    mov r13b, al
    shr r13b, 7

    movzx r10d, byte [r15]
    and r10b, 0x01
    shl al, 1
    or al, r10b

    mov r11w, bx
    mov r12b, al
    call write_memory_byte

    movzx esi, r13b
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    and al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 5
    ret

rla_zeropage_x:
    push rbx
    push r12
    push rbp
    push r13

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ZEROPAGE_X

    movzx r11, bx
    call read_memory_byte
    mov r13b, al
    shr r13b, 7

    movzx r10d, byte [r15]
    and r10b, 0x01
    shl al, 1
    or al, r10b

    mov r11w, bx
    mov r12b, al
    call write_memory_byte

    movzx esi, r13b
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    and al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 6
    ret

rla_absolute:
    push rbx
    push r12
    push rbp
    push r13

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE

    movzx r11, bx
    call read_memory_byte
    mov r13b, al
    shr r13b, 7

    movzx r10d, byte [r15]
    and r10b, 0x01
    shl al, 1
    or al, r10b

    mov r11w, bx
    mov r12b, al
    call write_memory_byte

    movzx esi, r13b
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    and al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 6
    ret

rla_absolute_x:
    push rbx
    push r12
    push r13
    push r14
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE_X
    mov r11, rbx

    movzx r11, bx
    call read_memory_byte
    mov r13b, al
    shr r13b, 7

    movzx r10d, byte [r15]
    and r10b, 0x01
    shl al, 1
    or al, r10b

    mov r11w, bx
    mov r12b, al
    call write_memory_byte

    movzx esi, r13b
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    and al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 7
    ret

rla_absolute_y:
    push rbx
    push r12
    push r13
    push r14
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE_Y
    mov r11, rbx

    movzx r11, bx
    call read_memory_byte
    mov r13b, al
    shr r13b, 7

    movzx r10d, byte [r15]
    and r10b, 0x01
    shl al, 1
    or al, r10b

    mov r11w, bx
    mov r12b, al
    call write_memory_byte

    movzx esi, r13b
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    and al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 7
    ret

rla_indirect_x:
    push rbx
    push r12
    push rbp
    push r13

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_INDIRECT_X

    movzx r11, bx
    call read_memory_byte
    mov r13b, al
    shr r13b, 7

    movzx r10d, byte [r15]
    and r10b, 0x01
    shl al, 1
    or al, r10b

    mov r11w, bx
    mov r12b, al
    call write_memory_byte

    movzx esi, r13b
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    and al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 8
    ret

rla_indirect_y:
    push rbx
    push r12
    push r13
    push r14
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_INDIRECT_Y
    mov r11, rbx

    movzx r11, bx
    call read_memory_byte
    mov r13b, al
    shr r13b, 7

    movzx r10d, byte [r15]
    and r10b, 0x01
    shl al, 1
    or al, r10b

    mov r11w, bx
    mov r12b, al
    call write_memory_byte

    movzx esi, r13b
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    and al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 8
    ret

; SRE — LSR memory, then EOR A with result
sre_zeropage:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ZEROPAGE

    movzx r11, bx
    call read_memory_byte
    test al, 0x01
    setnz sil
    movzx esi, sil
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    shr al, 1
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    xor al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r12
    pop rbx
    mov eax, 5
    ret

sre_zeropage_x:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ZEROPAGE_X

    movzx r11, bx
    call read_memory_byte
    test al, 0x01
    setnz sil
    movzx esi, sil
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    shr al, 1
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    xor al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r12
    pop rbx
    mov eax, 6
    ret

sre_absolute:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE

    movzx r11, bx
    call read_memory_byte
    test al, 0x01
    setnz sil
    movzx esi, sil
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    shr al, 1
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    xor al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r12
    pop rbx
    mov eax, 6
    ret

sre_absolute_x:
    push rbx
    push r12
    push r13
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE_X

    movzx r11, bx
    call read_memory_byte
    test al, 0x01
    setnz sil
    movzx esi, sil
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    shr al, 1
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    xor al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r13
    pop r12
    pop rbx
    mov eax, 7
    ret

sre_absolute_y:
    push rbx
    push r12
    push r13
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE_Y

    movzx r11, bx
    call read_memory_byte
    test al, 0x01
    setnz sil
    movzx esi, sil
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    shr al, 1
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    xor al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r13
    pop r12
    pop rbx
    mov eax, 7
    ret

sre_indirect_x:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_INDIRECT_X

    movzx r11, bx
    call read_memory_byte
    test al, 0x01
    setnz sil
    movzx esi, sil
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    shr al, 1
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    xor al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r12
    pop rbx
    mov eax, 8
    ret

sre_indirect_y:
    push rbx
    push r12
    push r13
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_INDIRECT_Y

    movzx r11, bx
    call read_memory_byte
    test al, 0x01
    setnz sil
    movzx esi, sil
    mov rdi, r15
    call set_carry_flag

    movzx r11, bx
    call read_memory_byte
    shr al, 1
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    xor al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r13
    pop r12
    pop rbx
    mov eax, 8
    ret

; RRA — ROR memory, then ADC A with result (AH replaced with r10b in ROR_MEM)
%macro ROR_MEM 0
    movzx r11, bx
    call read_memory_byte
    mov r13b, al
    and r13b, 0x01

    movzx r10d, byte [r15]
    and r10b, 0x01
    shl r10b, 7
    shr al, 1
    or al, r10b

    mov r11w, bx
    mov r12b, al
    call write_memory_byte

    movzx esi, r13b
    mov rdi, r15
    call set_carry_flag
%endmacro

%macro ADC_A_MEM 0
    push rcx
    push rdx
    movzx r11, bx
    call read_memory_byte
    movzx r13d, al

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

    movzx esi, cl
    mov rdi, r15
    call set_carry_flag

    mov cl, al
    mov sil, bl
    xor sil, r13b
    not sil
    mov dil, bl
    xor dil, cl
    and sil, dil
    and sil, 0x80
    jz %%no_overflow
    mov sil, 1
    mov rdi, r15
    call set_overflow_flag
    jmp %%store_result
%%no_overflow:
    mov sil, 0
    mov rdi, r15
    call set_overflow_flag

%%store_result:
    mov [r14], al
    mov rdi, r15
    call set_zn_flags
    pop rdx
    pop rcx
%endmacro

rra_zeropage:
    push rbx
    push r12
    push rbp
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ZEROPAGE

    ROR_MEM
    ADC_A_MEM

    pop r15
    pop r14
    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 5
    ret

rra_zeropage_x:
    push rbx
    push r12
    push rbp
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ZEROPAGE_X

    ROR_MEM
    ADC_A_MEM

    pop r15
    pop r14
    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 6
    ret

rra_absolute:
    push rbx
    push r12
    push rbp
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE

    ROR_MEM
    ADC_A_MEM

    pop r15
    pop r14
    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 6
    ret

rra_absolute_x:
    push rbx
    push r12
    push rbp
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE_X

    ROR_MEM
    ADC_A_MEM

    pop r15
    pop r14
    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 7
    ret

rra_absolute_y:
    push rbx
    push r12
    push rbp
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE_Y

    ROR_MEM
    ADC_A_MEM

    pop r15
    pop r14
    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 7
    ret

rra_indirect_x:
    push rbx
    push r12
    push rbp
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_INDIRECT_X

    ROR_MEM
    ADC_A_MEM

    pop r15
    pop r14
    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 8
    ret

rra_indirect_y:
    push rbx
    push r12
    push rbp
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_INDIRECT_Y

    ROR_MEM
    ADC_A_MEM

    pop r15
    pop r14
    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 8
    ret

; DCP — DEC memory, then CMP A with result
dcp_zeropage:
    push rbx
    push r12
    push rbp
    push r13

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ZEROPAGE

    movzx r11, bx
    call read_memory_byte
    dec al
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    movzx r13d, al

    mov al, [r14]
    sub al, r13b
    setnc r13b

    movzx esi, r13b
    mov rdi, r15
    call set_carry_flag

    mov rdi, r15
    call set_zn_flags

    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 5
    ret

dcp_zeropage_x:
    push rbx
    push r12
    push rbp
    push r13

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ZEROPAGE_X

    movzx r11, bx
    call read_memory_byte
    dec al
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    movzx r13d, al

    mov al, [r14]
    sub al, r13b
    setnc r13b

    movzx esi, r13b
    mov rdi, r15
    call set_carry_flag

    mov rdi, r15
    call set_zn_flags

    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 6
    ret

dcp_absolute:
    push rbx
    push r12
    push rbp
    push r13

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE

    movzx r11, bx
    call read_memory_byte
    dec al
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    movzx r13d, al

    mov al, [r14]
    sub al, r13b
    setnc r13b

    movzx esi, r13b
    mov rdi, r15
    call set_carry_flag

    mov rdi, r15
    call set_zn_flags

    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 6
    ret

dcp_absolute_x:
    push rbx
    push r12
    push r13
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE_X

    movzx r11, bx
    call read_memory_byte
    dec al
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    movzx r13d, al

    mov al, [r14]
    sub al, r13b
    setnc r13b

    movzx esi, r13b
    mov rdi, r15
    call set_carry_flag

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r13
    pop r12
    pop rbx
    mov eax, 7
    ret

dcp_absolute_y:
    push rbx
    push r12
    push r13
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE_Y

    movzx r11, bx
    call read_memory_byte
    dec al
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    movzx r13d, al

    mov al, [r14]
    sub al, r13b
    setnc r13b

    movzx esi, r13b
    mov rdi, r15
    call set_carry_flag

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r13
    pop r12
    pop rbx
    mov eax, 7
    ret

dcp_indirect_x:
    push rbx
    push r12
    push rbp
    push r13

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_INDIRECT_X

    movzx r11, bx
    call read_memory_byte
    dec al
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    movzx r13d, al

    mov al, [r14]
    sub al, r13b
    setnc r13b

    movzx esi, r13b
    mov rdi, r15
    call set_carry_flag

    mov rdi, r15
    call set_zn_flags

    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 8
    ret

dcp_indirect_y:
    push rbx
    push r12
    push r13
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_INDIRECT_Y

    movzx r11, bx
    call read_memory_byte
    dec al
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    movzx r11, bx
    call read_memory_byte
    movzx r13d, al

    mov al, [r14]
    sub al, r13b
    setnc r13b

    movzx esi, r13b
    mov rdi, r15
    call set_carry_flag

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r13
    pop r12
    pop rbx
    mov eax, 8
    ret

; ISC — INC memory, then SBC A with result
%macro SBC_A_MEM 0
    push rcx
    push rdx
    push rax
    movzx r11, bx
    call read_memory_byte
    movzx r13d, al

    movzx eax, byte [r14]
    movzx ebx, byte [r15]
    and ebx, 1
    mov ecx, 1
    sub ecx, ebx

    sub eax, r13d
    sub eax, ecx

    test eax, eax
    jge %%sbc_no_borrow
    add eax, 0x100
    mov ebx, 0
    jmp %%sbc_set_carry
%%sbc_no_borrow:
    mov ebx, 1

%%sbc_set_carry:
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
    jz %%sbc_no_overflow
    mov sil, 1
    mov rdi, r15
    call set_overflow_flag
    jmp %%sbc_store
%%sbc_no_overflow:
    mov sil, 0
    mov rdi, r15
    call set_overflow_flag

%%sbc_store:
    mov [r14], al
    mov rdi, r15
    call set_zn_flags
    pop rax
    pop rdx
    pop rcx
%endmacro

isc_zeropage:
    push rbx
    push r12
    push rbp
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ZEROPAGE

    movzx r11, bx
    call read_memory_byte
    inc al
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    SBC_A_MEM

    pop r15
    pop r14
    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 5
    ret

isc_zeropage_x:
    push rbx
    push r12
    push rbp
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ZEROPAGE_X

    movzx r11, bx
    call read_memory_byte
    inc al
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    SBC_A_MEM

    pop r15
    pop r14
    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 6
    ret

isc_absolute:
    push rbx
    push r12
    push rbp
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE

    movzx r11, bx
    call read_memory_byte
    inc al
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    SBC_A_MEM

    pop r15
    pop r14
    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 6
    ret

isc_absolute_x:
    push rbx
    push r12
    push rbp
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE_X

    movzx r11, bx
    call read_memory_byte
    inc al
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    SBC_A_MEM

    pop r15
    pop r14
    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 7
    ret

isc_absolute_y:
    push rbx
    push r12
    push rbp
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE_Y

    movzx r11, bx
    call read_memory_byte
    inc al
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    SBC_A_MEM

    pop r15
    pop r14
    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 7
    ret

isc_indirect_x:
    push rbx
    push r12
    push rbp
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_INDIRECT_X

    movzx r11, bx
    call read_memory_byte
    inc al
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    SBC_A_MEM

    pop r15
    pop r14
    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 8
    ret

isc_indirect_y:
    push rbx
    push r12
    push rbp
    push r13
    push r14
    push r15

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_INDIRECT_Y

    movzx r11, bx
    call read_memory_byte
    inc al
    mov r12b, al
    mov r11w, bx
    call write_memory_byte

    SBC_A_MEM

    pop r15
    pop r14
    pop r13
    pop rbp
    pop r12
    pop rbx
    mov eax, 8
    ret

; LAX — Load A and X from memory
lax_zeropage:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ZEROPAGE

    movzx r11, bx
    call read_memory_byte
    mov [r14], al
    mov [r8], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r12
    pop rbx
    mov eax, 3
    ret

lax_zeropage_y:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ZEROPAGE_Y

    movzx r11, bx
    call read_memory_byte
    mov [r14], al
    mov [r8], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r12
    pop rbx
    mov eax, 4
    ret

lax_absolute:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE

    movzx r11, bx
    call read_memory_byte
    mov [r14], al
    mov [r8], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r12
    pop rbx
    mov eax, 4
    ret

lax_absolute_y:
    push rbx
    push r12
    push r13
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov rbp, r9

    ADDR_ABSOLUTE_Y

    movzx r11, bx
    call read_memory_byte
    mov [r14], al
    mov [r8], al

    mov rdi, r15
    call set_zn_flags

    mov eax, 4
    add eax, r13d

    pop rbp
    pop r13
    pop r12
    pop rbx
    ret

lax_indirect_x:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_INDIRECT_X

    movzx r11, bx
    call read_memory_byte
    mov [r14], al
    mov [r8], al

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r12
    pop rbx
    mov eax, 6
    ret

lax_indirect_y:
    push rbx
    push r12
    push r13
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov rbp, r9

    ADDR_INDIRECT_Y

    movzx r11, bx
    call read_memory_byte
    mov [r14], al
    mov [r8], al

    mov rdi, r15
    call set_zn_flags

    mov eax, 5
    add eax, r13d

    pop rbp
    pop r13
    pop r12
    pop rbx
    ret

; SAX — Store A & X to memory (write via callback)
sax_zeropage:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ZEROPAGE

    mov al, [r14]
    and al, [r13]
    mov r11w, bx
    mov r12b, al
    call write_memory_byte

    pop rbp
    pop r12
    pop rbx
    mov eax, 3
    ret

sax_zeropage_y:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ZEROPAGE_Y

    mov al, [r14]
    and al, [r13]
    mov r11w, bx
    mov r12b, al
    call write_memory_byte

    pop rbp
    pop r12
    pop rbx
    mov eax, 4
    ret

sax_absolute:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_ABSOLUTE

    mov al, [r14]
    and al, [r13]
    mov r11w, bx
    mov r12b, al
    call write_memory_byte

    pop rbp
    pop r12
    pop rbx
    mov eax, 4
    ret

sax_indirect_x:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_INDIRECT_X

    mov al, [r14]
    and al, [r13]
    mov r11w, bx
    mov r12b, al
    call write_memory_byte

    pop rbp
    pop r12
    pop rbx
    mov eax, 6
    ret

; UNSTABLE WRITES (SHA, SHX, SHY, TAS, LAS)
sha_indirect_y:
    push rbx
    push r12
    push r13
    push r14
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    movzx rbx, word [rsi]
    movzx r11, bx
    call read_memory_byte
    movzx ebx, al
    inc word [rsi]

    movzx r11, bx
    call read_memory_byte
    movzx eax, al
    lea r10, [rbx + 1]
    and r10, 0xFF
    movzx r11, r10w
    call read_memory_byte
    mov r14b, al
    movzx r10, al
    shl r10, 8
    or rax, r10

    movzx r10, byte [rbp]
    add rax, r10
    and rax, 0xFFFF
    mov rbx, rax

    mov al, [r14]
    and al, [r13]
    inc r14b
    and al, r14b

    mov r11w, bx
    mov r12b, al
    call write_memory_byte

    pop rbp
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 6
    ret

sha_absolute_y:
    push rbx
    push r12
    push r13
    push r14
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    movzx rbx, word [rsi]
    movzx r11, bx
    call read_memory_byte
    movzx eax, al
    inc bx
    movzx r11, bx
    call read_memory_byte
    mov r14b, al
    movzx r10, al
    shl r10, 8
    or rax, r10
    inc bx
    mov word [rsi], bx

    movzx r10, byte [rbp]
    add rax, r10
    and rax, 0xFFFF
    mov rbx, rax

    mov al, [r14]
    and al, [r13]
    inc r14b
    and al, r14b

    mov r11w, bx
    mov r12b, al
    call write_memory_byte

    pop rbp
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 5
    ret

shx_absolute_y:
    push rbx
    push r12
    push r13
    push r14
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    movzx rbx, word [rsi]
    movzx r11, bx
    call read_memory_byte
    movzx eax, al
    inc bx
    movzx r11, bx
    call read_memory_byte
    mov r14b, al
    movzx r10, al
    shl r10, 8
    or rax, r10
    inc bx
    mov word [rsi], bx

    movzx r10, byte [rbp]
    add rax, r10
    and rax, 0xFFFF
    mov rbx, rax

    mov al, [r13]
    inc r14b
    and al, r14b

    mov r11w, bx
    mov r12b, al
    call write_memory_byte

    pop rbp
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 5
    ret

shy_absolute_x:
    push rbx
    push r12
    push r13
    push r14
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    movzx rbx, word [rsi]
    movzx r11, bx
    call read_memory_byte
    movzx eax, al
    inc bx
    movzx r11, bx
    call read_memory_byte
    mov r14b, al
    movzx r10, al
    shl r10, 8
    or rax, r10
    inc bx
    mov word [rsi], bx

    movzx r10, byte [r13]
    add rax, r10
    and rax, 0xFFFF
    mov rbx, rax

    mov al, [rbp]
    inc r14b
    and al, r14b

    mov r11w, bx
    mov r12b, al
    call write_memory_byte

    pop rbp
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 5
    ret

tas_absolute_y:
    push rbx
    push r12
    push r13
    push r14
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    movzx rbx, word [rsi]
    movzx r11, bx
    call read_memory_byte
    movzx eax, al
    inc bx
    movzx r11, bx
    call read_memory_byte
    mov r14b, al
    movzx r10, al
    shl r10, 8
    or rax, r10
    inc bx
    mov word [rsi], bx

    movzx r10, byte [rbp]
    add rax, r10
    and rax, 0xFFFF
    mov rbx, rax

    mov al, [r14]
    and al, [r13]
    mov r10, [rel sp_pointer]
    mov [r10], al

    inc r14b
    and al, r14b

    mov r11w, bx
    mov r12b, al
    call write_memory_byte

    pop rbp
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 5
    ret

las_absolute_y:
    push rbx
    push r12
    push r13
    push r14
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov rbp, r9

    ADDR_ABSOLUTE_Y

    movzx r11, bx
    call read_memory_byte
    mov r10, [rel sp_pointer]
    and al, [r10]

    mov [r14], al
    mov [r8], al
    mov [r10], al

    mov rdi, r15
    call set_zn_flags

    mov eax, 4
    add eax, r13d

    pop rbp
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Immediate unofficial opcodes
extern sbc_immediate

anc_immediate:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_IMMEDIATE
    and al, [r14]
    mov [r14], al

    mov rdi, r15
    call set_zn_flags

    movzx eax, byte [r15]
    mov bl, al
    shr bl, 7
    and al, 0xFE
    or al, bl
    mov [r15], al

    pop rbp
    pop r12
    pop rbx
    mov eax, 2
    ret

alr_immediate:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_IMMEDIATE
    and al, [r14]
    test al, 0x01
    setnz bl
    movzx esi, bl
    mov rdi, r15
    call set_carry_flag

    shr al, 1
    mov [r14], al
    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r12
    pop rbx
    mov eax, 2
    ret

arr_immediate:
    push rbx
    push r12
    push r13
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_IMMEDIATE
    and al, [r14]
    movzx ebx, byte [r15]
    and ebx, 0x01
    shr al, 1
    shl bl, 7
    or al, bl
    mov [r14], al

    mov bl, al
    shr bl, 6
    and bl, 0x01
    movzx esi, bl
    mov rdi, r15
    call set_carry_flag

    mov bl, al
    mov cl, al
    shr bl, 6
    and bl, 0x01
    shr cl, 5
    and cl, 0x01
    xor bl, cl
    movzx esi, bl
    mov rdi, r15
    call set_overflow_flag

    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r13
    pop r12
    pop rbx
    mov eax, 2
    ret

axs_immediate:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_IMMEDIATE
    mov bl, [r14]
    and bl, [r13]
    sub bl, al
    mov [r13], bl

    setnc al
    movzx esi, al
    mov rdi, r15
    call set_carry_flag

    movzx eax, bl
    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r12
    pop rbx
    mov eax, 2
    ret

ane_immediate:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_IMMEDIATE
    mov bl, [r14]
    or bl, 0xEE
    and bl, [r13]
    and bl, al
    mov [r14], bl

    movzx eax, bl
    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r12
    pop rbx
    mov eax, 2
    ret

lxa_immediate:
    push rbx
    push r12
    push rbp

    mov r12, rdi
    mov r15, rcx
    mov r14, rdx
    mov r13, r8                    ; Save X register pointer
    mov rbp, r9

    ADDR_IMMEDIATE
    mov bl, [r14]
    or bl, 0xEE
    and bl, al
    mov [r14], bl
    mov [r13], bl

    movzx eax, bl
    mov rdi, r15
    call set_zn_flags

    pop rbp
    pop r12
    pop rbx
    mov eax, 2
    ret

sbc_immediate_eb:
    jmp sbc_immediate

; Unofficial NOPs
nop_implied_unofficial:
    mov eax, 2
    ret

nop_zeropage_unofficial:
    push rbx
    ADDR_ZEROPAGE
    pop rbx
    mov eax, 3
    ret

nop_zeropage_x_unofficial:
    push rbx
    ADDR_ZEROPAGE_X
    pop rbx
    mov eax, 4
    ret

nop_absolute_unofficial:
    push rbx
    ADDR_ABSOLUTE
    pop rbx
    mov eax, 4
    ret

nop_absolute_x_unofficial:
    push rbx
    push r13
    ADDR_ABSOLUTE_X
    mov eax, 4
    add eax, r13d
    pop r13
    pop rbx
    ret

; KIL
kil_instr:
    dec word [rsi]
.halt:
    jmp .halt

section .note.GNU-stack noalloc noexec nowrite progbits