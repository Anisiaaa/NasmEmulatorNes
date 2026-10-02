

; External functions from flags.asm
extern set_zn_flags
extern set_carry_flag

; External unofficial combined RMW opcode handlers — unofficial.asm
extern slo_zeropage
extern slo_zeropage_x
extern slo_absolute
extern slo_absolute_x
extern slo_absolute_y
extern slo_indirect_x
extern slo_indirect_y

extern rla_zeropage
extern rla_zeropage_x
extern rla_absolute
extern rla_absolute_x
extern rla_absolute_y
extern rla_indirect_x
extern rla_indirect_y

extern sre_zeropage
extern sre_zeropage_x
extern sre_absolute
extern sre_absolute_x
extern sre_absolute_y
extern sre_indirect_x
extern sre_indirect_y

extern rra_zeropage
extern rra_zeropage_x
extern rra_absolute
extern rra_absolute_x
extern rra_absolute_y
extern rra_indirect_x
extern rra_indirect_y

extern dcp_zeropage
extern dcp_zeropage_x
extern dcp_absolute
extern dcp_absolute_x
extern dcp_absolute_y
extern dcp_indirect_x
extern dcp_indirect_y

extern isc_zeropage
extern isc_zeropage_x
extern isc_absolute
extern isc_absolute_x
extern isc_absolute_y
extern isc_indirect_x
extern isc_indirect_y

; External unofficial LAX group — unofficial.asm
extern lax_zeropage
extern lax_zeropage_y
extern lax_absolute
extern lax_absolute_y
extern lax_indirect_x
extern lax_indirect_y

; External unofficial SAX group — unofficial.asm
extern sax_zeropage
extern sax_zeropage_y
extern sax_absolute
extern sax_indirect_x

; External unofficial unstable writes — unofficial.asm
extern sha_indirect_y
extern sha_absolute_y
extern shx_absolute_y
extern shy_absolute_x
extern tas_absolute_y
extern las_absolute_y

; External unofficial single-byte arithmetics — unofficial.asm
extern anc_immediate
extern alr_immediate
extern arr_immediate
extern axs_immediate
extern ane_immediate
extern lxa_immediate
extern sbc_immediate_eb

; External unofficial NOP variants — unofficial.asm
extern nop_implied_unofficial
extern nop_zeropage_unofficial
extern nop_zeropage_x_unofficial
extern nop_absolute_unofficial
extern nop_absolute_x_unofficial

; External KIL handler — unofficial.asm
extern kil_instr

; External opcode handlers — load/store
extern lda_immediate
extern lda_zeropage
extern lda_absolute
extern lda_zeropage_x
extern lda_absolute_x
extern lda_absolute_y
extern lda_indirect_x
extern lda_indirect_y
extern ldx_immediate
extern ldx_zeropage
extern ldx_absolute
extern ldx_zeropage_y
extern ldx_absolute_y
extern ldy_immediate
extern ldy_zeropage
extern ldy_absolute
extern ldy_zeropage_x
extern ldy_absolute_x
extern sta_zeropage
extern sta_absolute
extern sta_zeropage_x
extern sta_absolute_x
extern sta_absolute_y
extern sta_indirect_x
extern sta_indirect_y
extern stx_zeropage
extern stx_absolute
extern stx_zeropage_y
extern sty_zeropage
extern sty_absolute
extern sty_zeropage_x

; External opcode handlers — arithmetic
extern adc_immediate
extern adc_zeropage
extern adc_zeropage_x
extern adc_absolute
extern adc_absolute_x
extern adc_absolute_y
extern adc_indirect_x
extern adc_indirect_y
extern sbc_immediate
extern sbc_zeropage
extern sbc_zeropage_x
extern sbc_absolute
extern sbc_absolute_x
extern sbc_absolute_y
extern sbc_indirect_x
extern sbc_indirect_y
extern inc_zeropage
extern inc_absolute
extern inc_zeropage_x
extern inc_absolute_x
extern dec_zeropage
extern dec_absolute
extern dec_zeropage_x
extern dec_absolute_x
extern inx_instr
extern iny_instr
extern dex_instr
extern dey_instr

; External opcode handlers — logical
extern and_immediate
extern and_zeropage
extern and_zeropage_x
extern and_absolute
extern and_absolute_x
extern and_absolute_y
extern and_indirect_x
extern and_indirect_y
extern ora_immediate
extern ora_zeropage
extern ora_zeropage_x
extern ora_absolute
extern ora_absolute_x
extern ora_absolute_y
extern ora_indirect_x
extern ora_indirect_y
extern eor_immediate
extern eor_zeropage
extern eor_zeropage_x
extern eor_absolute
extern eor_absolute_x
extern eor_absolute_y
extern eor_indirect_x
extern eor_indirect_y
extern asl_accumulator
extern asl_zeropage
extern asl_zeropage_x
extern asl_absolute
extern asl_absolute_x
extern lsr_accumulator
extern lsr_zeropage
extern lsr_zeropage_x
extern lsr_absolute
extern lsr_absolute_x
extern rol_accumulator
extern rol_zeropage
extern rol_zeropage_x
extern rol_absolute
extern rol_absolute_x
extern ror_accumulator
extern ror_zeropage
extern ror_zeropage_x
extern ror_absolute
extern ror_absolute_x

; External opcode handlers — branches
extern beq_instr
extern bne_instr
extern bpl_instr
extern bmi_instr
extern bcs_instr
extern bcc_instr
extern bvc_instr
extern bvs_instr

; External opcode handlers — stack
extern pha_instr
extern php_instr
extern pla_instr
extern plp_instr
extern jsr_absolute
extern rts_instr

; External opcode handlers — flags
extern clc_instr
extern sec_instr
extern cli_instr
extern sei_instr
extern clv_instr
extern cld_instr
extern sed_instr

section .text
bits 64

; read_memory_byte — Helper function to read a byte via callback
; Input: r11 = 16-bit address to read from
; Output: al = byte value read
; Preserves: All registers except rax, rdi (caller-saved)
global read_memory_byte
read_memory_byte:
    ; Save registers that will be clobbered by the call
    ; Preserve rdi as well so callers' memory pointer isn't overwritten.
    ; (Entry stack alignment: rsp % 16 = 8 due to return address)
    push rdi
    push rsi
    push rdx
    push rcx
    push r8
    push r9
    push r10

    ; After 7 pushes (56 bytes), stack is aligned for the call (no extra adjust)

    ; Prepare callback call: rdi = address
    movzx rdi, r11w            ; Zero-extend address to 64-bit in rdi

    ; Call the callback (stack is 16-byte aligned)
    call [rel memory_read_callback]

    ; Result is in al (uint8_t return value)

    ; Restore registers (MUST be in reverse order of push!)
    ; Pushed: rdi, rsi, rdx, rcx, r8, r9, r10
    ; Pop in reverse: r10, r9, r8, rcx, rdx, rsi, rdi
    pop r10
    pop r9
    pop r8
    pop rcx
    pop rdx
    pop rsi
    pop rdi

    ret

; setSPPointer — C-callable setter for sp_pointer
; void setSPPointer(uint8_t* sp)
global setSPPointer
setSPPointer:
    mov [rel sp_pointer], rdi
    ret

; execute6502Instruction — main opcode dispatcher
; C signature:
;   int execute6502Instruction(ReadMemoryCallback read_memory_callback, uint8_t* memory,
;                               uint16_t* PC, uint8_t* A, uint8_t* X, uint8_t* Y,
;                               uint8_t* P, uint8_t* SP)
; Linux x86-64 ABI:
;   rdi = read_memory_callback (function pointer)
;   rsi = memory (for WRITES - preserved as-is per task requirements)
;   rdx = PC*
;   rcx = A*
;   r8 = X*
;   r9 = Y*
;   [rsp+8] = P* (7th arg, before any pushes; after 5 pushes: [rsp+48])
;   [rsp+16] = SP* (8th arg, before any pushes; after 5 pushes: [rsp+56])
; Internal handler convention:
;   rdi = memory pointer (for WRITES), rsi = PC*, rdx = A*, rcx = P*, r8 = X*, r9 = Y*
;   NOTE: Memory READS must use read_memory_byte helper which calls the callback
global execute6502Instruction
execute6502Instruction:
    ; Save callee-saved registers
    push rbx
    push r12
    push r13
    push r14
    push r15
    push rbp

    ; Store the callback pointer in global variable for later use by read_memory_byte
    mov [rel memory_read_callback], rdi
    
    ; Store the memory pointer in global variable
    mov [rel memory_write_pointer], rsi

    ; Save all argument pointers in callee-saved regs
    ; C ABI order: rdi=callback, rsi=memory, rdx=PC, rcx=A, r8=X, r9=Y, [rsp+56]=P, [rsp+64]=SP
    mov r12, rsi        ; r12 = memory ptr (for writes, also used as rdi in handlers)
    mov r13, rdx        ; r13 = PC ptr
    mov r14, rcx        ; r14 = A ptr
    mov r15, r8         ; r15 = X ptr
    mov rbx, r9         ; rbx = Y ptr
    ; P ptr is at [rsp+56], SP ptr is at [rsp+64]
    
    ; Update sp_pointer with the 8th argument (SP ptr)
    ; After 6 pushes (6 callee-saved regs): [rsp+64] = original [rsp+16] = SP ptr
    mov rdi, [rsp + 64]
    call setSPPointer

    ; Read opcode at memory[*PC] using callback and increment PC
    movzx r11, word [r13]          ; r11 = PC value (16-bit address)
    call read_memory_byte          ; Call helper, returns byte in al
    movzx eax, al                  ; Zero-extend result to eax (opcode)
    
    ; Increment PC
    movzx r10, word [r13]
    inc r10w
    mov word [r13], r10w           ; PC++

    ; Set up handler arguments in internal convention:
    ;   rdi = memory (r12)
    ;   rsi = PC*    (r13)
    ;   rdx = A*     (r14)
    ;   rcx = P*     ([rsp+48] — 7th C arg, on stack)
    ;   r8  = X*     (r15 — 5th C arg)
    ;   r9  = Y*     (rbx — 6th C arg)
    ; We must do this AFTER reading the opcode but BEFORE calling handlers.
    ; Save opcode in a caller-saved reg we won't use otherwise.
    ; Use the jump table via rax (opcode).

    ; Prepare handler args — we'll do this right before each call via macros
    ; But since we use a jump table, set them up once here, then jmp.
    ; Save opcode to use after setup.
    push rax                       ; save opcode on stack (rsp now shifted by 8)
    
    ; Get P pointer from stack (7th argument)
    ; After 6 callee-saved register pushes + opcode push: [rsp+64] = original [rsp+8] = P*
    mov rbp, [rsp+64]              ; rbp = P* (preserved across handler calls - callee-saved register)
    
    ; Rearrange for internal calling convention
    ; rdi <- r12 (memory)
    ; rsi <- r13 (PC*)
    ; rdx <- r14 (A*)
    ; rcx <- rbp (P* from stack)
    ; r8  <- r15 (X*)
    ; r9  <- rbx (Y*)
    mov rdi, r12
    mov rsi, r13
    mov rdx, r14
    mov rcx, rbp                   ; rcx = P* (from rbp - callee-saved)
    mov r8, r15
    mov r9, rbx

    pop rax                        ; restore opcode

    ; Dispatch via jump table
    lea rbx, [rel opcode_table]
    jmp [rbx + rax*8]

