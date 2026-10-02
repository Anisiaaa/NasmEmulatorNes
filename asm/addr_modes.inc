; addr_modes.inc — Addressing Mode Macros for the 6502 CPU Core
; NASM include file: %include "addr_modes.inc"
;
; Register convention (all macros assume this is set up by the caller):
;   rdi = 64 KB flat NES memory array base pointer
;   rsi = pointer to 16-bit PC (uint16_t* — dereference with [rsi])
;   rdx = pointer to A register
;   rcx = pointer to P (status flags) register
;   r8  = pointer to X register (byte)
;   r9  = pointer to Y register (byte)
;
; Output after each macro:
;   ADDR_IMMEDIATE  → al  = the fetched immediate byte; PC advanced by 1
;   all others      → rbx = the effective 16-bit address; PC advanced
;   ADDR_ABSOLUTE_X,
;   ADDR_ABSOLUTE_Y,
;   ADDR_INDIRECT_Y → r13d = 1 if a page boundary was crossed, else 0
;
; Scratch registers used internally (clobbered by macros):
;   rax, rbx, r10, r13   — callers that need them must save/restore
;
; rdi, rsi, rdx, rcx, r8, r9 are READ but NOT written by any macro.

%ifndef ADDR_MODES_INC
%define ADDR_MODES_INC

; ----------------------------------------------------------------------------
; ADDR_IMMEDIATE
; Reads the byte at [rdi + *PC] into al, then increments PC by 1.
; Result: al = fetched byte
; ----------------------------------------------------------------------------
%macro ADDR_IMMEDIATE 0
    movzx rbx, word [rsi]         ; rbx = PC (zero-extended to avoid stale bits)
    movzx eax, byte [rdi + rbx]   ; al  = memory[PC]
    inc bx                        ; PC += 1  (wraps within 16 bits via bx)
    mov word [rsi], bx            ; store updated PC
%endmacro

; ----------------------------------------------------------------------------
; ADDR_ZEROPAGE
; Reads the zeropage address byte at [rdi + *PC] into rbx,
; then increments PC by 1.
; Result: rbx = zero-page address (0x00–0xFF)
; ----------------------------------------------------------------------------
%macro ADDR_ZEROPAGE 0
    movzx rbx, word [rsi]         ; rbx = PC
    movzx rbx, byte [rdi + rbx]   ; rbx = memory[PC]  (zeropage address)
    inc word [rsi]                 ; PC += 1
%endmacro

; ----------------------------------------------------------------------------
; ADDR_ZEROPAGE_X
; Reads the zeropage base address, adds X with page-0 wrap (& 0xFF),
; stores the result in rbx, and increments PC by 1.
; Result: rbx = (base + X) & 0xFF
; ----------------------------------------------------------------------------
%macro ADDR_ZEROPAGE_X 0
    movzx rbx, word [rsi]         ; rbx = PC
    movzx rbx, byte [rdi + rbx]   ; rbx = base address byte from memory[PC]
    movzx r10, byte [r8]          ; r10 = X register value
    add rbx, r10                  ; rbx = base + X
    and rbx, 0xFF                 ; wrap within page 0
    inc word [rsi]                 ; PC += 1
%endmacro

; ----------------------------------------------------------------------------
; ADDR_ZEROPAGE_Y
; Same as ADDR_ZEROPAGE_X but uses Y instead of X.
; Result: rbx = (base + Y) & 0xFF
; ----------------------------------------------------------------------------
%macro ADDR_ZEROPAGE_Y 0
    movzx rbx, word [rsi]         ; rbx = PC
    movzx rbx, byte [rdi + rbx]   ; rbx = base address byte from memory[PC]
    movzx r10, byte [r9]          ; r10 = Y register value
    add rbx, r10                  ; rbx = base + Y
    and rbx, 0xFF                 ; wrap within page 0
    inc word [rsi]                 ; PC += 1
%endmacro

; ----------------------------------------------------------------------------
; ADDR_ABSOLUTE
; Reads two bytes little-endian from [rdi + *PC] and [rdi + *PC + 1],
; forms the 16-bit address in rbx, and increments PC by 2.
; Result: rbx = 16-bit absolute address
; ----------------------------------------------------------------------------
%macro ADDR_ABSOLUTE 0
    movzx rbx, word [rsi]         ; rbx = PC
    movzx rax, byte [rdi + rbx]   ; rax = low byte of address
    inc bx                        ; bx  = PC + 1 (points to high byte)
    movzx r10, byte [rdi + rbx]   ; r10 = high byte of address
    shl r10, 8
    or rax, r10                   ; rax = full 16-bit address
    inc bx                        ; bx  = PC + 2
    mov word [rsi], bx            ; store updated PC (PC += 2 total)
    mov rbx, rax                  ; rbx = effective address (AFTER PC update)
%endmacro

