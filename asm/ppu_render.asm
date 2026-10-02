; NES Emulator - PPU Rendering Core
bits 64
default rel

extern ppu_read_chr
extern ppu_read_nt_byte
extern renderBackground_cpp
extern renderSpritesCpp

; section .rodata — NES NTSC master palette (64 × ARGB32, alpha = 0xFF)
section .rodata

global nes_palette_rgb
nes_palette_rgb:
    dd 0xFF626262, 0xFF001FB2, 0xFF2404C8, 0xFF5200B2
    dd 0xFF730076, 0xFF800024, 0xFF730B00, 0xFF522800
    dd 0xFF244400, 0xFF005700, 0xFF005C00, 0xFF005324
    dd 0xFF003C76, 0xFF000000, 0xFF000000, 0xFF000000
    dd 0xFFABABAB, 0xFF0D57FF, 0xFF4B30FF, 0xFF8A13FF
    dd 0xFFBC08D6, 0xFFD21269, 0xFFC72E00, 0xFF9D5400
    dd 0xFF607B00, 0xFF209800, 0xFF00A300, 0xFF009942
    dd 0xFF007DB4, 0xFF000000, 0xFF000000, 0xFF000000
    dd 0xFFFFFFFF, 0xFF53AEFF, 0xFF9085FF, 0xFFD365FF
    dd 0xFFFF57FF, 0xFFFF5DCF, 0xFFFF7757, 0xFFFA9E00
    dd 0xFFBDC700, 0xFF7AE700, 0xFF43F611, 0xFF26EF7E
    dd 0xFF2CD5F6, 0xFF4E4E4E, 0xFF000000, 0xFF000000
    dd 0xFFFFFFFF, 0xFFB6E1FF, 0xFFCED1FF, 0xFFE9C3FF
    dd 0xFFFFBCFF, 0xFFFFBDF4, 0xFFFFC6C3, 0xFFFFD59A
    dd 0xFFE9E681, 0xFFCEF481, 0xFFB6FB9A, 0xFFA9FAC3
    dd 0xFFA9F0F0, 0xFFB8B8B8, 0xFF000000, 0xFF000000

; section .bss — per-scanline shift register temporaries
section .bss

global bg_shift_lo, bg_shift_hi
global bg_attr_shift0, bg_attr_shift1
global bg_latch_nt, bg_latch_attr, bg_latch_lo, bg_latch_hi

bg_shift_lo:    resw 1
bg_shift_hi:    resw 1
bg_attr_shift0: resb 1
bg_attr_shift1: resb 1
bg_latch_nt:    resb 1
bg_latch_attr:  resb 1
bg_latch_lo:    resb 1
bg_latch_hi:    resb 1

; section .text — rendering functions
section .text

; ----------------------------------------------------------------------------
; evaluateSprites
; ----------------------------------------------------------------------------
global evaluateSprites
evaluateSprites:
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi            ; r12 = oam pointer
    mov     r13, rsi            ; r13 = secondary_oam pointer
    mov     r14d, edx           ; r14d = scanline
    mov     r15d, ecx           ; r15d = sprite_height (8 or 16)
    mov     rbx, r8             ; rbx  = ppustatus pointer

    ; Phase 1: clear secondary OAM with 0xFF (32 bytes = 8 dwords)
    mov     rdi, r13
    mov     eax, 0xFFFFFFFF
    mov     ecx, 8
    rep     stosd

    ; Phase 2: normal OAM scan
    xor     rbp, rbp            ; sprite_count = 0
    xor     r11d, r11d          ; sprite_zero_found = 0
    xor     r9d, r9d            ; overflow bug byte offset = 0
    xor     r10d, r10d          ; entry index = 0

.scan_loop:
    cmp     r10d, 64
    jge     .scan_done

    cmp     ebp, 8
    jge     .overflow_path

    mov     eax, r10d
    shl     eax, 2                      ; byte offset = entry * 4

    movzx   ecx, byte [r12 + rax]      ; raw Y value
    inc     ecx                         ; effective top = Y + 1

    ; NES PPU quirk: sprites with Y >= $EF are not displayed on the next frame
    cmp     ecx, 0xF0
    jge     .entry_next

    cmp     r14d, ecx
    jl      .entry_next

    mov     edx, ecx
    add     edx, r15d
    cmp     r14d, edx
    jge     .entry_next

    ; Copy 4-byte OAM entry to secondary OAM
    mov     edx, dword [r12 + rax]
    mov     ecx, ebp
    shl     ecx, 2
    mov     dword [r13 + rcx], edx

    test    r10d, r10d
    jnz     .not_sprite_zero
    mov     r11d, 1
.not_sprite_zero:
    inc     ebp
    jmp     .entry_next

.overflow_path:
    mov     eax, r10d
    shl     eax, 2
    lea     r8, [r12 + rax]
    movzx   ecx, byte [r8 + r9]
    inc     ecx

    ; NES PPU quirk: sprites with Y >= $EF are not displayed on the next frame
    cmp     ecx, 0xF0
    jge     .overflow_no_hit

    cmp     r14d, ecx
    jl      .overflow_no_hit
    mov     edx, ecx
    add     edx, r15d
    cmp     r14d, edx
    jge     .overflow_no_hit

    or      byte [rbx], 0x20
    jmp     .scan_done

.overflow_no_hit:
    inc     r9d
    and     r9d, 0x03

.entry_next:
    inc     r10d
    jmp     .scan_loop

.scan_done:
    mov     eax, ebp
    shl     r11d, 8
    or      eax, r11d

    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    ret

; ----------------------------------------------------------------------------
; renderScanline(PPUState* state, int scanline, uint32_t* fb_row)
; ----------------------------------------------------------------------------
%define S_CTRL           0
%define S_MASK           1
%define S_STATUS         2
%define S_V              4
%define S_FINE_X         8
%define S_VRAM           11
%define S_PALETTE_RAM    2059
%define S_OAM            2091
%define S_SECONDARY_OAM  2347
%define S_SPRITE_COUNT   2403
%define S_SZ_IN_RANGE    2404

global renderScanline
renderScanline:
    push    rbx
    push    rbp
    push    r12
    push    r13
    push    r14
    push    r15

    mov     r12, rdi               ; r12 = PPUState*
    mov     r13d, esi              ; r13d = scanline
    mov     r14, rdx               ; r14 = fb_row

    sub     rsp, 248
    mov     r15, rsp               ; r15 = bg_row[]

    ; ── Step 1: renderBackground_cpp ─────────────────────────────────────
    movzx   edi, word [r12 + S_V]
    movzx   esi, byte [r12 + S_FINE_X]
    lea     rdx, [r12 + S_VRAM]
    mov     rcx, r12                ; ppu_state
    xor     r8d, r8d                ; unused
    lea     r9, [r12 + S_PALETTE_RAM]
    movzx   eax, byte [r12 + S_MASK]
    push    rax                     ; 8th arg: ppumask
    push    r15                     ; 7th arg: bg_row
    call    renderBackground_cpp
    add     rsp, 16

    ; ── Step 2: bg_row → fb_row (palette lookup) ─────────────────────────
    lea     rbx, [r12 + S_PALETTE_RAM]
    lea     rbp, [rel nes_palette_rgb]
    movzx   r8d, byte [r12 + S_MASK]

    xor     ecx, ecx
.bg_to_fb_loop:
    cmp     ecx, 256
    jge     .bg_to_fb_done
    movzx   eax, byte [r15 + rcx]
    movzx   eax, byte [rbx + rax]
    and     eax, 0x3F
    test    r8b, 0x01
    jz      .no_gs
    and     eax, 0x30
.no_gs:
    mov     edx, dword [rbp + rax*4]
    mov     dword [r14 + rcx*4], edx
    inc     ecx
    jmp     .bg_to_fb_loop

.bg_to_fb_done:
    ; ── Step 3: renderSpritesCpp ─────────────────────────────────────────
    mov     rdi, r12                ; ppu_state*
    mov     esi, r13d              ; scanline
    mov     rdx, r15               ; bg_row
    mov     rcx, r14               ; fb_row
    call    renderSpritesCpp

    ; ── Epilogue ─────────────────────────────────────────────────────────
    add     rsp, 248
    pop     r15
    pop     r14
    pop     r13
    pop     r12
    pop     rbp
    pop     rbx
    ret

; ----------------------------------------------------------------------------
; calculatePixelColor (unchanged)
; ----------------------------------------------------------------------------
global calculatePixelColor
calculatePixelColor:
    and     rdi, 0x3F

    test    dl, 0x01
    jz      .no_greyscale
    and     rdi, 0x30
.no_greyscale:

    mov     eax, [rsi + rdi*4]

    mov     ecx, edx
    shr     ecx, 5
    and     ecx, 0x07
    jz      .no_emphasis

    test    ecx, 0x01
    jnz     .skip_r
    mov     r8d, eax
    shr     r8d, 16
    and     r8d, 0xFF
    imul    r8d, r8d, 0xD5
    shr     r8d, 8
    and     eax, 0xFF00FFFF
    shl     r8d, 16
    or      eax, r8d
.skip_r:

    test    ecx, 0x02
    jnz     .skip_g
    mov     r8d, eax
    shr     r8d, 8
    and     r8d, 0xFF
    imul    r8d, r8d, 0xD5
    shr     r8d, 8
    and     eax, 0xFFFF00FF
    shl     r8d, 8
    or      eax, r8d
.skip_g:

    test    ecx, 0x04
    jnz     .skip_b
    mov     r8d, eax
    and     r8d, 0xFF
    imul    r8d, r8d, 0xD5
    shr     r8d, 8
    and     eax, 0xFFFFFF00
    or      eax, r8d
.skip_b:

.no_emphasis:
    ret

section .note.GNU-stack noalloc noexec nowrite progbits