; Opcode handlers return here via nop_fallback or directly
; eax = cycles from handler
.dispatch_done:
    ; Save instruction cycles in r11
    mov r11d, eax
    ; Skip assembly interrupt checks – they are handled in C++ Emulator::step()
    jmp .no_interrupt

.check_interrupts:      ; (dead code left for reference, not used)
.no_interrupt:
    ; No interrupts pending, return total cycles
    mov eax, r11d
    pop rbp
    pop r15
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; Fallback for unimplemented opcodes — skip 1 byte, return 2 cycles
nop_fallback:
    ; PC was already incremented past opcode. Return 2 cycles.
    mov eax, 2
    jmp execute6502Instruction.dispatch_done

; Wrappers that JMP to handler then return to .dispatch_done
; Each opcode handler uses `ret`, so we need a call/ret pattern.
; We use CALL to the handler — the handler rets to us, then we jmp to done.

%macro DISPATCH_CALL 1
    call %1
    jmp execute6502Instruction.dispatch_done
%endmacro

; Opcode dispatch entries.
op_00: DISPATCH_CALL brk_instr              ; $00  BRK
op_01: DISPATCH_CALL ora_indirect_x         ; $01  ORA (ind,X)
op_02: DISPATCH_CALL kil_instr              ; $02  KIL (halt)
op_03: DISPATCH_CALL slo_indirect_x         ; $03  SLO (ind,X)
op_04: DISPATCH_CALL nop_zeropage_unofficial ; $04  NOP zpg (unofficial)
op_05: DISPATCH_CALL ora_zeropage            ; $05  ORA zpg
op_06: DISPATCH_CALL asl_zeropage            ; $06  ASL zpg
op_07: DISPATCH_CALL slo_zeropage            ; $07  SLO zpg
op_08: DISPATCH_CALL php_instr               ; $08  PHP
op_09: DISPATCH_CALL ora_immediate           ; $09  ORA imm
op_0A: DISPATCH_CALL asl_accumulator         ; $0A  ASL acc
op_0B: DISPATCH_CALL anc_immediate           ; $0B  ANC imm (unofficial)
op_0C: DISPATCH_CALL nop_absolute_unofficial ; $0C  NOP abs (unofficial)
op_0D: DISPATCH_CALL ora_absolute            ; $0D  ORA abs
op_0E: DISPATCH_CALL asl_absolute            ; $0E  ASL abs
op_0F: DISPATCH_CALL slo_absolute            ; $0F  SLO abs
op_10: DISPATCH_CALL bpl_instr               ; $10  BPL
op_11: DISPATCH_CALL ora_indirect_y          ; $11  ORA (ind),Y
op_12: DISPATCH_CALL kil_instr               ; $12  KIL (halt)
op_13: DISPATCH_CALL slo_indirect_y          ; $13  SLO (ind),Y
op_14: DISPATCH_CALL nop_zeropage_x_unofficial ; $14  NOP zpg,X (unofficial)
op_15: DISPATCH_CALL ora_zeropage_x          ; $15  ORA zpg,X
op_16: DISPATCH_CALL asl_zeropage_x          ; $16  ASL zpg,X
op_17: DISPATCH_CALL slo_zeropage_x          ; $17  SLO zpg,X
op_18: DISPATCH_CALL clc_instr               ; $18  CLC
op_19: DISPATCH_CALL ora_absolute_y          ; $19  ORA abs,Y
op_1A: DISPATCH_CALL nop_implied_unofficial  ; $1A  NOP (unofficial)
op_1B: DISPATCH_CALL slo_absolute_y          ; $1B  SLO abs,Y
op_1C: DISPATCH_CALL nop_absolute_x_unofficial ; $1C  NOP abs,X (unofficial)
op_1D: DISPATCH_CALL ora_absolute_x          ; $1D  ORA abs,X
op_1E: DISPATCH_CALL asl_absolute_x          ; $1E  ASL abs,X
op_1F: DISPATCH_CALL slo_absolute_x          ; $1F  SLO abs,X
op_20: DISPATCH_CALL jsr_absolute            ; $20  JSR
op_21: DISPATCH_CALL and_indirect_x          ; $21  AND (ind,X)
op_22: DISPATCH_CALL kil_instr               ; $22  KIL (halt)
op_23: DISPATCH_CALL rla_indirect_x          ; $23  RLA (ind,X)
op_24: DISPATCH_CALL bit_zeropage            ; $24  BIT zpg
op_25: DISPATCH_CALL and_zeropage            ; $25  AND zpg
op_26: DISPATCH_CALL rol_zeropage            ; $26  ROL zpg
op_27: DISPATCH_CALL rla_zeropage            ; $27  RLA zpg
op_28: DISPATCH_CALL plp_instr               ; $28  PLP
op_29: DISPATCH_CALL and_immediate           ; $29  AND imm
op_2A: DISPATCH_CALL rol_accumulator         ; $2A  ROL acc
op_2B: DISPATCH_CALL anc_immediate           ; $2B  ANC imm (unofficial, same as $0B)
op_2C: DISPATCH_CALL bit_absolute            ; $2C  BIT abs
op_2D: DISPATCH_CALL and_absolute            ; $2D  AND abs
op_2E: DISPATCH_CALL rol_absolute            ; $2E  ROL abs
op_2F: DISPATCH_CALL rla_absolute            ; $2F  RLA abs
op_30: DISPATCH_CALL bmi_instr               ; $30  BMI
op_31: DISPATCH_CALL and_indirect_y          ; $31  AND (ind),Y
op_32: DISPATCH_CALL kil_instr               ; $32  KIL (halt)
op_33: DISPATCH_CALL rla_indirect_y          ; $33  RLA (ind),Y
op_34: DISPATCH_CALL nop_zeropage_x_unofficial ; $34  NOP zpg,X (unofficial)
op_35: DISPATCH_CALL and_zeropage_x          ; $35  AND zpg,X
op_36: DISPATCH_CALL rol_zeropage_x          ; $36  ROL zpg,X
op_37: DISPATCH_CALL rla_zeropage_x          ; $37  RLA zpg,X
op_38: DISPATCH_CALL sec_instr               ; $38  SEC
op_39: DISPATCH_CALL and_absolute_y          ; $39  AND abs,Y
op_3A: DISPATCH_CALL nop_implied_unofficial  ; $3A  NOP (unofficial)
op_3B: DISPATCH_CALL rla_absolute_y          ; $3B  RLA abs,Y
op_3C: DISPATCH_CALL nop_absolute_x_unofficial ; $3C  NOP abs,X (unofficial)
op_3D: DISPATCH_CALL and_absolute_x          ; $3D  AND abs,X
op_3E: DISPATCH_CALL rol_absolute_x          ; $3E  ROL abs,X
op_3F: DISPATCH_CALL rla_absolute_x          ; $3F  RLA abs,X
op_40: DISPATCH_CALL rti_instr               ; $40  RTI
op_41: DISPATCH_CALL eor_indirect_x          ; $41  EOR (ind,X)
op_42: DISPATCH_CALL kil_instr               ; $42  KIL (halt)
op_43: DISPATCH_CALL sre_indirect_x          ; $43  SRE (ind,X)
op_44: DISPATCH_CALL nop_zeropage_unofficial ; $44  NOP zpg (unofficial)
op_45: DISPATCH_CALL eor_zeropage            ; $45  EOR zpg
op_46: DISPATCH_CALL lsr_zeropage            ; $46  LSR zpg
op_47: DISPATCH_CALL sre_zeropage            ; $47  SRE zpg
op_48: DISPATCH_CALL pha_instr               ; $48  PHA
op_49: DISPATCH_CALL eor_immediate           ; $49  EOR imm
op_4A: DISPATCH_CALL lsr_accumulator         ; $4A  LSR acc
op_4B: DISPATCH_CALL alr_immediate           ; $4B  ALR imm (unofficial)
op_4C: DISPATCH_CALL jmp_absolute            ; $4C  JMP abs
op_4D: DISPATCH_CALL eor_absolute            ; $4D  EOR abs
op_4E: DISPATCH_CALL lsr_absolute            ; $4E  LSR abs
op_4F: DISPATCH_CALL sre_absolute            ; $4F  SRE abs
op_50: DISPATCH_CALL bvc_instr               ; $50  BVC
op_51: DISPATCH_CALL eor_indirect_y          ; $51  EOR (ind),Y
op_52: DISPATCH_CALL kil_instr               ; $52  KIL (halt)
op_53: DISPATCH_CALL sre_indirect_y          ; $53  SRE (ind),Y
op_54: DISPATCH_CALL nop_zeropage_x_unofficial ; $54  NOP zpg,X (unofficial)
op_55: DISPATCH_CALL eor_zeropage_x          ; $55  EOR zpg,X
op_56: DISPATCH_CALL lsr_zeropage_x          ; $56  LSR zpg,X
op_57: DISPATCH_CALL sre_zeropage_x          ; $57  SRE zpg,X
op_58: DISPATCH_CALL cli_instr               ; $58  CLI
op_59: DISPATCH_CALL eor_absolute_y          ; $59  EOR abs,Y
op_5A: DISPATCH_CALL nop_implied_unofficial  ; $5A  NOP (unofficial)
op_5B: DISPATCH_CALL sre_absolute_y          ; $5B  SRE abs,Y
op_5C: DISPATCH_CALL nop_absolute_x_unofficial ; $5C  NOP abs,X (unofficial)
op_5D: DISPATCH_CALL eor_absolute_x          ; $5D  EOR abs,X
op_5E: DISPATCH_CALL lsr_absolute_x          ; $5E  LSR abs,X
op_5F: DISPATCH_CALL sre_absolute_x          ; $5F  SRE abs,X
op_60: DISPATCH_CALL rts_instr               ; $60  RTS
op_61: DISPATCH_CALL adc_indirect_x          ; $61  ADC (ind,X)
op_62: DISPATCH_CALL kil_instr               ; $62  KIL (halt)
op_63: DISPATCH_CALL rra_indirect_x          ; $63  RRA (ind,X)
op_64: DISPATCH_CALL nop_zeropage_unofficial ; $64  NOP zpg (unofficial)
op_65: DISPATCH_CALL adc_zeropage            ; $65  ADC zpg
op_66: DISPATCH_CALL ror_zeropage            ; $66  ROR zpg
op_67: DISPATCH_CALL rra_zeropage            ; $67  RRA zpg
op_68: DISPATCH_CALL pla_instr               ; $68  PLA
op_69: DISPATCH_CALL adc_immediate           ; $69  ADC imm
op_6A: DISPATCH_CALL ror_accumulator         ; $6A  ROR acc
op_6B: DISPATCH_CALL arr_immediate           ; $6B  ARR imm (unofficial)
op_6C: DISPATCH_CALL jmp_indirect            ; $6C  JMP ind
op_6D: DISPATCH_CALL adc_absolute            ; $6D  ADC abs
op_6E: DISPATCH_CALL ror_absolute            ; $6E  ROR abs
op_6F: DISPATCH_CALL rra_absolute            ; $6F  RRA abs
op_70: DISPATCH_CALL bvs_instr               ; $70  BVS
op_71: DISPATCH_CALL adc_indirect_y          ; $71  ADC (ind),Y
op_72: DISPATCH_CALL kil_instr               ; $72  KIL (halt)
op_73: DISPATCH_CALL rra_indirect_y          ; $73  RRA (ind),Y
op_74: DISPATCH_CALL nop_zeropage_x_unofficial ; $74  NOP zpg,X (unofficial)
op_75: DISPATCH_CALL adc_zeropage_x          ; $75  ADC zpg,X
op_76: DISPATCH_CALL ror_zeropage_x          ; $76  ROR zpg,X
op_77: DISPATCH_CALL rra_zeropage_x          ; $77  RRA zpg,X
op_78: DISPATCH_CALL sei_instr               ; $78  SEI
op_79: DISPATCH_CALL adc_absolute_y          ; $79  ADC abs,Y
op_7A: DISPATCH_CALL nop_implied_unofficial  ; $7A  NOP (unofficial)
op_7B: DISPATCH_CALL rra_absolute_y          ; $7B  RRA abs,Y
op_7C: DISPATCH_CALL nop_absolute_x_unofficial ; $7C  NOP abs,X (unofficial)
op_7D: DISPATCH_CALL adc_absolute_x          ; $7D  ADC abs,X
op_7E: DISPATCH_CALL ror_absolute_x          ; $7E  ROR abs,X
op_7F: DISPATCH_CALL rra_absolute_x          ; $7F  RRA abs,X
op_80: DISPATCH_CALL nop_immediate           ; $80  NOP imm (unofficial)
op_81: DISPATCH_CALL sta_indirect_x          ; $81  STA (ind,X)
op_82: DISPATCH_CALL nop_immediate           ; $82  NOP imm (unofficial)
op_83: DISPATCH_CALL sax_indirect_x          ; $83  SAX (ind,X)
op_84: DISPATCH_CALL sty_zeropage            ; $84  STY zpg
op_85: DISPATCH_CALL sta_zeropage            ; $85  STA zpg
op_86: DISPATCH_CALL stx_zeropage            ; $86  STX zpg
op_87: DISPATCH_CALL sax_zeropage            ; $87  SAX zpg
op_88: DISPATCH_CALL dey_instr               ; $88  DEY
op_89: DISPATCH_CALL nop_immediate           ; $89  NOP imm (unofficial)
op_8A: DISPATCH_CALL txa_instr               ; $8A  TXA
op_8B: DISPATCH_CALL ane_immediate           ; $8B  ANE/XAA imm (unofficial, unstable)
op_8C: DISPATCH_CALL sty_absolute            ; $8C  STY abs
op_8D: DISPATCH_CALL sta_absolute            ; $8D  STA abs
op_8E: DISPATCH_CALL stx_absolute            ; $8E  STX abs
op_8F: DISPATCH_CALL sax_absolute            ; $8F  SAX abs
op_90: DISPATCH_CALL bcc_instr               ; $90  BCC
op_91: DISPATCH_CALL sta_indirect_y          ; $91  STA (ind),Y
op_92: DISPATCH_CALL kil_instr               ; $92  KIL (halt)
op_93: DISPATCH_CALL sha_indirect_y          ; $93  SHA (ind),Y (unstable)
op_94: DISPATCH_CALL sty_zeropage_x          ; $94  STY zpg,X
op_95: DISPATCH_CALL sta_zeropage_x          ; $95  STA zpg,X
op_96: DISPATCH_CALL stx_zeropage_y          ; $96  STX zpg,Y
op_97: DISPATCH_CALL sax_zeropage_y          ; $97  SAX zpg,Y
op_98: DISPATCH_CALL tya_instr               ; $98  TYA
op_99: DISPATCH_CALL sta_absolute_y          ; $99  STA abs,Y
op_9A: DISPATCH_CALL txs_instr               ; $9A  TXS
op_9B: DISPATCH_CALL tas_absolute_y          ; $9B  TAS abs,Y (unstable)
op_9C: DISPATCH_CALL shy_absolute_x          ; $9C  SHY abs,X (unstable)
op_9D: DISPATCH_CALL sta_absolute_x          ; $9D  STA abs,X
op_9E: DISPATCH_CALL shx_absolute_y          ; $9E  SHX abs,Y (unstable)
op_9F: DISPATCH_CALL sha_absolute_y          ; $9F  SHA abs,Y (unstable)
op_A0: DISPATCH_CALL ldy_immediate           ; $A0  LDY imm
op_A1: DISPATCH_CALL lda_indirect_x          ; $A1  LDA (ind,X)
op_A2: DISPATCH_CALL ldx_immediate           ; $A2  LDX imm
op_A3: DISPATCH_CALL lax_indirect_x          ; $A3  LAX (ind,X)
op_A4: DISPATCH_CALL ldy_zeropage            ; $A4  LDY zpg
op_A5: DISPATCH_CALL lda_zeropage            ; $A5  LDA zpg
op_A6: DISPATCH_CALL ldx_zeropage            ; $A6  LDX zpg
op_A7: DISPATCH_CALL lax_zeropage            ; $A7  LAX zpg
op_A8: DISPATCH_CALL tay_instr               ; $A8  TAY
op_A9: DISPATCH_CALL lda_immediate           ; $A9  LDA imm
op_AA: DISPATCH_CALL tax_instr               ; $AA  TAX
op_AB: DISPATCH_CALL lxa_immediate           ; $AB  LXA/LAX imm (unofficial, unstable)
op_AC: DISPATCH_CALL ldy_absolute            ; $AC  LDY abs
op_AD: DISPATCH_CALL lda_absolute            ; $AD  LDA abs
op_AE: DISPATCH_CALL ldx_absolute            ; $AE  LDX abs
op_AF: DISPATCH_CALL lax_absolute            ; $AF  LAX abs
op_B0: DISPATCH_CALL bcs_instr               ; $B0  BCS
op_B1: DISPATCH_CALL lda_indirect_y          ; $B1  LDA (ind),Y
op_B2: DISPATCH_CALL kil_instr               ; $B2  KIL (halt)
op_B3: DISPATCH_CALL lax_indirect_y          ; $B3  LAX (ind),Y
op_B4: DISPATCH_CALL ldy_zeropage_x          ; $B4  LDY zpg,X
op_B5: DISPATCH_CALL lda_zeropage_x          ; $B5  LDA zpg,X
op_B6: DISPATCH_CALL ldx_zeropage_y          ; $B6  LDX zpg,Y
op_B7: DISPATCH_CALL lax_zeropage_y          ; $B7  LAX zpg,Y
op_B8: DISPATCH_CALL clv_instr               ; $B8  CLV
op_B9: DISPATCH_CALL lda_absolute_y          ; $B9  LDA abs,Y
op_BA: DISPATCH_CALL tsx_instr               ; $BA  TSX
op_BB: DISPATCH_CALL las_absolute_y          ; $BB  LAS abs,Y
op_BC: DISPATCH_CALL ldy_absolute_x          ; $BC  LDY abs,X
op_BD: DISPATCH_CALL lda_absolute_x          ; $BD  LDA abs,X
op_BE: DISPATCH_CALL ldx_absolute_y          ; $BE  LDX abs,Y
op_BF: DISPATCH_CALL lax_absolute_y          ; $BF  LAX abs,Y
op_C0: DISPATCH_CALL cpy_immediate           ; $C0  CPY imm
op_C1: DISPATCH_CALL cmp_indirect_x          ; $C1  CMP (ind,X)
op_C2: DISPATCH_CALL nop_immediate           ; $C2  NOP imm (unofficial)
op_C3: DISPATCH_CALL dcp_indirect_x          ; $C3  DCP (ind,X)
op_C4: DISPATCH_CALL cpy_zeropage            ; $C4  CPY zpg
op_C5: DISPATCH_CALL cmp_zeropage            ; $C5  CMP zpg
op_C6: DISPATCH_CALL dec_zeropage            ; $C6  DEC zpg
op_C7: DISPATCH_CALL dcp_zeropage            ; $C7  DCP zpg
op_C8: DISPATCH_CALL iny_instr               ; $C8  INY
op_C9: DISPATCH_CALL cmp_immediate           ; $C9  CMP imm
op_CA: DISPATCH_CALL dex_instr               ; $CA  DEX
op_CB: DISPATCH_CALL axs_immediate           ; $CB  AXS/SBX imm (unofficial)
op_CC: DISPATCH_CALL cpy_absolute            ; $CC  CPY abs
op_CD: DISPATCH_CALL cmp_absolute            ; $CD  CMP abs
op_CE: DISPATCH_CALL dec_absolute            ; $CE  DEC abs
op_CF: DISPATCH_CALL dcp_absolute            ; $CF  DCP abs
op_D0: DISPATCH_CALL bne_instr               ; $D0  BNE
op_D1: DISPATCH_CALL cmp_indirect_y          ; $D1  CMP (ind),Y
op_D2: DISPATCH_CALL kil_instr               ; $D2  KIL (halt)
op_D3: DISPATCH_CALL dcp_indirect_y          ; $D3  DCP (ind),Y
op_D4: DISPATCH_CALL nop_zeropage_x_unofficial ; $D4  NOP zpg,X (unofficial)
op_D5: DISPATCH_CALL cmp_zeropage_x          ; $D5  CMP zpg,X
op_D6: DISPATCH_CALL dec_zeropage_x          ; $D6  DEC zpg,X
op_D7: DISPATCH_CALL dcp_zeropage_x          ; $D7  DCP zpg,X
op_D8: DISPATCH_CALL cld_instr               ; $D8  CLD
op_D9: DISPATCH_CALL cmp_absolute_y          ; $D9  CMP abs,Y
op_DA: DISPATCH_CALL nop_implied_unofficial  ; $DA  NOP (unofficial)
op_DB: DISPATCH_CALL dcp_absolute_y          ; $DB  DCP abs,Y
op_DC: DISPATCH_CALL nop_absolute_x_unofficial ; $DC  NOP abs,X (unofficial)
op_DD: DISPATCH_CALL cmp_absolute_x          ; $DD  CMP abs,X
op_DE: DISPATCH_CALL dec_absolute_x          ; $DE  DEC abs,X
op_DF: DISPATCH_CALL dcp_absolute_x          ; $DF  DCP abs,X
op_E0: DISPATCH_CALL cpx_immediate           ; $E0  CPX imm
op_E1: DISPATCH_CALL sbc_indirect_x          ; $E1  SBC (ind,X)
op_E2: DISPATCH_CALL nop_immediate           ; $E2  NOP imm (unofficial)
op_E3: DISPATCH_CALL isc_indirect_x          ; $E3  ISC (ind,X)
op_E4: DISPATCH_CALL cpx_zeropage            ; $E4  CPX zpg
op_E5: DISPATCH_CALL sbc_zeropage            ; $E5  SBC zpg
op_E6: DISPATCH_CALL inc_zeropage            ; $E6  INC zpg
op_E7: DISPATCH_CALL isc_zeropage            ; $E7  ISC zpg
op_E8: DISPATCH_CALL inx_instr               ; $E8  INX
op_E9: DISPATCH_CALL sbc_immediate           ; $E9  SBC imm
op_EA: DISPATCH_CALL nop_instr               ; $EA  NOP
op_EB: DISPATCH_CALL sbc_immediate_eb        ; $EB  SBC imm (unofficial, same as $E9)
op_EC: DISPATCH_CALL cpx_absolute            ; $EC  CPX abs
op_ED: DISPATCH_CALL sbc_absolute            ; $ED  SBC abs
op_EE: DISPATCH_CALL inc_absolute            ; $EE  INC abs
op_EF: DISPATCH_CALL isc_absolute            ; $EF  ISC abs
op_F0: DISPATCH_CALL beq_instr               ; $F0  BEQ
op_F1: DISPATCH_CALL sbc_indirect_y          ; $F1  SBC (ind),Y
op_F2: DISPATCH_CALL kil_instr               ; $F2  KIL (halt)
op_F3: DISPATCH_CALL isc_indirect_y          ; $F3  ISC (ind),Y
op_F4: DISPATCH_CALL nop_zeropage_x_unofficial ; $F4  NOP zpg,X (unofficial)
op_F5: DISPATCH_CALL sbc_zeropage_x          ; $F5  SBC zpg,X
op_F6: DISPATCH_CALL inc_zeropage_x          ; $F6  INC zpg,X
op_F7: DISPATCH_CALL isc_zeropage_x          ; $F7  ISC zpg,X
op_F8: DISPATCH_CALL sed_instr               ; $F8  SED
op_F9: DISPATCH_CALL sbc_absolute_y          ; $F9  SBC abs,Y
op_FA: DISPATCH_CALL nop_implied_unofficial  ; $FA  NOP (unofficial)
op_FB: DISPATCH_CALL isc_absolute_y          ; $FB  ISC abs,Y
op_FC: DISPATCH_CALL nop_absolute_x_unofficial ; $FC  NOP abs,X (unofficial)
op_FD: DISPATCH_CALL sbc_absolute_x          ; $FD  SBC abs,X
op_FE: DISPATCH_CALL inc_absolute_x          ; $FE  INC abs,X
op_FF: DISPATCH_CALL isc_absolute_x          ; $FF  ISC abs,X

; Jump table — 256 entries, one per opcode
; Must be in .data (not .rodata) because it holds absolute address relocations.
section .data
align 8
opcode_table:
    dq op_00, op_01, op_02, op_03, op_04, op_05, op_06, op_07
    dq op_08, op_09, op_0A, op_0B, op_0C, op_0D, op_0E, op_0F
    dq op_10, op_11, op_12, op_13, op_14, op_15, op_16, op_17
    dq op_18, op_19, op_1A, op_1B, op_1C, op_1D, op_1E, op_1F
    dq op_20, op_21, op_22, op_23, op_24, op_25, op_26, op_27
    dq op_28, op_29, op_2A, op_2B, op_2C, op_2D, op_2E, op_2F
    dq op_30, op_31, op_32, op_33, op_34, op_35, op_36, op_37
    dq op_38, op_39, op_3A, op_3B, op_3C, op_3D, op_3E, op_3F
    dq op_40, op_41, op_42, op_43, op_44, op_45, op_46, op_47
    dq op_48, op_49, op_4A, op_4B, op_4C, op_4D, op_4E, op_4F
    dq op_50, op_51, op_52, op_53, op_54, op_55, op_56, op_57
    dq op_58, op_59, op_5A, op_5B, op_5C, op_5D, op_5E, op_5F
    dq op_60, op_61, op_62, op_63, op_64, op_65, op_66, op_67
    dq op_68, op_69, op_6A, op_6B, op_6C, op_6D, op_6E, op_6F
    dq op_70, op_71, op_72, op_73, op_74, op_75, op_76, op_77
    dq op_78, op_79, op_7A, op_7B, op_7C, op_7D, op_7E, op_7F
    dq op_80, op_81, op_82, op_83, op_84, op_85, op_86, op_87
    dq op_88, op_89, op_8A, op_8B, op_8C, op_8D, op_8E, op_8F
    dq op_90, op_91, op_92, op_93, op_94, op_95, op_96, op_97
    dq op_98, op_99, op_9A, op_9B, op_9C, op_9D, op_9E, op_9F
    dq op_A0, op_A1, op_A2, op_A3, op_A4, op_A5, op_A6, op_A7
    dq op_A8, op_A9, op_AA, op_AB, op_AC, op_AD, op_AE, op_AF
    dq op_B0, op_B1, op_B2, op_B3, op_B4, op_B5, op_B6, op_B7
    dq op_B8, op_B9, op_BA, op_BB, op_BC, op_BD, op_BE, op_BF
    dq op_C0, op_C1, op_C2, op_C3, op_C4, op_C5, op_C6, op_C7
    dq op_C8, op_C9, op_CA, op_CB, op_CC, op_CD, op_CE, op_CF
    dq op_D0, op_D1, op_D2, op_D3, op_D4, op_D5, op_D6, op_D7
    dq op_D8, op_D9, op_DA, op_DB, op_DC, op_DD, op_DE, op_DF
    dq op_E0, op_E1, op_E2, op_E3, op_E4, op_E5, op_E6, op_E7
    dq op_E8, op_E9, op_EA, op_EB, op_EC, op_ED, op_EE, op_EF
    dq op_F0, op_F1, op_F2, op_F3, op_F4, op_F5, op_F6, op_F7
    dq op_F8, op_F9, op_FA, op_FB, op_FC, op_FD, op_FE, op_FF

