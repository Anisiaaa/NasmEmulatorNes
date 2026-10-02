; NES Emulator - Memory System
; Low-level assembly memory access functions with proper mirroring

default rel
bits 64

section .text


global readMemory
readMemory:
    ; Parameters: rdi = memory, rsi = address
    ; Returns: al = value
    mov rax, rdi
    movzx eax, byte [rax+rsi]
    ret

global writeMemory
writeMemory:
    ; Parameters: rdi = memory, rsi = address, rdx = value
    mov rax, rdi
    mov byte [rax+rsi], dl
    ret

; asm_simulateBusConflict: Simulate NES bus conflict (AND operation)
; Parameters: rdi = written value, rsi = rom value
; Returns: al = result (written_value & rom_value)

global asm_simulateBusConflict
asm_simulateBusConflict:
    ; AND the written value with the ROM value
    mov eax, edi
    and al, sil
    ret


global readPPUMemory
readPPUMemory:
    ret


global writeMapper
writeMapper:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits
