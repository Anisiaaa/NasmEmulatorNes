

bits 64
default rel

; FrameCounterState Structure Offsets
; This struct layout MUST match the C++ definition in include/apu.hpp.
; Any mismatch will cause runtime errors when assembly accesses fields.
;
; C++ Definition (struct FrameCounterState):
;   struct FrameCounterState {
;       u8  mode5step;          // +0
;       u8  irqInhibit;         // +1
;       u8  frameIrqFlag;       // +2
;       u8  pendingReset;       // +3
;       u32 pad1;               // +4
;       u64 resetAtCycle;       // +8
;       u64 divider;            // +16
;       u64 pad2;               // +24
;   } __attribute__((packed));
;
; Total Size: 32 bytes
;
; Assembly Access Pattern:
;   mov rdi, state_ptr          ; First parameter (System V ABI)
;   movzx eax, byte [rdi + FC_MODE5STEP]
;   mov qword [rdi + FC_DIVIDER], rcx

%define FC_MODE5STEP        0       ; +0:  u8  - 4-step (0) or 5-step (1) mode
%define FC_IRQINHIBIT       1       ; +1:  u8  - IRQ inhibit flag (bit 6 of $4017)
%define FC_FRAMEIRQFLAG     2       ; +2:  u8  - Pending Frame IRQ flag (bit 6 of $4015)
%define FC_PENDINGRESET     3       ; +3:  u8  - Jitter-delayed reset queued
%define FC_PAD1             4       ; +4:  u32 - Padding for alignment
%define FC_RESETATCYCLE     8       ; +8:  u64 - Absolute cycle for sequencer reset
%define FC_DIVIDER          16      ; +16: u64 - Cycle offset within current sequence
%define FC_PAD2             24      ; +24: u64 - Padding to 32 bytes
%define FC_SIZE             32      ; Total structure size


section .text

; frameCounterTick — Advance Frame Counter divider by one CPU cycle
; and checks if an IRQ should be asserted based on the current mode and cycle offset.
;
; The divider increments on every call, directly tracking CPU cycle progression.
; Frame Counter events (quarter-frame, half-frame, IRQ) occur at specific divider values.
;
; In 4-step mode with IRQ not inhibited, the function checks for IRQ fire
; points at CPU cycle offsets 29828, 29829, and 29830.
; In 5-step mode or when IRQ is inhibited, no IRQs are fired.
;
; The divider wraps to 0 at the end of each sequence period:
;   - 4-step mode: 29830 CPU cycles → wrap to 0
;   - 5-step mode: 37281 CPU cycles → wrap to 0
;
; System V ABI Parameters:
;   rdi = FrameCounterState* state  (pointer to Frame Counter state)
;   rsi = u64 currentCycle           (current CPU cycle counter)
;
; Returns:
;   al = 1 if IRQ should be asserted this cycle, 0 otherwise
;
; Preserves:
;   rbx, rbp, r12-r15 (callee-saved registers per System V ABI)
;
; Register Allocation:
;   rdi = state pointer (preserved for field access throughout)
;   rsi = currentCycle (input parameter)
;   rax = return value (0 or 1)
;   rcx = divider value (loaded from state, modified, stored back)
;   r8  = resetAtCycle (loaded from state for reset check)
;   r9d = mode flag (0=4-step, 1=5-step)
;   r10d = irqInhibit flag (0=allow IRQ, 1=inhibit IRQ)
;
; ----------------------------------------------------------------------------
global frameCounterTick
frameCounterTick:
    ; Load state fields into registers
    movzx   r9d, byte [rdi + FC_MODE5STEP]      ; r9d = mode flag (0=4-step, 1=5-step)
    movzx   r10d, byte [rdi + FC_IRQINHIBIT]    ; r10d = IRQ inhibit flag
    mov     rcx, [rdi + FC_DIVIDER]             ; rcx = current divider value
    mov     r8, [rdi + FC_RESETATCYCLE]         ; r8 = reset cycle target
    
    ; Check for pending reset: if pendingReset==1 and currentCycle >= resetAtCycle
    cmp     byte [rdi + FC_PENDINGRESET], 1
    jne     .no_reset
    cmp     rsi, r8                              ; currentCycle >= resetAtCycle?
    jb      .no_reset
    
    ; Apply reset: divider = 0, pendingReset = 0
    xor     rcx, rcx
    mov     byte [rdi + FC_PENDINGRESET], 0
    