section .bss
global sp_pointer
sp_pointer: resq 1

; Memory read callback pointer (for routing reads through MemoryBus)
global memory_read_callback
memory_read_callback: resq 1

; Memory write pointer (for direct writes - preserved as-is per task requirements)
global memory_write_pointer
memory_write_pointer: resq 1

; Interrupt State Variables
; Global interrupt state variables for NMI and IRQ handling
; These are exported for C++ access and initialized to 0 by .bss section

global nmi_pending
nmi_pending:    resb 1          ; NMI pending flag (uint8_t)

global nmi_previous
nmi_previous:   resb 1          ; Previous NMI line state for edge detection (uint8_t)

global irq_asserted
irq_asserted:   resb 1          ; IRQ line active flag (uint8_t)

global irq_counter
irq_counter:    resd 1          ; IRQ reference counter (int32_t)

section .text
; Transfer Instructions

; TYA - Transfer Y to Accumulator ($98) - 2 cycles
global tya_instr
tya_instr:
    mov al, [r9]        ; Get Y value
    mov [rdx], al       ; Store in A
    mov rdi, rcx        ; P pointer
    call set_zn_flags   ; Set Z and N flags
    mov eax, 2
    ret

; TAY - Transfer Accumulator to Y ($A8) - 2 cycles
global tay_instr
tay_instr:
    mov al, [rdx]       ; Get A value
    mov [r9], al        ; Store in Y
    mov rdi, rcx        ; P pointer
    call set_zn_flags   ; Set Z and N flags
    mov eax, 2
    ret

