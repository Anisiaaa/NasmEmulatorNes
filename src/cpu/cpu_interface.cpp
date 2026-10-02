#include "types.hpp"
#include "cpu_state.hpp"
#include "memory_system.hpp"
#include <cstdio>
#include <cstdlib>
#include <cassert>

// Callback type for memory reads
typedef uint8_t (*ReadMemoryCallback)(uint16_t address);

// External assembly functions and global variables
extern "C" {
    int execute6502Instruction(ReadMemoryCallback read_memory_callback, uint8_t* memory, uint16_t* PC, uint8_t* A,
                                uint8_t* X, uint8_t* Y, uint8_t* P, uint8_t* SP);
    uint64_t getCycleCount();
    void resetCycleCount();
    void advanceCycles(int64_t cycles);
    const char* getCPUVersion();
    void setSPPointer(uint8_t* sp);
    
    // Global interrupt state variables from cpu.asm
    extern uint8_t nmi_pending;
    extern uint8_t nmi_previous;
    extern uint8_t irq_asserted;
    extern int32_t irq_counter;
}

// Callback wrapper for production code - routes through MemoryBus::readMemory8()
extern "C" uint8_t cpuReadMemoryCallback(uint16_t address) {
    uint8_t v = NES::gMemoryBus.readMemory8(address);
    // EVERY memory access from the 6502 core, so it must NOT emit stderr
    // unconditionally — that floods stdout/stderr and starves the emulator.
    // Only print when an explicit trace switch is requested.
    static const bool cpu_trace = std::getenv("NES_CPU_TRACE") != nullptr;
    if (cpu_trace) {
        if (address == 0x4016 || address == 0x4017) {
            std::fprintf(stderr, "[CTRL-R] read(0x%04X)=0x%02X\n",
                         address, v);
        }
        if (address == 0x0580 || address == 0xE545) {
            std::fprintf(stderr, "[CB] read(0x%04X)=0x%02X  zp43=%02X zp44=%02X\n",
                         address, v,
                         NES::gMemoryBus.readMemory8(0x0043),
                         NES::gMemoryBus.readMemory8(0x0044));
        }
    }
    return v;
}

// Test-specific callback for isolated unit tests
static uint8_t* test_memory_ptr = nullptr;
extern "C" uint8_t testMemoryCallback(uint16_t address) {
    return test_memory_ptr[address];
}

// Execute a single instruction and return cycles (C linkage for cross-TU calls)
extern "C" int cpuExecuteInstruction(CPUState& cpu, ReadMemoryCallback callback, uint8_t* memory) {
    setSPPointer(&cpu.SP);
    resetCycleCount();
    int cycles = execute6502Instruction(
        callback,
        memory,
        &cpu.PC,
        &cpu.A,
        &cpu.X,
        &cpu.Y,
        &cpu.P,
        &cpu.SP
    );
    cpu.cycles += cycles;
    return cycles;
}


// Trigger NMI with rising edge detection (0→1 transition)
void triggerNMI() {
    // Rising edge detection: only set pending if previous was 0 and pending is not already set
    if (nmi_previous == 0 && nmi_pending == 0) {
        nmi_pending = 1;
    }
    nmi_previous = 1;  // Update previous state to current (high)
}

// Clear NMI signal (resets edge detection state)
void clearNMI() {
    nmi_previous = 0;  // Reset to low state for edge detection
    // Note: nmi_pending is cleared by assembly when NMI is serviced
}

// Query if NMI is pending
bool isNMIPending() {
    return nmi_pending != 0;
}


// Assert IRQ line (increment reference counter)
void assertIRQ() {
    irq_counter++;
    irq_asserted = (irq_counter > 0) ? 1 : 0;
}

// Clear IRQ line (decrement reference counter with underflow protection)
void clearIRQ() {
    if (irq_counter > 0) {
        irq_counter--;
    }
    // Counter never goes negative (underflow protection)
    irq_asserted = (irq_counter > 0) ? 1 : 0;
}

// Query if IRQ is asserted
bool isIRQAsserted() {
    return irq_asserted != 0;
}