.no_reset:
    ; APU Frame Counter divider tracks CPU cycles directly
    ; Increment divider on every call to frameCounterTick
    inc     rcx
    ; Check if we're in 4-step mode (mode5step == 0)
    test    r9b, r9b
    jnz     .mode_5step                          ; 5-step mode → skip IRQ logic
    
    ; 4-step mode: check for IRQ fire points
    ; Per NESdev, IRQ fires at CPU cycles 29828.5, 29829.5, 29830.5
    ; We check at cycles 29828, 29829, 29830 (before the .5)
    
    ; Check if IRQ is inhibited
    test    r10b, r10b
    jnz     .mode_4step_no_irq                   ; IRQ inhibited → skip IRQ fire
    
    ; Check for IRQ fire at CPU cycles 29828, 29829, 29830
    cmp     rcx, 29828
    je      .fire_irq
    cmp     rcx, 29829
    je      .fire_irq
    cmp     rcx, 29830
    je      .fire_irq_and_wrap
    
    ; Not at IRQ fire point, check for wrap
    jmp     .mode_4step_no_irq
    
.fire_irq:
    ; Fire IRQ at CPU cycles 29828, 29829
    mov     byte [rdi + FC_FRAMEIRQFLAG], 1
    mov     [rdi + FC_DIVIDER], rcx
    mov     al, 1
    ret
    
.fire_irq_and_wrap:
    ; Fire IRQ at CPU cycle 29830, then wrap to 0
    mov     byte [rdi + FC_FRAMEIRQFLAG], 1
    xor     rcx, rcx
    mov     [rdi + FC_DIVIDER], rcx
    mov     al, 1
    ret
    
.mode_4step_no_irq:
    ; Not at IRQ fire point in 4-step mode (or IRQ inhibited)
    ; Check for wrap: divider wraps at CPU cycle 29830
    ; 4-step sequence is 29830 CPU cycles (0 to 29829)
    cmp     rcx, 29830
    jae     .wrap_divider_4step
    
    ; Store divider
    mov     [rdi + FC_DIVIDER], rcx
    xor     eax, eax
    ret
    
.wrap_divider_4step:
    ; Wrap APU divider to 0
    xor     rcx, rcx
    mov     [rdi + FC_DIVIDER], rcx
    xor     eax, eax
    ret
    
.mode_5step:
    ; 5-step mode: check for wrap
    ; No IRQ fires in 5-step mode
    ; divider already incremented above (tracks CPU cycles)
    
    ; Check for wrap: divider wraps at CPU cycle 37281
    ; 5-step sequence is 37281 CPU cycles (0 to 37280)
    cmp     rcx, 37281
    jae     .wrap_divider_5step
    
    ; Store divider (5-step mode never fires IRQ)
    mov     [rdi + FC_DIVIDER], rcx
    xor     eax, eax
    ret
    
.wrap_divider_5step:
    ; Wrap APU divider to 0
    xor     rcx, rcx
    mov     [rdi + FC_DIVIDER], rcx
    xor     eax, eax
    ret

; frameCounterWrite4017 — Handle $4017 register write
; It extracts the mode select bit (bit 7) and IRQ inhibit flag (bit 6),
; computes the jitter-adjusted reset cycle based on write cycle parity, and
; schedules a sequencer reset.
;
; Write Jitter Rule:
;   - Even cycle write: sequencer resets 3 cycles later
;   - Odd cycle write:  sequencer resets 4 cycles later
;
; When mode5step is set (bit 7 = 1), frameIrqFlag is cleared immediately.
; When irqInhibit is set (bit 6 = 1), frameIrqFlag is cleared immediately.
;
; System V ABI Parameters:
;   rdi = FrameCounterState* state  (pointer to Frame Counter state)
;   rsi = u8 value                   (byte written to $4017)
;   rdx = u64 currentCycle           (CPU cycle when write occurred)
;
; Returns:
;   void (no return value)
;
; Preserves:
;   rbx, rbp, r12-r15 (callee-saved registers per System V ABI)
;
; Register Allocation:
;   rdi = state pointer (preserved)
;   rsi = value (input, used to extract mode/inhibit bits)
;   rdx = currentCycle (input)
;   rax = temporary (jitter calculation, bit extraction)
;   rcx = temporary
;   r8  = resetAtCycle (computed value)
;
; ----------------------------------------------------------------------------
global frameCounterWrite4017
frameCounterWrite4017:
    ; Extract mode5step from bit 7 of value
    mov     al, sil                 ; Copy value to al (sil is low byte of rsi)
    shr     al, 7                   ; Shift bit 7 to bit 0
    mov     byte [rdi + FC_MODE5STEP], al
    
    ; Extract irqInhibit from bit 6 of value
    mov     al, sil                 ; Copy value to al again
    shr     al, 6                   ; Shift bit 6 to bit 0
    and     al, 1                   ; Mask to isolate bit 0
    mov     byte [rdi + FC_IRQINHIBIT], al
    
    ; Compute jitter delay based on currentCycle parity
    ; if (currentCycle & 1) == 0 → jitter = 3, else jitter = 4
    test    rdx, 1                  ; Test LSB of currentCycle
    jz      .even_cycle             ; Jump if zero (even cycle)
    