; TAX - Transfer Accumulator to X ($AA) - 2 cycles
global tax_instr
tax_instr:
    mov al, [rdx]       ; Get A value
    mov [r8], al        ; Store in X
    mov rdi, rcx        ; P pointer
    call set_zn_flags   ; Set Z and N flags
    mov eax, 2
    ret

; TXA - Transfer X to Accumulator ($8A) - 2 cycles
global txa_instr
txa_instr:
    mov al, [r8]        ; Get X value
    mov [rdx], al       ; Store in A
    mov rdi, rcx        ; P pointer
    call set_zn_flags   ; Set Z and N flags
    mov eax, 2
    ret

; TSX - Transfer Stack Pointer to X ($BA) - 2 cycles
global tsx_instr
tsx_instr:
    ; Get SP value from the stored SP pointer
    push rbx
    mov rbx, [rel sp_pointer]
    mov al, [rbx]       ; Get SP value
    mov [r8], al        ; Store in X
    mov rdi, rcx
    call set_zn_flags
    pop rbx
    mov eax, 2
    ret

; TXS - Transfer X to Stack Pointer ($9A) - 2 cycles
global txs_instr
txs_instr:
    mov al, [r8]        ; Get X value
    push rbx
    mov rbx, [rel sp_pointer]
    mov [rbx], al       ; Store in SP
    pop rbx
    ; TXS does NOT set flags
    mov eax, 2
    ret

; Compare Instructions
; All compare instructions do:
;   temp = register - memory_value
;   Set C=1 if register >= memory_value (unsigned)
;   Set Z=1 if register == memory_value
;   Set N=1 if bit 7 of temp is set

; CMP - Compare Accumulator with Memory

; CMP Immediate ($C9) - 2 cycles
global cmp_immediate
cmp_immediate:
    push rbx
    push r12
    
    ; Get PC value
    movzx r11, word [rsi]
    
    ; Read operand from memory[PC] using callback
    call read_memory_byte           ; Returns byte in al
    movzx r12, al                   ; r12 = operand
    
    ; Increment PC
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; CMP: temp = A - operand
    mov al, [rdx]                   ; Get A value
    sub al, r12b                    ; al = A - operand
    
    ; Carry flag: C=1 if A >= operand (no borrow)
    setnc r12b                      ; r12b = 1 if carry set
    
    ; Set carry flag
    movzx esi, r12b
    mov rdi, rcx
    call set_carry_flag
    
    ; Set Z and N flags from result
    mov rdi, rcx
    call set_zn_flags
    
    pop r12
    pop rbx
    mov eax, 2
    ret

; CMP Zeropage ($C5) - 3 cycles
global cmp_zeropage
cmp_zeropage:
    push rbx
    push r12
    
    ; Get PC
    movzx r11, word [rsi]
    
    ; Read zeropage address using callback
    call read_memory_byte           ; Returns byte in al
    movzx r12, al                   ; r12 = zeropage address
    
    ; Increment PC
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Read value from zeropage using callback
    movzx r11, r12w                 ; r11 = zeropage address
    call read_memory_byte           ; Returns byte in al
    mov r12b, al                    ; r12b = memory value
    
    ; CMP: temp = A - operand
    mov al, [rdx]                   ; Get A value
    sub al, r12b                    ; al = A - operand
    
    ; Carry flag
    setnc r12b
    movzx esi, r12b
    mov rdi, rcx
    call set_carry_flag
    
    ; Set Z and N flags
    mov rdi, rcx
    call set_zn_flags
    
    pop r12
    pop rbx
    mov eax, 3
    ret

; CMP Absolute ($CD) - 4 cycles
global cmp_absolute
cmp_absolute:
    push rbx
    push r12
    push r13
    
    ; Get PC
    movzx r11, word [rsi]
    
    ; Read low byte of address using callback
    call read_memory_byte           ; Returns byte in al
    movzx r12, al                   ; r12 = low byte
    
    ; Increment PC
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Read high byte of address using callback
    movzx r11, word [rsi]
    call read_memory_byte           ; Returns byte in al
    movzx r13, al                   ; r13 = high byte
    shl r13, 8
    or r12, r13                     ; r12 = 16-bit address
    
    ; Increment PC by 1 more (total +2)
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Read value from absolute address using callback
    movzx r11, r12w                 ; r11 = absolute address
    call read_memory_byte           ; Returns byte in al
    mov r12b, al                    ; r12b = memory value
    
    ; CMP: temp = A - operand
    mov al, [rdx]
    sub al, r12b
    
    ; Carry flag
    setnc r12b
    movzx esi, r12b
    mov rdi, rcx
    call set_carry_flag
    
    ; Set Z and N flags
    mov rdi, rcx
    call set_zn_flags
    
    pop r13
    pop r12
    pop rbx
    mov eax, 4
    ret

; CMP — additional addressing modes (task 5)
; Uses addr_modes.inc macros; memory pointer saved in r12 before flag calls.
; Pattern mirrors cmp_zeropage / cmp_absolute already in cpu.asm.
; NOTE: set_carry_flag / set_zn_flags do NOT modify al — al holds the
;       subtraction result safely across both calls.
%include "addr_modes.inc"

; CMP Zeropage,X ($D5) - 4 cycles — A - mem; sets N, Z, C
global cmp_zeropage_x
cmp_zeropage_x:
    push rbx
    push r12
    push r13

    mov r12, rdi                ; r12 = memory pointer
    ADDR_ZEROPAGE_X             ; rbx = (base + X) & 0xFF; PC advanced

    ; Read operand from memory using callback
    movzx r11, bx                ; r11 = zeropage address
    call read_memory_byte        ; Returns byte in al
    movzx r13d, al               ; r13b = operand from memory

    ; CMP: temp = A - operand; keep result in al for flag helpers
    mov al, [rdx]               ; al = A
    sub al, r13b                ; al = A - operand  (x86 CF set on borrow)
    setnc r13b                  ; r13b = 1 if no borrow (A >= operand) → 6502 C=1

    ; set_carry_flag(rdi=P*, sil=carry) — does NOT clobber al
    movzx esi, r13b
    mov rdi, rcx                ; rdi = P*
    call set_carry_flag

    ; set_zn_flags(rdi=P*, al=result) — al still holds subtraction result
    mov rdi, rcx
    call set_zn_flags

    pop r13
    pop r12
    pop rbx
    mov eax, 4
    ret