void testLDA_Immediate() {
    printf("Testing LDA Immediate...\n");

    uint8_t memory[0x10000] = {0};
    memory[0] = 0xA9;  // LDA #$42
    memory[1] = 0x42;

    CPUState cpu;
    cpu.reset();
    cpu.PC = 0;

    test_memory_ptr = memory;
    int cycles = cpuExecuteInstruction(cpu, testMemoryCallback, memory);

    printf("  A=0x%02X (expected 0x42)\n", cpu.A);
    printf("  PC=0x%04X (expected 0x0002)\n", cpu.PC);
    printf("  cycles=%d (expected 2)\n", cycles);

    assert(cpu.A == 0x42);
    assert(cpu.PC == 2);
    // USING GETTERS INSTEAD OF CPU_FLAGS
    assert(!cpu.getZero());
    assert(!cpu.getNegative());
    assert(cycles == 2);

    printf("  PASSED!\n");
}

void testLDA_Immediate_Zero() {
    printf("Testing LDA Immediate (zero)...\n");

    uint8_t memory[0x10000] = {0};
    memory[0] = 0xA9;  // LDA #$00
    memory[1] = 0x00;

    CPUState cpu;
    cpu.reset();
    cpu.PC = 0;

    test_memory_ptr = memory;
    cpuExecuteInstruction(cpu, testMemoryCallback, memory);

    printf("  A=0x%02X (expected 0x00)\n", cpu.A);
    // USING GETTERS INSTEAD OF CPU_FLAGS
    printf("  Z flag=%d (expected 1)\n", cpu.getZero() ? 1 : 0);

    assert(cpu.A == 0x00);
    assert(cpu.getZero());
    assert(!cpu.getNegative());

    printf("  PASSED!\n");
}

void testLDA_Immediate_Negative() {
    printf("Testing LDA Immediate (negative)...\n");

    uint8_t memory[0x10000] = {0};
    memory[0] = 0xA9;  // LDA #$FF
    memory[1] = 0xFF;

    CPUState cpu;
    cpu.reset();
    cpu.PC = 0;

    test_memory_ptr = memory;
    cpuExecuteInstruction(cpu, testMemoryCallback, memory);

    printf("  A=0x%02X (expected 0xFF)\n", cpu.A);
    // USING GETTERS INSTEAD OF CPU_FLAGS
    printf("  N flag=%d (expected 1)\n", cpu.getNegative() ? 1 : 0);

    assert(cpu.A == 0xFF);
    assert(!cpu.getZero());
    assert(cpu.getNegative());

    printf("  PASSED!\n");
}
// Test STA zeropage
void testSTA_Zeropage() {
    printf("Testing STA Zeropage...\n");

    uint8_t memory[0x10000] = {0};
    memory[0] = 0x85;  // STA $42
    memory[1] = 0x42;

    CPUState cpu;
    cpu.reset();
    cpu.A = 0xAB;
    cpu.PC = 0;

    test_memory_ptr = memory;
    cpuExecuteInstruction(cpu, testMemoryCallback, memory);

    printf("  memory[0x42]=0x%02X (expected 0xAB)\n", memory[0x42]);
    printf("  PC=0x%04X (expected 0x0002)\n", cpu.PC);

    assert(memory[0x42] == 0xAB);
    assert(cpu.PC == 2);

    printf("  PASSED!\n");
}

// Test ADC immediate
void testADC_Immediate() {
    printf("Testing ADC Immediate...\n");

    uint8_t memory[0x10000] = {0};
    memory[0] = 0x69;  // ADC #$10
    memory[1] = 0x10;

    CPUState cpu;
    cpu.reset();
    cpu.A = 0x20;
    cpu.PC = 0;
    cpu.setCarry(false);

    test_memory_ptr = memory;
    cpuExecuteInstruction(cpu, testMemoryCallback, memory);

    printf("  A=0x%02X (expected 0x30)\n", cpu.A);
    printf("  C flag=%d (expected 0)\n", cpu.getCarry() ? 1 : 0);

    assert(cpu.A == 0x30);
    assert(!cpu.getCarry());
    assert(!cpu.getZero());
    assert(!cpu.getNegative());

    printf("  PASSED!\n");
}