.odd_cycle:
    mov     r8, rdx                 ; r8 = currentCycle
    add     r8, 4                   ; jitter = 4 for odd cycles
    jmp     .set_reset_cycle
    
.even_cycle:
    mov     r8, rdx                 ; r8 = currentCycle
    add     r8, 3                   ; jitter = 3 for even cycles
    
.set_reset_cycle:
    ; Set resetAtCycle = currentCycle + jitter
    mov     qword [rdi + FC_RESETATCYCLE], r8
    
    ; Set pendingReset = 1
    mov     byte [rdi + FC_PENDINGRESET], 1
    
    ; If irqInhibit == 1: clear frameIrqFlag immediately
    movzx   ecx, byte [rdi + FC_IRQINHIBIT]
    test    cl, cl
    jz      .check_mode5step        ; Skip if irqInhibit is 0
    mov     byte [rdi + FC_FRAMEIRQFLAG], 0
    
.check_mode5step:
    ; If mode5step == 1: clear frameIrqFlag immediately
    movzx   ecx, byte [rdi + FC_MODE5STEP]
    test    cl, cl
    jz      .done                   ; Skip if mode5step is 0
    mov     byte [rdi + FC_FRAMEIRQFLAG], 0
    
.done:
    ret

; frameCounterReset — Initialize or preserve Frame Counter state
; or preserves mode/inhibit/divider across a soft CPU reset.
;
; Hard Reset (hard=1):
;   - All fields zeroed: mode5step=0 (4-step), irqInhibit=0, frameIrqFlag=0
;   - pendingReset=0, resetAtCycle=0, divider=0
;
; Soft Reset (hard=0):
;   - Only frameIrqFlag is cleared (simulates $4015=$00 write side effect)
;   - mode5step, irqInhibit, divider, resetAtCycle, pendingReset preserved
;
; System V ABI Parameters:
;   rdi = FrameCounterState* state  (pointer to Frame Counter state)
;   rsi = u8 hard (1 = power-on reset, 0 = soft CPU reset)
;
; Returns:
;   void (no return value)
;
; Preserves:
;   rbx, rbp, r12-r15 (callee-saved registers per System V ABI)
;
; Register Allocation:
;   rdi = state pointer (preserved)
;   rsi = hard flag (input)
;   rax = temporary (used for zeroing)
;
; ----------------------------------------------------------------------------
global frameCounterReset
frameCounterReset:
    ; Check if this is a hard reset (power-on) or soft reset (CPU reset)
    test    sil, sil            ; Test hard flag (rsi = u8 hard)
    jz      .soft_reset         ; If hard == 0, jump to soft reset
    
.hard_reset:
    ; Hard reset: zero all fields
    ; mode5step = 0, irqInhibit = 0, frameIrqFlag = 0, pendingReset = 0
    xor     eax, eax
    mov     dword [rdi + FC_MODE5STEP], eax     ; Clear first 4 bytes (mode5step, irqInhibit, frameIrqFlag, pendingReset)
    mov     dword [rdi + FC_PAD1], eax          ; Clear padding
    mov     qword [rdi + FC_RESETATCYCLE], rax  ; resetAtCycle = 0
    mov     qword [rdi + FC_DIVIDER], rax       ; divider = 0
    mov     qword [rdi + FC_PAD2], rax          ; Clear padding
    ret
    
.soft_reset:
    ; Soft reset: clear only frameIrqFlag, preserve everything else
    ; This simulates the side effect of writing $00 to $4015
    mov     byte [rdi + FC_FRAMEIRQFLAG], 0
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