; CMP Absolute,X ($DD) - 4+1 cycles (page-cross penalty)
global cmp_absolute_x
cmp_absolute_x:
    push rbx
    push r12
    push r13

    mov r12, rdi                ; r12 = memory pointer
    ADDR_ABSOLUTE_X             ; rbx = effective addr; r13d = page-crossed flag

    ; Read operand from memory using callback
    movzx r11, bx                ; r11 = effective address
    call read_memory_byte        ; Returns byte in al
    push rax                     ; save operand (r13d = page flag, can't reuse r13)

    mov al, [rdx]               ; al = A
    sub al, [rsp]               ; al = A - operand
    setnc r12b                    ; cl = carry (no-borrow)

    movzx esi, r12b
    mov rdi, rcx
    call set_carry_flag

    mov rdi, rcx
    call set_zn_flags

    pop rax                     ; discard saved operand
    mov eax, 4
    add eax, r13d               ; +1 if page crossed
    pop r13
    pop r12
    pop rbx
    ret

; CMP Absolute,Y ($D9) - 4+1 cycles (page-cross penalty)
global cmp_absolute_y
cmp_absolute_y:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_ABSOLUTE_Y             ; rbx = effective addr; r13d = page-crossed flag

    ; Read operand from memory using callback
    movzx r11, bx                ; r11 = effective address
    call read_memory_byte        ; Returns byte in al
    push rax

    mov al, [rdx]               ; al = A
    sub al, [rsp]               ; al = A - operand
    setnc r12b

    movzx esi, r12b
    mov rdi, rcx
    call set_carry_flag

    mov rdi, rcx
    call set_zn_flags

    pop rax
    mov eax, 4
    add eax, r13d
    pop r13
    pop r12
    pop rbx
    ret

; CMP (Indirect,X) ($C1) - 6 cycles
global cmp_indirect_x
cmp_indirect_x:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_INDIRECT_X             ; rbx = effective 16-bit address; PC advanced

    ; Read operand from memory using callback
    movzx r11, bx                ; r11 = effective address
    call read_memory_byte        ; Returns byte in al
    movzx r13d, al               ; r13b = operand

    mov al, [rdx]               ; al = A
    sub al, r13b                ; al = A - operand
    setnc r13b                  ; r13b = carry

    movzx esi, r13b
    mov rdi, rcx
    call set_carry_flag

    mov rdi, rcx
    call set_zn_flags

    pop r13
    pop r12
    pop rbx
    mov eax, 6
    ret

; CMP (Indirect),Y ($D1) - 5+1 cycles (page-cross penalty)
global cmp_indirect_y
cmp_indirect_y:
    push rbx
    push r12
    push r13

    mov r12, rdi
    ADDR_INDIRECT_Y             ; rbx = effective addr; r13d = page-crossed flag

    ; Read operand from memory using callback
    movzx r11, bx                ; r11 = effective address
    call read_memory_byte        ; Returns byte in al
    push rax                     ; save operand (r13d holds page flag)

    mov al, [rdx]               ; al = A
    sub al, [rsp]               ; al = A - operand
    setnc r12b

    movzx esi, r12b
    mov rdi, rcx
    call set_carry_flag

    mov rdi, rcx
    call set_zn_flags

    pop rax
    mov eax, 5
    add eax, r13d
    pop r13
    pop r12
    pop rbx
    ret

; CPX - Compare X Register with Memory

; CPX Immediate ($E0) - 2 cycles
global cpx_immediate
cpx_immediate:
    push rbx
    push r12
    
    ; Read operand from memory[PC] using callback
    movzx r11, word [rsi]
    call read_memory_byte        ; Returns byte in al
    movzx r12, al                ; r12 = operand
    
    ; Increment PC
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; temp = X - operand
    mov al, [r8]
    sub al, r12b
    
    setnc r12b
    movzx esi, r12b
    mov rdi, rcx
    call set_carry_flag
    
    mov rdi, rcx
    call set_zn_flags
    
    pop r12
    pop rbx
    mov eax, 2
    ret
    pop rbx
    mov eax, 2
    ret

; CPX Zeropage ($E4) - 3 cycles
global cpx_zeropage
cpx_zeropage:
    push rbx
    push r12
    
    ; Read zeropage address using callback
    movzx r11, word [rsi]
    call read_memory_byte        ; Returns byte in al
    movzx r12, al                ; r12 = zeropage address
    
    ; Increment PC
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Read value from zeropage using callback
    movzx r11, r12w
    call read_memory_byte        ; Returns byte in al
    mov r12b, al
    
    mov al, [r8]
    sub al, r12b
    
    setnc r12b
    movzx esi, r12b
    mov rdi, rcx
    call set_carry_flag
    
    mov rdi, rcx
    call set_zn_flags
    
    pop r12
    pop rbx
    mov eax, 3
    ret

; CPX Absolute ($EC) - 4 cycles
global cpx_absolute
cpx_absolute:
    push rbx
    push r12
    push r13
    
    ; Read low byte of address using callback
    movzx r11, word [rsi]
    call read_memory_byte        ; Returns byte in al
    movzx r12, al
    
    ; Increment PC
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Read high byte of address using callback
    movzx r11, word [rsi]
    call read_memory_byte        ; Returns byte in al
    movzx r13, al
    shl r13, 8
    or r12, r13
    
    ; Increment PC again (total +2)
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Read value from absolute address using callback
    movzx r11, r12w
    call read_memory_byte        ; Returns byte in al
    mov r12b, al
    
    mov al, [r8]
    sub al, r12b
    
    setnc r12b
    movzx esi, r12b
    mov rdi, rcx
    call set_carry_flag
    
    mov rdi, rcx
    call set_zn_flags
    
    pop r13
    pop r12
    pop rbx
    mov eax, 4
    ret

; CPY - Compare Y Register with Memory

; CPY Immediate ($C0) - 2 cycles
global cpy_immediate
cpy_immediate:
    push rbx
    push r12
    
    ; Read operand from memory[PC] using callback
    movzx r11, word [rsi]
    call read_memory_byte        ; Returns byte in al
    movzx r12, al
    
    ; Increment PC
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    mov al, [r9]
    sub al, r12b
    
    setnc r12b
    movzx esi, r12b
    mov rdi, rcx
    call set_carry_flag
    
    mov rdi, rcx
    call set_zn_flags
    
    pop r12
    pop rbx
    mov eax, 2
    ret

; CPY Zeropage ($C4) - 3 cycles
global cpy_zeropage
cpy_zeropage:
    push rbx
    push r12
    
    ; Read zeropage address using callback
    movzx r11, word [rsi]
    call read_memory_byte        ; Returns byte in al
    movzx r12, al
    
    ; Increment PC
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Read value from zeropage using callback
    movzx r11, r12w
    call read_memory_byte        ; Returns byte in al
    mov r12b, al
    
    mov al, [r9]
    sub al, r12b
    
    setnc r12b
    movzx esi, r12b
    mov rdi, rcx
    call set_carry_flag
    
    mov rdi, rcx
    call set_zn_flags
    
    pop r12
    pop rbx
    mov eax, 3
    ret

; CPY Absolute ($CC) - 4 cycles
global cpy_absolute
cpy_absolute:
    push rbx
    push r12
    push r13
    
    ; Read low byte of address using callback
    movzx r11, word [rsi]
    call read_memory_byte        ; Returns byte in al
    movzx r12, al
    
    ; Increment PC
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Read high byte of address using callback
    movzx r11, word [rsi]
    call read_memory_byte        ; Returns byte in al
    movzx r13, al
    shl r13, 8
    or r12, r13
    
    ; Increment PC again (total +2)
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Read value from absolute address using callback
    movzx r11, r12w
    call read_memory_byte        ; Returns byte in al
    mov r12b, al
    
    mov al, [r9]
    sub al, r12b
    
    setnc r12b
    movzx esi, r12b
    mov rdi, rcx
    call set_carry_flag
    
    mov rdi, rcx
    call set_zn_flags
    
    pop r13
    pop r12
    pop rbx
    mov eax, 4
    ret

; JMP - Jump

; JMP Absolute ($4C) - 3 cycles
global jmp_absolute
jmp_absolute:
    push rbx
    
    ; Get PC
    movzx r11, word [rsi]
    
    ; Read low byte of target address using callback
    call read_memory_byte        ; Returns byte in al
    movzx ebx, al                ; ebx = low byte
    
    ; Increment PC
    movzx r11, word [rsi]
    inc r11w
    
    ; Read high byte of target address using callback
    call read_memory_byte        ; Returns byte in al
    movzx ecx, al                ; ecx = high byte
    
    ; Combine to form target address
    shl ecx, 8
    or ebx, ecx                  ; ebx = target address
    
    ; Set PC to target address
    mov word [rsi], bx
    
    pop rbx
    mov eax, 3                    ; 3 cycles
    ret

; JMP Indirect ($6C) - 5 cycles
global jmp_indirect
jmp_indirect:
    push rbx
    push r12
    push r13
    push r14
    
    ; Get PC
    movzx r11, word [rsi]
    
    ; Read low byte of pointer address using callback
    call read_memory_byte        ; Returns byte in al
    movzx r12, al                ; r12 = low byte
    
    ; Increment PC
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Read high byte of pointer address using callback
    movzx r11, word [rsi]
    call read_memory_byte        ; Returns byte in al
    movzx r13, al                ; r13 = high byte
    shl r13, 8
    or r12, r13                  ; r12 = pointer address
    
    ; Read low byte of target from pointer using callback
    movzx r11, r12w
    call read_memory_byte        ; Returns byte in al
    movzx ecx, al                ; ecx = low byte of target
    
    ; Read high byte of target (handle 6502 page boundary bug)
    ; If pointer is $xxFF, high byte reads from $xx00 not $(xx+1)00
    movzx eax, r12w              ; Copy pointer address
    inc al                       ; High byte at pointer+1
    and ax, 0x00FF               ; Wrap low byte within page (0x00FF -> 0x0000)
    mov r14, r12
    and r14, 0xFF00              ; Keep original high byte
    or rax, r14                  ; rax = low byte wrapped, high byte same
    
    ; Read high byte using callback
    movzx r11, ax
    call read_memory_byte        ; Returns byte in al
    movzx edx, al                ; edx = high byte of target (with bug)
    
    ; Combine target address
    shl edx, 8
    or ecx, edx                  ; ecx = target address
    
    ; Set PC
    mov word [rsi], cx
    
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 5                    ; 5 cycles
    ret

; BIT - Bit Test

; BIT Zeropage ($24) - 3 cycles
global bit_zeropage
bit_zeropage:
    push rbx
    push r12
    
    ; Get PC
    movzx r11, word [rsi]
    
    ; Read address from zeropage using callback
    call read_memory_byte        ; Returns byte in al
    movzx r12, al                ; r12 = zeropage address
    
    ; Increment PC
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Read value from memory at zeropage address using callback
    movzx r11, r12w
    call read_memory_byte        ; Returns byte in al
    mov r12b, al                 ; r12b = memory value at zeropage address
    
    ; Test A with memory value (set Z flag)
    mov al, [rdx]                ; al = A value
    and al, r12b                 ; al = A & memory_value
    
    ; Set Z flag based on AND result
    test al, al
    jnz .bit_zp_not_zero
    or byte [rcx], 0x02          ; Set Z flag
    jmp .bit_zp_n_flag
.bit_zp_not_zero:
    and byte [rcx], 0xFD         ; Clear Z flag
    
.bit_zp_n_flag:
    ; Set N flag from bit 7 of memory value
    test r12b, 0x80
    jz .bit_zp_no_neg
    or byte [rcx], 0x80          ; Set N flag
    jmp .bit_zp_v_flag
.bit_zp_no_neg:
    and byte [rcx], 0x7F         ; Clear N flag
    
.bit_zp_v_flag:
    ; Set V flag from bit 6 of memory value
    test r12b, 0x40
    jz .bit_zp_no_v
    or byte [rcx], 0x40          ; Set V flag
    jmp .bit_zp_done
.bit_zp_no_v:
    and byte [rcx], 0xBF         ; Clear V flag
    
.bit_zp_done:
    pop r12
    pop rbx
    mov eax, 3                   ; 3 cycles
    ret

; BIT Absolute ($2C) - 4 cycles
global bit_absolute
bit_absolute:
    push rbx
    push r12
    push r13
    
    ; Get PC
    movzx r11, word [rsi]
    
    ; Read low byte of target address using callback
    call read_memory_byte        ; Returns byte in al
    movzx r12, al                ; r12 = low byte
    
    ; Increment PC
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Read high byte of address using callback
    movzx r11, word [rsi]
    call read_memory_byte        ; Returns byte in al
    movzx r13, al                ; r13 = high byte
    shl r13, 8
    or r12, r13                  ; r12 = 16-bit address
    
    ; Increment PC again (total +2)
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    
    ; Read value from memory using callback
    movzx r11, r12w
    call read_memory_byte        ; Returns byte in al
    mov r13b, al                 ; Save memory value
    
    ; FIXED: Changed cl to r10b so it doesn't overwrite your P pointer (rcx)
    mov r10b, [rdx]
    and al, r10b
    
    ; Set Z flag
    test al, al
    jnz .bit_abs_not_zero
    or byte [rcx], 0x02
    jmp .bit_abs_n_flag
.bit_abs_not_zero:
    and byte [rcx], 0xFD
    
.bit_abs_n_flag:
    test r13b, 0x80
    jz .bit_abs_no_neg
    or byte [rcx], 0x80
    jmp .bit_abs_v_flag
.bit_abs_no_neg:
    and byte [rcx], 0x7F
    
.bit_abs_v_flag:
    test r13b, 0x40
    jz .bit_abs_no_v
    or byte [rcx], 0x40
    jmp .bit_abs_done
.bit_abs_no_v:
    and byte [rcx], 0xBF
    
.bit_abs_done:
    pop r13
    pop r12
    pop rbx
    mov eax, 4
    ret

; NOP - No Operation

; NOP Implied ($EA) - 2 cycles
global nop_instr
nop_instr:
    mov eax, 2
    ret

; NOP Immediate ($80, $82, $C2, $E2) - 2 cycles
global nop_immediate
nop_immediate:
    push rbx
    movzx rbx, word [rsi]
    inc bx
    mov word [rsi], bx
    pop rbx
    mov eax, 2
    ret

; Interrupt Handlers

; NMI Interrupt Handler - 7 cycles
; NMI - Non-Maskable Interrupt Handler
; NMI interrupt sequence - 7 cycles total
; Called when nmi_pending flag is set at instruction boundary
; Convention: rdi=memory, rsi=PC*, rdx=A*, rcx=P*, r8=X*, r9=Y*
;
; Cycle-by-cycle breakdown:
;   Cycle 1: Internal operation (opcode fetch dummy read)
;   Cycle 2: Push PCH to stack at $0100 + SP, decrement SP
;   Cycle 3: Push PCL to stack at $0100 + SP, decrement SP
;   Cycle 4: Push P to stack (B=0, unused=1) at $0100 + SP, decrement SP
;   Cycle 5: Read NMI vector low byte from $FFFA
;   Cycle 6: Read NMI vector high byte from $FFFB
;   Cycle 7: Set PC to vector address
;
; Total: 7 cycles.
global nmi_handler
nmi_handler:
    push rbx
    push r12
    push r13
    push r14
    
    ; Get SP pointer from global
    mov r14, [rel sp_pointer]
    
    ; Get current PC
    movzx rbx, word [rsi]
    
    ; Get current SP
    movzx rax, byte [r14]
    
    ; Cycle 1: Internal operation (opcode fetch, not implemented in asm)
    ; Cycle 2: Push PCH (high byte) to stack at $0100 + SP, decrement SP
    mov r12w, bx                  ; Copy PC to r12
    shr r12w, 8                   ; Shift right to get high byte in low position
    add rax, 0x100
    mov [rdi+rax], r12b           ; Write PCH to stack at $0100 + SP
    dec al                        ; Decrement SP (8-bit operation)
    and al, 0xFF                  ; Explicit wrap to ensure 0x00 -> 0xFF
    sub rax, 0x100
    
; Cycle 3: Push PCL (low byte) to stack at $0100 + SP, decrement SP
    mov r12b, bl                  ; Get PCL
    add rax, 0x100
    mov [rdi+rax], r12b           ; Write PCL to stack at $0100 + SP
    dec al                        ; Decrement SP (8-bit operation)
    and al, 0xFF                  ; Explicit wrap to ensure 0x00 -> 0xFF
    sub rax, 0x100
    
    ; Cycle 4: Push P with B flag clear (bit 4 = 0) and unused flag set (bit 5 = 1)
    ;          to stack at $0100 + SP, decrement SP
    movzx r12, byte [rcx]         ; Load P value into r12 (rcx pointer is now intact)
    and r12b, 0xEF                ; Clear B flag (bit 4) - distinguishes NMI from BRK
    or r12b, 0x20                 ; Set unused flag (bit 5) - always set when pushed
    add rax, 0x100
    mov [rdi+rax], r12b           ; Write modified P to stack at $0100 + SP
    dec al                        ; Decrement SP (8-bit operation, final value)
    and al, 0xFF                  ; Explicit wrap to ensure 0x00 -> 0xFF
    sub rax, 0x100
    
    ; Store updated SP
    mov [r14], al
    
    ; Set I flag (bit 2) in live P register (not in pushed copy)
    or byte [rcx], 0x04           ; Set I flag to prevent IRQ during NMI handler
    
; Cycle 5: Read NMI vector low byte from $FFFA
    mov r11w, 0xFFFA              ; Address to read from
    call read_memory_byte         ; Returns byte in al
    movzx r12, al                 ; r12 = low byte of NMI vector
    
; Cycle 6: Read NMI vector high byte from $FFFB
    mov r11w, 0xFFFB              ; Address to read from
    call read_memory_byte         ; Returns byte in al
    movzx r13, al                 ; r13 = high byte of NMI vector
    
    ; Combine vector bytes to form 16-bit address (little-endian)
    shl r13, 8
    or r13, r12
    
; Cycle 7: Set PC to vector address (begin executing NMI handler)
    mov word [rsi], r13w          ; PC now points to NMI handler entry point
    
    ; Clear NMI pending flag (edge-detection - allows next rising edge)
    mov byte [rel nmi_pending], 0
    
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 7                    ; Return 7 cycles
    ret

; IRQ - Interrupt Request Handler
; IRQ interrupt sequence - 7 cycles total
; Handles hardware IRQ interrupts (maskable by I flag)
; Called when IRQ line is asserted and I flag is clear at instruction boundary
; Convention: rdi=memory, rsi=PC*, rdx=A*, rcx=P*, r8=X*, r9=Y*
;
; Cycle-by-cycle breakdown:
;   Cycle 1: Internal operation (opcode fetch dummy read)
;   Cycle 2: Push PCH to stack at $0100 + SP, decrement SP
;   Cycle 3: Push PCL to stack at $0100 + SP, decrement SP
;   Cycle 4: Push P to stack (B=0, unused=1) at $0100 + SP, decrement SP
;   Cycle 5: Read IRQ vector low byte from $FFFE (NMI hijacking can occur here)
;   Cycle 6: Read IRQ vector high byte from $FFFF (NMI hijacking can occur here)
;   Cycle 7: Set PC to vector address
;
; Note: If NMI becomes pending during cycles 5-6 (vector read), the CPU reads
;       from the NMI vector ($FFFA/$FFFB) instead (interrupt hijacking behavior)
;
; Total: 7 cycles.
global irq_handler
irq_handler:
    push rbx
    push r12
    push r13
    push r14
    
    ; Get SP pointer from global
    mov r14, [rel sp_pointer]
    
    ; Get current PC
    movzx rbx, word [rsi]
    
    ; Get current SP
    movzx rax, byte [r14]
    
    ; Cycle 1: Internal operation (opcode fetch, not implemented in asm)
    ; Cycle 2: Push PCH (high byte) to stack at $0100 + SP, decrement SP
    mov r12w, bx                  ; Copy PC to r12
    shr r12w, 8                   ; Shift right to get high byte in low position
    add rax, 0x100
    mov [rdi+rax], r12b           ; Write PCH to stack at $0100 + SP
    dec al                        ; Decrement SP (8-bit operation)
    and al, 0xFF                  ; Explicit wrap to ensure 0x00 -> 0xFF
    sub rax, 0x100
    
; Cycle 3: Push PCL (low byte) to stack at $0100 + SP, decrement SP
    mov r12b, bl                  ; Get PCL
    add rax, 0x100
    mov [rdi+rax], r12b           ; Write PCL to stack at $0100 + SP
    dec al                        ; Decrement SP (8-bit operation)
    and al, 0xFF                  ; Explicit wrap to ensure 0x00 -> 0xFF
    sub rax, 0x100
    
    ; Cycle 4: Push P with B flag clear (bit 4 = 0) and unused flag set (bit 5 = 1)
    ;          to stack at $0100 + SP, decrement SP
    movzx r12, byte [rcx]         ; Load P value into r12
    and r12b, 0xEF                ; Clear B flag (bit 4) - distinguishes IRQ from BRK
    or r12b, 0x20                 ; Set unused flag (bit 5) - always set when pushed
    add rax, 0x100
    mov [rdi+rax], r12b           ; Write modified P to stack at $0100 + SP
    dec al                        ; Decrement SP (8-bit operation, final value)
    and al, 0xFF                  ; Explicit wrap to ensure 0x00 -> 0xFF
    sub rax, 0x100
    
    ; Store updated SP
    mov [r14], al
    
    ; Set I flag (bit 2) in live P register (not in pushed copy)
    or byte [rcx], 0x04           ; Set I flag to prevent nested IRQs
    
    ; Cycle 5: Read IRQ vector low byte from $FFFE
    ; Cycle 6: Read IRQ vector high byte from $FFFF
    ; Check for NMI hijacking during vector fetch (cycles 5-6)
    mov r12b, byte [rel nmi_pending]
    test r12b, r12b
    jnz .nmi_hijack
    
.read_irq_vector:
    ; Read IRQ vector from $FFFE (low byte) and $FFFF (high byte)
    mov r11w, 0xFFFE              ; Address to read from
    call read_memory_byte         ; Cycle 5: Returns byte in al
    movzx r12, al                 ; r12 = low byte of IRQ vector
    
    mov r11w, 0xFFFF              ; Address to read from
    call read_memory_byte         ; Cycle 6: Returns byte in al
    movzx r13, al                 ; r13 = high byte of IRQ vector
    jmp .set_pc
    
.nmi_hijack:
    ; NMI asserted during vector fetch → read NMI vector instead of IRQ vector
    mov r11w, 0xFFFA              ; Address to read from
    call read_memory_byte         ; Cycle 5: Returns byte in al
    movzx r12, al                 ; r12 = low byte of NMI vector
    
    mov r11w, 0xFFFB              ; Address to read from
    call read_memory_byte         ; Cycle 6: Returns byte in al
    movzx r13, al                 ; r13 = high byte of NMI vector
    ; Clear NMI pending since we're servicing it through hijacking
    mov byte [rel nmi_pending], 0
    
.set_pc:
    ; Combine vector bytes to form 16-bit address (little-endian)
    shl r13, 8
    or r13, r12
    
; Cycle 7: Set PC to vector address (begin executing IRQ/NMI handler)
    mov word [rsi], r13w          ; PC now points to handler entry point
    
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 7                    ; Return 7 cycles
    ret

; BRK - Break (Software Interrupt)
; BRK ($00) - 7 cycles total
; Software interrupt instruction, identical to IRQ except B flag is set in pushed P
; Convention: rdi=memory, rsi=PC*, rdx=A*, rcx=P*, r8=X*, r9=Y*
;
; Cycle-by-cycle breakdown:
;   Cycle 1: Fetch BRK opcode (already done in dispatcher)
;   Cycle 2: Push PCH to stack at $0100 + SP, decrement SP
;   Cycle 3: Push PCL to stack at $0100 + SP, decrement SP
;   Cycle 4: Push P to stack (B=1, unused=1) at $0100 + SP, decrement SP
;   Cycle 5: Read IRQ/BRK vector low byte from $FFFE (NMI hijacking can occur)
;   Cycle 6: Read IRQ/BRK vector high byte from $FFFF (NMI hijacking can occur)
;   Cycle 7: Set PC to vector address
;
; Note: PC is pushed as PC+2 (skips the signature byte after $00)
;       B flag in pushed P is set to 1 (distinguishes BRK from IRQ in handler)
;
; Total: 7 cycles.
global brk_instr
brk_instr:
    push rbx
    push r12
    push r13
    push r14
    
    ; Check for NMI pending - NMI hijacks BRK before starting sequence
    mov al, byte [rel nmi_pending]
    test al, al
    jnz .nmi_hijack_brk
    
    ; Get SP pointer from global
    mov r14, [rel sp_pointer]
    
    ; Get current PC (already incremented in dispatcher past $00)
    movzx rbx, word [rsi]
    add bx, 1                     ; PC + 1 (skip the signature byte, so PC+2 total)
    
    ; Get current SP
    movzx rax, byte [r14]
    
    ; Cycle 1: Fetch BRK opcode (handled by dispatcher)
    ; Cycle 2: Push PC+2 high byte to stack at $0100 + SP, decrement SP
    mov r12w, bx                  ; Copy PC+2 to r12
    shr r12w, 8                   ; Shift right to get high byte
    add rax, 0x100
    mov [rdi+rax], r12b           ; Write PCH to stack at $0100 + SP
    dec al                        ; Decrement SP (8-bit operation)
    and al, 0xFF                  ; Explicit wrap to ensure 0x00 -> 0xFF
    sub rax, 0x100
    
; Cycle 3: Push PC+2 low byte to stack at $0100 + SP, decrement SP
    mov r12b, bl                  ; Get PCL
    add rax, 0x100
    mov [rdi+rax], r12b           ; Write PCL to stack at $0100 + SP
    dec al                        ; Decrement SP (8-bit operation)
    and al, 0xFF                  ; Explicit wrap to ensure 0x00 -> 0xFF
    sub rax, 0x100
    
    ; Cycle 4: Push P with B flag SET (bit 4 = 1) and unused flag set (bit 5 = 1)
    ;          to stack at $0100 + SP, decrement SP
    movzx r12, byte [rcx]         ; rcx = P pointer, get P value
    or r12b, 0x30                 ; Set B flag (bit 4) and unused flag (bit 5)
                                  ; B=1 distinguishes BRK from hardware IRQ
    add rax, 0x100
    mov [rdi+rax], r12b           ; Write modified P to stack at $0100 + SP
    dec al                        ; Decrement SP (8-bit operation, final value)
    and al, 0xFF                  ; Explicit wrap to ensure 0x00 -> 0xFF
    sub rax, 0x100
    
    ; Store updated SP
    mov [r14], al
    
    ; Set I flag (bit 2) in live P register (not in pushed copy)
    or byte [rcx], 0x04           ; Set interrupt disable flag
    
    ; Cycle 5: Read BRK/IRQ vector low byte from $FFFE
    ; Cycle 6: Read BRK/IRQ vector high byte from $FFFF
    ; Check for NMI hijacking during vector fetch (cycles 5-6)
    mov r12b, byte [rel nmi_pending]
    test r12b, r12b
    jnz .nmi_hijack
    
.read_brk_vector:
    ; Read BRK/IRQ vector from $FFFE (low byte) and $FFFF (high byte)
    mov r11w, 0xFFFE              ; Address to read from
    call read_memory_byte         ; Cycle 5: Returns byte in al
    movzx r12, al                 ; r12 = low byte of BRK/IRQ vector
    
    mov r11w, 0xFFFF              ; Address to read from
    call read_memory_byte         ; Cycle 6: Returns byte in al
    movzx r13, al                 ; r13 = high byte of BRK/IRQ vector
    jmp .set_pc
    
.nmi_hijack:
    ; NMI asserted during vector fetch → read NMI vector instead of BRK/IRQ vector
    mov r11w, 0xFFFA              ; Address to read from
    call read_memory_byte         ; Cycle 5: Returns byte in al
    movzx r12, al                 ; r12 = low byte of NMI vector
    
    mov r11w, 0xFFFB              ; Address to read from
    call read_memory_byte         ; Cycle 6: Returns byte in al
    movzx r13, al                 ; r13 = high byte of NMI vector
    ; Clear NMI pending since we're servicing it through hijacking
    mov byte [rel nmi_pending], 0
    
.set_pc:
; Cycle 7: Set PC to vector address (begin executing BRK/IRQ/NMI handler)
    ; Combine vector bytes to form 16-bit address (little-endian)
    shl r13, 8
    or r13, r12
    mov word [rsi], r13w          ; PC now points to handler entry point
    
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 7                    ; Return 7 cycles
    ret

.nmi_hijack_brk:
    ; NMI pending at start of BRK → service NMI instead of BRK
    ; Handler calling convention already set up: rdi=memory, rsi=PC*, rdx=A*, rcx=P*, r8=X*, r9=Y*
    call nmi_handler
    mov eax, 7                    ; Still 7 cycles total
    pop r14
    pop r13
    pop r12
    pop rbx
    ret

; RTI - Return from Interrupt
; RTI ($40) - 6 cycles total
; Restores processor state from stack and returns from interrupt handler
; Convention: rdi=memory, rsi=PC*, rdx=A*, rcx=P*, r8=X*, r9=Y*
;
; Cycle-by-cycle breakdown:
;   Cycle 1: Fetch RTI opcode (already done in dispatcher)
;   Cycle 2: Increment SP, pull P from stack at $0100 + SP
;   Cycle 3: Increment SP, pull PCL from stack at $0100 + SP
;   Cycle 4: Increment SP, pull PCH from stack at $0100 + SP
;   Cycle 5: Internal operation (prepare to jump)
;   Cycle 6: Set PC to restored address
;
; Note: B flag (bit 4) is always cleared in pulled P (not a real flag)
;       Unused flag (bit 5) is always set in pulled P
;       SP is incremented by 3 total (one per pulled byte)
;       If pulled P has I flag clear, IRQ can trigger at next instruction boundary
;
; Total: 6 cycles.
global rti_instr
rti_instr:
    push rbx
    push r12
    push r13
    push r14
    
    ; Get SP pointer from global
    mov r14, [rel sp_pointer]
    
    ; Cycle 1: Fetch RTI opcode (handled by dispatcher)
    ; Cycle 2: Increment SP and pull P from stack at $0100 + SP
    movzx rax, byte [r14]
    inc al                        ; Increment SP (8-bit operation)
    and al, 0xFF                  ; Explicit wrap to ensure 0xFF -> 0x00
    mov [r14], al                 ; Store updated SP
    add rax, 0x100
    
    ; Read from stack using callback
    mov r11w, ax                  ; Address to read from ($0100 + SP)
    call read_memory_byte         ; Returns byte in al
    mov bl, al                    ; Save result in bl
    
    and bl, 0xEF                  ; Clear B flag (bit 4) - not a real flag
    or bl, 0x20                   ; Set unused flag (bit 5) - always set in P
    mov [rcx], bl                 ; Store restored P into live P register
    
; Cycle 3: Increment SP and pull PCL (low byte) from stack at $0100 + SP
    movzx rax, byte [r14]
    inc al                        ; Increment SP (8-bit operation)
    and al, 0xFF                  ; Explicit wrap to ensure 0xFF -> 0x00
    mov [r14], al                 ; Store updated SP
    add rax, 0x100
    
    ; Read from stack using callback
    mov r11w, ax                  ; Address to read from ($0100 + SP)
    call read_memory_byte         ; Returns byte in al
    movzx r12, al                 ; r12 = PCL
    
; Cycle 4: Increment SP and pull PCH (high byte) from stack at $0100 + SP
    movzx rax, byte [r14]
    inc al                        ; Increment SP (8-bit operation)
    and al, 0xFF                  ; Explicit wrap to ensure 0xFF -> 0x00
    mov [r14], al                 ; Store updated SP (final value: initial + 3)
    add rax, 0x100
    
    ; Read from stack using callback
    mov r11w, ax                  ; Address to read from ($0100 + SP)
    call read_memory_byte         ; Returns byte in al
    movzx r13, al                 ; r13 = PCH
    
; Cycle 5-6: Combine PCL and PCH, set PC to restored address
    ; Combine PC bytes to form 16-bit address (little-endian)
    shl r13, 8
    or r13, r12
    mov word [rsi], r13w          ; PC now points to instruction after interrupt
    
    pop r14
    pop r13
    pop r12
    pop rbx
    mov eax, 6                    ; Return 6 cycles
    ret

; KIL - Illegal opcode (Kill)
; The KIL opcode is an undocumented instruction that causes the CPU to
; enter a lock‑up state. In many emulators this is implemented as an
; infinite loop, effectively halting execution. We implement it as a
; simple self‑jump that never returns.
; KIL – Illegal opcode (unofficial, Implied) ; 0 cycles (halts CPU)
global KIL_IMP
KIL_IMP:
    ; The KIL instruction causes the CPU to enter a lock‑up state.
    ; We implement this as an infinite self‑jump. No registers are modified
    ; and the dispatcher will never regain control.
    dec word [rsi]            ; Decrement PC to original position
    mov eax, 0                ; Return 0 cycles
    ret                       ; FIXED: Added missing return statement!

; SLO (Indirect,X) is now implemented in unofficial.asm (all SLO variants)


section .note.GNU-stack noalloc noexec nowrite progbits