; ----------------------------------------------------------------------------
; ADDR_ABSOLUTE_X
; ABSOLUTE address + X; detects page crossing.
; Result: rbx = (base_addr + X) & 0xFFFF
;         r13d = 1 if high byte of (base_addr + X) != high byte of base_addr,
;                else 0
; ----------------------------------------------------------------------------
%macro ADDR_ABSOLUTE_X 0
    movzx rbx, word [rsi]         ; rbx = PC
    movzx rax, byte [rdi + rbx]   ; rax = low byte
    inc bx
    movzx r10, byte [rdi + rbx]   ; r10 = high byte
    shl r10, 8
    or rax, r10                   ; rax = base address
    inc bx
    mov word [rsi], bx            ; PC += 2

    ; Detect page crossing before adding X
    mov r13, rax                  ; r13 = base address (save high byte for check)

    movzx r10, byte [r8]          ; r10 = X
    add rax, r10                  ; rax = base + X
    and rax, 0xFFFF               ; keep within 16-bit address space

    ; Compare high bytes: (base >> 8) vs (result >> 8)
    mov rbx, rax                  ; rbx = effective address
    shr r13, 8                    ; r13 = base high byte
    mov r10, rax
    shr r10, 8                    ; r10 = result high byte
    xor r13, r10                  ; 0 if same page, non-zero if crossed
    setne r13b                    ; r13b = 1 if page crossed
    movzx r13d, r13b              ; zero-extend to 32 bits
%endmacro

; ----------------------------------------------------------------------------
; ADDR_ABSOLUTE_Y
; Same as ADDR_ABSOLUTE_X but uses Y.
; Result: rbx = (base_addr + Y) & 0xFFFF
;         r13d = 1 if page crossed, else 0
; ----------------------------------------------------------------------------
%macro ADDR_ABSOLUTE_Y 0
    movzx rbx, word [rsi]         ; rbx = PC
    movzx rax, byte [rdi + rbx]   ; rax = low byte
    inc bx
    movzx r10, byte [rdi + rbx]   ; r10 = high byte
    shl r10, 8
    or rax, r10                   ; rax = base address
    inc bx
    mov word [rsi], bx            ; PC += 2

    ; Detect page crossing before adding Y
    mov r13, rax                  ; r13 = base address

    movzx r10, byte [r9]          ; r10 = Y
    add rax, r10                  ; rax = base + Y
    and rax, 0xFFFF               ; keep within 16-bit space

    mov rbx, rax                  ; rbx = effective address
    shr r13, 8                    ; r13 = base high byte
    mov r10, rax
    shr r10, 8                    ; r10 = result high byte
    xor r13, r10
    setne r13b
    movzx r13d, r13b
%endmacro

; ----------------------------------------------------------------------------
; ADDR_INDIRECT_X   — (Indirect, X)  aka (zp,X)
; Reads the zeropage base byte at *PC, adds X with page-0 wrap to get a
; pointer address, then reads the 16-bit little-endian pointer stored at
; that zeropage location into rbx.  Increments PC by 1.
; Result: rbx = 16-bit effective address read from ([ptr_addr], [ptr_addr+1])
; ----------------------------------------------------------------------------
%macro ADDR_INDIRECT_X 0
    movzx rbx, word [rsi]         ; rbx = PC
    movzx rbx, byte [rdi + rbx]   ; rbx = zeropage base byte
    inc word [rsi]                 ; PC += 1

    movzx r10, byte [r8]          ; r10 = X
    add rbx, r10                  ; rbx = base + X
    and rbx, 0xFF                 ; wrap within page 0 → ptr_addr

    ; Read 16-bit pointer little-endian from zeropage
    movzx rax, byte [rdi + rbx]   ; rax = low byte of pointer
    lea r10, [rbx + 1]
    and r10, 0xFF                 ; (ptr_addr + 1) wraps within page 0
    movzx r10, byte [rdi + r10]   ; r10 = high byte of pointer
    shl r10, 8
    or rax, r10                   ; rax = full 16-bit target address
    mov rbx, rax                  ; rbx = effective address
%endmacro

; ----------------------------------------------------------------------------
; ADDR_INDIRECT_Y   — (Indirect), Y  aka (zp),Y
; Reads the zeropage base byte at *PC, reads the 16-bit pointer stored in
; zeropage at that address, adds Y to get the effective address, and sets
; the page-cross flag.  Increments PC by 1.
; Result: rbx  = 16-bit effective address (ptr + Y) & 0xFFFF
;         r13d = 1 if page crossed, else 0
; ----------------------------------------------------------------------------
%macro ADDR_INDIRECT_Y 0
    movzx rbx, word [rsi]         ; rbx = PC
    movzx rbx, byte [rdi + rbx]   ; rbx = zeropage base address byte
    inc word [rsi]                 ; PC += 1

    ; Read 16-bit little-endian pointer from zeropage
    movzx rax, byte [rdi + rbx]   ; rax = low byte of pointer
    lea r10, [rbx + 1]
    and r10, 0xFF                 ; (base + 1) wraps within page 0
    movzx r10, byte [rdi + r10]   ; r10 = high byte of pointer
    shl r10, 8
    or rax, r10                   ; rax = base pointer address

    ; Save base pointer high byte for page-cross detection
    mov r13, rax
    shr r13, 8                    ; r13 = pointer high byte (before Y add)

    movzx r10, byte [r9]          ; r10 = Y
    add rax, r10                  ; rax = ptr + Y
    and rax, 0xFFFF               ; stay within 16-bit space

    mov rbx, rax                  ; rbx = effective address

    ; Page-cross detection
    mov r10, rax
    shr r10, 8                    ; r10 = result high byte
    xor r13, r10
    setne r13b
    movzx r13d, r13b
%endmacro

%endif ; ADDR_MODES_INC
