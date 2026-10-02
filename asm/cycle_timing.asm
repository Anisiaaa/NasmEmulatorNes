

%ifndef ADDR_MODES_INC
%define ADDR_MODES_INC

; External function for memory reads via callback
extern read_memory_byte

; ----------------------------------------------------------------------------
; ADDR_IMMEDIATE
; Reads the byte at memory[*PC] via callback into al, then increments PC by 1.
; Result: al = fetched byte
; ----------------------------------------------------------------------------
%macro ADDR_IMMEDIATE 0
    movzx r11, word [rsi]         ; r11 = PC (address for read_memory_byte)
    call read_memory_byte         ; al = memory[PC] via callback
    movzx rbx, word [rsi]         ; rbx = PC for increment
    inc bx                        ; PC += 1  (wraps within 16 bits via bx)
    mov word [rsi], bx            ; store updated PC
%endmacro

; ----------------------------------------------------------------------------
; ADDR_ZEROPAGE
; Reads the zeropage address byte at memory[*PC] via callback into rbx,
; then increments PC by 1.
; Result: rbx = zero-page address (0x00–0xFF)
; ----------------------------------------------------------------------------
%macro ADDR_ZEROPAGE 0
    movzx r11, word [rsi]         ; r11 = PC (address for read_memory_byte)
    call read_memory_byte         ; al = memory[PC] via callback
    movzx rbx, al                 ; rbx = zeropage address
    movzx r10, word [rsi]         ; r10 = PC for increment
    inc r10w                      ; PC += 1
    mov word [rsi], r10w          ; store updated PC
%endmacro

; ----------------------------------------------------------------------------
; ADDR_ZEROPAGE_X
; Reads the zeropage base address via callback, adds X with page-0 wrap (& 0xFF),
; stores the result in rbx, and increments PC by 1.
; Result: rbx = (base + X) & 0xFF
; ----------------------------------------------------------------------------
%macro ADDR_ZEROPAGE_X 0
    movzx r11, word [rsi]         ; r11 = PC (address for read_memory_byte)
    call read_memory_byte         ; al = base address byte from memory[PC]
    movzx rbx, al                 ; rbx = base address
    movzx r10, byte [r8]          ; r10 = X register value
    add rbx, r10                  ; rbx = base + X
    and rbx, 0xFF                 ; wrap within page 0
    movzx r10, word [rsi]         ; r10 = PC for increment
    inc r10w                      ; PC += 1
    mov word [rsi], r10w          ; store updated PC
%endmacro

; ----------------------------------------------------------------------------
; ADDR_ZEROPAGE_Y
; Same as ADDR_ZEROPAGE_X but uses Y instead of X.
; Result: rbx = (base + Y) & 0xFF
; ----------------------------------------------------------------------------
%macro ADDR_ZEROPAGE_Y 0
    movzx r11, word [rsi]         ; r11 = PC (address for read_memory_byte)
    call read_memory_byte         ; al = base address byte from memory[PC]
    movzx rbx, al                 ; rbx = base address
    movzx r10, byte [r9]          ; r10 = Y register value
    add rbx, r10                  ; rbx = base + Y
    and rbx, 0xFF                 ; wrap within page 0
    movzx r10, word [rsi]         ; r10 = PC for increment
    inc r10w                      ; PC += 1
    mov word [rsi], r10w          ; store updated PC
%endmacro

; ----------------------------------------------------------------------------
; ADDR_ABSOLUTE
; Reads two bytes little-endian from memory[*PC] and memory[*PC + 1] via callback,
; forms the 16-bit address in rbx, and increments PC by 2.
; Result: rbx = 16-bit absolute address
; ----------------------------------------------------------------------------
%macro ADDR_ABSOLUTE 0
    ; Read low byte via callback
    movzx r11, word [rsi]         ; r11 = PC
    call read_memory_byte         ; al = low byte of address
    movzx rax, al                 ; rax = low byte
    
    ; Increment PC and read high byte
    movzx r10, word [rsi]         ; r10 = PC
    inc r10w                      ; r10 = PC + 1
    mov word [rsi], r10w          ; store updated PC
    movzx r11, r10w               ; r11 = PC + 1
    call read_memory_byte         ; al = high byte of address
    movzx r10, al                 ; r10 = high byte
    shl r10, 8
    or rax, r10                   ; rax = full 16-bit address
    
    ; Increment PC again (PC += 2 total)
    movzx r10, word [rsi]         ; r10 = PC
    inc r10w                      ; r10 = PC + 2
    mov word [rsi], r10w          ; store updated PC
    
    mov rbx, rax                  ; rbx = effective address
%endmacro

