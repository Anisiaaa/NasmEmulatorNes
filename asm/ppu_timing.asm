; NES Emulator - PPU Timing
; Cycle-accurate PPU timing
bits 64
section .text

global getPPUCycle
global resetPPUCycle
global advancePPUCycle

getPPUCycle:
    mov rax, [rel ppu_cycle]
    ret

resetPPUCycle:
    xor rax, rax
    mov [rel ppu_cycle], rax
    ret

advancePPUCycle:
    imul rdi, rdi, 3   
    add [rel ppu_cycle], rdi
    ret

section .bss
ppu_cycle: resq 1

section .note.GNU-stack noalloc noexec nowrite progbits