// Test ADC with carry
void testADC_WithCarry() {
    printf("Testing ADC with carry...\n");

    uint8_t memory[0x10000] = {0};
    memory[0] = 0x69;  // ADC #$01
    memory[1] = 0x01;

    CPUState cpu;
    cpu.reset();
    cpu.A = 0xFF;
    cpu.PC = 0;
    cpu.setCarry(false);

    test_memory_ptr = memory;
    cpuExecuteInstruction(cpu, testMemoryCallback, memory);

    printf("  A=0x%02X (expected 0x00)\n", cpu.A);
    printf("  C flag=%d (expected 1)\n", cpu.getCarry() ? 1 : 0);
    printf("  Z flag=%d (expected 1)\n", cpu.getZero() ? 1 : 0);

    assert(cpu.A == 0x00);
    assert(cpu.getCarry());
    assert(cpu.getZero());

    printf("  PASSED!\n");
}

// Test branch instructions
void testBEQ_Taken() {
    printf("Testing BEQ (taken)...\n");

    uint8_t memory[0x10000] = {0};
    memory[0x10] = 0xF0;  // BEQ +$20
    memory[0x11] = 0x20;

    CPUState cpu;
    cpu.reset();
    cpu.PC = 0x10;
    cpu.setZero(true);

    test_memory_ptr = memory;
    cpuExecuteInstruction(cpu, testMemoryCallback, memory);

    printf("  PC=0x%04X (expected 0x0032)\n", cpu.PC);

    assert(cpu.PC == 0x32);  // 0x10 + 2 + 0x20 = 0x32

    printf("  PASSED!\n");
}

// Test all CPU opcodes
void testAllCPUCore() {
    printf("\n=== CPU Core Tests ===\n\n");

    testLDA_Immediate();
    testLDA_Immediate_Zero();
    testLDA_Immediate_Negative();
    testSTA_Zeropage();
    testADC_Immediate();
    testADC_WithCarry();
    testBEQ_Taken();

    printf("\n=== All CPU Core Tests PASSED! ===\n");
}


extern "C" const char* getCPUVersion() {
    return "NES ASM Core v1.0";
}

uint64_t internal_cycle_count = 0;
extern "C" void resetCycleCount() {
    internal_cycle_count = 0;
}

// 1. The actual C++ function (renamed so it doesn't clash)
extern "C" void cpp_write_memory_byte(uint16_t address, uint8_t value) {
    NES::gMemoryBus.writeMemory8(address, value);
}

// 2. The raw assembly bridge that translates the registers
__asm__(
    ".global write_memory_byte\n"
    "write_memory_byte:\n"
    "    push %rdi\n"         // Save standard caller-saved registers
    "    push %rsi\n"
    "    push %rdx\n"
    "    push %rcx\n"
    "    push %r8\n"
    "    push %r9\n"
    "    push %r10\n"
    "    push %r11\n"
    
    "    mov %r11, %rdi\n"    // Translate Custom Assembly Arg 1 (r11) -> C++ Arg 1 (rdi)
    "    mov %r12, %rsi\n"    // Translate Custom Assembly Arg 2 (r12) -> C++ Arg 2 (rsi)
    
    "    push %rbp\n"         // Re-align the stack to 16-bytes (Linux C++ requirement)
    "    mov %rsp, %rbp\n"
    "    and $-16, %rsp\n"
    
    "    call cpp_write_memory_byte\n" // Safely call C++
    
    "    mov %rbp, %rsp\n"    // Restore stack alignment
    "    pop %rbp\n"
    
    "    pop %r11\n"          // Restore all registers back to assembly core
    "    pop %r10\n"
    "    pop %r9\n"
    "    pop %r8\n"
    "    pop %rcx\n"
    "    pop %rdx\n"
    "    pop %rsi\n"
    "    pop %rdi\n"
    "    ret\n"
);