; ----------------------------------------------------------------------------
; ADDR_ABSOLUTE_X
; ABSOLUTE address + X; detects page crossing.
; Result: rbx = (base_addr + X) & 0xFFFF
;         r13d = 1 if high byte of (base_addr + X) != high byte of base_addr,
;                else 0
; ----------------------------------------------------------------------------
%macro ADDR_ABSOLUTE_X 0
    ; Read low byte via callback
    movzx r11, word [rsi]         ; r11 = PC
    call read_memory_byte         ; al = low byte
    movzx rax, al                 ; rax = low byte
    
    ; Increment PC and read high byte
    movzx r10, word [rsi]         ; r10 = PC
    inc r10w                      ; r10 = PC + 1
    mov word [rsi], r10w          ; store updated PC
    movzx r11, r10w               ; r11 = PC + 1
    call read_memory_byte         ; al = high byte
    movzx r10, al                 ; r10 = high byte
    shl r10, 8
    or rax, r10                   ; rax = base address
    
    ; Increment PC again (PC += 2 total)
    movzx r10, word [rsi]         ; r10 = PC
    inc r10w                      ; r10 = PC + 2
    mov word [rsi], r10w          ; store updated PC

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
    ; Read low byte via callback
    movzx r11, word [rsi]         ; r11 = PC
    call read_memory_byte         ; al = low byte
    movzx rax, al                 ; rax = low byte
    
    ; Increment PC and read high byte
    movzx r10, word [rsi]         ; r10 = PC
    inc r10w                      ; r10 = PC + 1
    mov word [rsi], r10w          ; store updated PC
    movzx r11, r10w               ; r11 = PC + 1
    call read_memory_byte         ; al = high byte
    movzx r10, al                 ; r10 = high byte
    shl r10, 8
    or rax, r10                   ; rax = base address
    
    ; Increment PC again (PC += 2 total)
    movzx r10, word [rsi]         ; r10 = PC
    inc r10w                      ; r10 = PC + 2
    mov word [rsi], r10w          ; store updated PC

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
; Reads the zeropage base byte at *PC via callback, adds X with page-0 wrap to get a
; pointer address, then reads the 16-bit little-endian pointer stored at
; that zeropage location into rbx.  Increments PC by 1.
; Result: rbx = 16-bit effective address read from ([ptr_addr], [ptr_addr+1])
; ----------------------------------------------------------------------------
%macro ADDR_INDIRECT_X 0
    ; Read zeropage base byte via callback
    movzx r11, word [rsi]         ; r11 = PC
    call read_memory_byte         ; al = zeropage base byte
    movzx rbx, al                 ; rbx = zeropage base
    
    ; Increment PC
    movzx r10, word [rsi]         ; r10 = PC
    inc r10w                      ; PC += 1
    mov word [rsi], r10w          ; store updated PC

    movzx r10, byte [r8]          ; r10 = X
    add rbx, r10                  ; rbx = base + X
    and rbx, 0xFF                 ; wrap within page 0 → ptr_addr

    ; Read 16-bit pointer little-endian from zeropage via callback
    mov r11, rbx                  ; r11 = ptr_addr
    call read_memory_byte         ; al = low byte of pointer
    movzx rax, al                 ; rax = low byte
    
    lea r10, [rbx + 1]
    and r10, 0xFF                 ; (ptr_addr + 1) wraps within page 0
    mov r11, r10                  ; r11 = ptr_addr + 1
    call read_memory_byte         ; al = high byte of pointer
    movzx r10, al                 ; r10 = high byte
    shl r10, 8
    or rax, r10                   ; rax = full 16-bit target address
    mov rbx, rax                  ; rbx = effective address
%endmacro

; ----------------------------------------------------------------------------
; ADDR_INDIRECT_Y   — (Indirect), Y  aka (zp),Y
; Reads the zeropage base byte at *PC via callback, reads the 16-bit pointer stored in
; zeropage at that address via callback, adds Y to get the effective address, and sets
; the page-cross flag.  Increments PC by 1.
; Result: rbx  = 16-bit effective address (ptr + Y) & 0xFFFF
;         r13d = 1 if page crossed, else 0
; ----------------------------------------------------------------------------
%macro ADDR_INDIRECT_Y 0
    ; Read zeropage base byte via callback
    movzx r11, word [rsi]         ; r11 = PC
    call read_memory_byte         ; al = zeropage base address byte
    movzx rbx, al                 ; rbx = zeropage base
    
    ; Increment PC
    movzx r10, word [rsi]         ; r10 = PC
    inc r10w                      ; PC += 1
    mov word [rsi], r10w          ; store updated PC

    ; Read 16-bit little-endian pointer from zeropage via callback
    mov r11, rbx                  ; r11 = base
    call read_memory_byte         ; al = low byte of pointer
    movzx rax, al                 ; rax = low byte
    
    lea r10, [rbx + 1]
    and r10, 0xFF                 ; (base + 1) wraps within page 0
    mov r11, r10                  ; r11 = base + 1
    call read_memory_byte         ; al = high byte of pointer
    movzx r10, al                 ; r10 = high byte
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
