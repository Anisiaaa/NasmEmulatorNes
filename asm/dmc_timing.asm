
bits 64
default rel

; DMCState structure offsets (must match C++ layout in include/apu.hpp)
; struct DMCState {
;     u8  enabled;            // +0: bit 4 of $4015
;     u8  irqEnable;          // +1: bit 7 of $4010
;     u8  loopFlag;           // +2: bit 6 of $4010
;     u8  rateIndex;          // +3: bits 3-0 of $4010
;     u8  lengthCounter;      // +4: stub (always 0, audio out of scope)
;     u8  sampleBufferEmpty;  // +5: fetch trigger flag
;     u8  dmcIrqFlag;         // +6: bit 7 of $4015
;     u8  pad1;               // +7: padding
;     u16 sampleStartAddr;    // +8: 0xC000 + ($4012 * 64)
;     u16 sampleLength;       // +10: ($4013 * 16) + 1
;     u16 currentAddr;        // +12: DMA address (wraps $FFFF → $8000)
;     u16 bytesRemaining;     // +14: bytes left in sample
;     u32 rateTimer;          // +16: countdown timer
;     u32 pad2[11];           // +20: padding to 64 bytes
; } __attribute__((packed));
; Total size: 64 bytes

%define DMC_ENABLED             0
%define DMC_IRQENABLE           1
%define DMC_LOOPFLAG            2
%define DMC_RATEINDEX           3
%define DMC_LENGTHCOUNTER       4
%define DMC_SAMPLEBUFFEREMPTY   5
%define DMC_DMCIRQFLAG          6
%define DMC_PAD1                7
%define DMC_SAMPLESTARTADDR     8
%define DMC_SAMPLELENGTH        10
%define DMC_CURRENTADDR         12
%define DMC_BYTESREMAINING      14
%define DMC_RATETIMER           16
%define DMC_SIZE                64

; Maps $4010 bits 3-0 (rateIndex 0x0–0xF) to CPU cycle periods.
section .rodata
align 4
global dmc_rate_table_ntsc
dmc_rate_table_ntsc:
    dd 428, 380, 340, 320, 286, 254, 226, 214
    dd 190, 160, 142, 128, 106,  84,  72,  54

section .text

; System V ABI:
;   Parameters:
;     rdi = DMCState* state (pointer to DMC state structure)
;     rsi = u8 hard (1 = power-on reset, 0 = soft CPU reset)
;   Returns: void
;   Preserves: rbx, rbp, r12-r15
;
; Hard reset clears the complete state; soft reset clears only dmcIrqFlag.
global dmcTimingReset
dmcTimingReset:
    test    sil, sil
    jz      .soft_reset
    
.hard_reset:
    xor     eax, eax
    
    mov     [rdi + DMC_ENABLED], al
    mov     [rdi + DMC_IRQENABLE], al
    mov     [rdi + DMC_LOOPFLAG], al
    mov     [rdi + DMC_RATEINDEX], al
    mov     [rdi + DMC_LENGTHCOUNTER], al
    mov     [rdi + DMC_SAMPLEBUFFEREMPTY], al
    mov     [rdi + DMC_DMCIRQFLAG], al
    mov     [rdi + DMC_PAD1], al
    
    mov     word [rdi + DMC_SAMPLESTARTADDR], ax
    mov     word [rdi + DMC_SAMPLELENGTH], ax
    mov     word [rdi + DMC_CURRENTADDR], ax
    mov     word [rdi + DMC_BYTESREMAINING], ax
    
    mov     dword [rdi + DMC_RATETIMER], eax
    
    mov     qword [rdi + 20], rax
    mov     qword [rdi + 28], rax
    mov     qword [rdi + 36], rax
    mov     qword [rdi + 44], rax
    mov     qword [rdi + 52], rax
    mov     dword [rdi + 60], eax
    
    ret
    
.soft_reset:
    mov     byte [rdi + DMC_DMCIRQFLAG], 0
    ret

; System V ABI:
;   Parameters:
;     rdi = DMCState* state (pointer to DMC state structure)
;     rsi = u8 instructionPhase (0=Read, 1=Write, 2=RMW, 3=OAMDMALast)
;     rdx = u64 currentCycle
;   Returns:
;     al = number of cycles to steal (0, 1, 2, or 4)
;   Preserves: rbx, rbp, r12-r15
;
; The caller supplies one phase for the whole instruction. This is an
; intentional timing approximation; actual 6502 bus phases vary by cycle.
global dmcTimingTick
dmcTimingTick:
    movzx   eax, byte [rdi + DMC_ENABLED]
    test    al, al
    jz      .no_steal
    
.enabled_check:
    movzx   eax, byte [rdi + DMC_SAMPLEBUFFEREMPTY]
    test    al, al
    jz      .no_steal
    
    mov     ecx, [rdi + DMC_RATETIMER]
    test    ecx, ecx
    jz      .timer_expired
    
    dec     ecx
    mov     [rdi + DMC_RATETIMER], ecx
    jmp     .no_steal
    
.timer_expired:
    movzx   r8d, byte [rdi + DMC_RATEINDEX]
    and     r8d, 0x0F
    lea     r10, [dmc_rate_table_ntsc]
    mov     r8d, [r10 + r8*4]
    mov     [rdi + DMC_RATETIMER], r8d
    
    cmp     sil, 0
    je      .steal_phase_read
    cmp     sil, 1
    je      .steal_phase_write
    cmp     sil, 2
    je      .steal_phase_rmw
    cmp     sil, 3
    je      .steal_phase_read
    jmp     .no_steal
    
.steal_phase_read:
    mov     al, 1
    ret
    
.steal_phase_write:
    mov     al, 2
    ret
    
.steal_phase_rmw:
    mov     al, 4
    ret
    
.no_steal:
    xor     eax, eax
    ret


section .note.GNU-stack noalloc noexec nowrite progbits
