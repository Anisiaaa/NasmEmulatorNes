#include "emulator.hpp"
#include "memory_system.hpp"
#include "cpu_state.hpp"
#include "ppu.hpp"
#include "apu.hpp"
#include "controller.hpp"
#include <iostream>

typedef uint8_t (*ReadMemoryCallback)(uint16_t address);
extern "C" int cpuExecuteInstruction(CPUState& cpu, ReadMemoryCallback callback, uint8_t* memory);
extern "C" uint8_t cpuReadMemoryCallback(uint16_t address);

extern bool gNestestMode;

extern "C" {
    extern uint8_t  irq_asserted;
    extern int32_t  irq_counter;
}

namespace NES {

u16 dbg_pc = 0;
bool dbg_mem_trace = false;
bool dbg_dump_lax = false;

#ifndef NES_TEST_RUNNER
CPUState gCPUState;
PPU      gPPU;
#endif

static bool cpuTraceEnabled() {
    return std::getenv("NES_CPU_TRACE") != nullptr;
}
static uint64_t g_instruction_count = 0;

Emulator::Emulator() : apu_(new APU_Interface(gMemoryBus)), pending_irq_(false) {}
Emulator::~Emulator() { delete apu_; }

void initializeEmulator() {
    gMemoryBus.reset();
    gPPU.initialize();
    gCPUState.reset();
    gControllerSystem.reset();
}

void Emulator::reset() {
    gMemoryBus.reset();
    gMemoryBus.setAPU(apu_);
    apu_->reset(true);
    gCPUState.reset();
    gControllerSystem.reset();

    Cartridge* cart = gMemoryBus.getCartridge();
    if (!cart) {
        gCPUState.PC = 0x8000;
        gPPU.reset();
        pending_irq_ = false;
        return;
    }

    uint16_t reset_vector = gMemoryBus.readMemory16(0xFFFC);
    bool valid_range = (reset_vector >= 0x8000 && reset_vector <= 0xFFEF);
    gCPUState.PC = valid_range ? reset_vector : 0x8000;

    std::cerr << "[RESET] reset_vector=0x" << std::hex << reset_vector
              << " PC=0x" << gCPUState.PC << std::dec << std::endl;

    std::cerr << "[RESET] PRG@$8000:";
    for (int i = 0; i < 32; i++) {
        std::cerr << " " << std::hex << (int)gMemoryBus.readMemory8(0x8000 + i);
    }
    std::cerr << std::dec << std::endl;

    if (gNestestMode) {
        gCPUState.PC = 0xC000;
    }

    apu_->tick(InstructionPhase::Read);
    apu_->tick(InstructionPhase::Read);
    gPPU.reset();
    pending_irq_ = false;
}

InstructionPhase Emulator::getInstructionPhase(uint8_t opcode) {
    switch (opcode) {
        case 0x06: case 0x0E: case 0x16: case 0x1E:
        case 0x26: case 0x2E: case 0x36: case 0x3E:
        case 0x46: case 0x4E: case 0x56: case 0x5E:
        case 0x66: case 0x6E: case 0x76: case 0x7E:
        case 0xE6: case 0xEE: case 0xF6: case 0xFE:
        case 0xC6: case 0xCE: case 0xD6: case 0xDE:
        case 0x03: case 0x07: case 0x0F: case 0x13: case 0x17: case 0x1B: case 0x1F:
        case 0x23: case 0x27: case 0x2F: case 0x33: case 0x37: case 0x3B: case 0x3F:
        case 0x43: case 0x47: case 0x4F: case 0x53: case 0x57: case 0x5B: case 0x5F:
        case 0x63: case 0x67: case 0x6F: case 0x73: case 0x77: case 0x7B: case 0x7F:
        case 0xC3: case 0xC7: case 0xCF: case 0xD3: case 0xD7: case 0xDB: case 0xDF:
        case 0xE3: case 0xE7: case 0xEF: case 0xF3: case 0xF7: case 0xFB: case 0xFF:
            return InstructionPhase::RMW;
        case 0x81: case 0x85: case 0x8D: case 0x91: case 0x95: case 0x99: case 0x9D:
        case 0x86: case 0x8E: case 0x96:
        case 0x84: case 0x8C: case 0x94:
        case 0x83: case 0x87: case 0x8F: case 0x97:
        case 0x9B: case 0x9C: case 0x9E: case 0x9F:
            return InstructionPhase::Write;
        default:
            return InstructionPhase::Read;
    }
}

int Emulator::step() {
    uint8_t opcode = gMemoryBus.readMemory8(gCPUState.PC);
    InstructionPhase phase = getInstructionPhase(opcode);

    dbg_pc = gCPUState.PC;

    // CPU instruction tracing
    if (cpuTraceEnabled()) {
        g_instruction_count++;
        if ((g_instruction_count & 0x0F) == 0) {  // Log every 16 instructions
            std::cerr << "[CPU] #" << g_instruction_count 
                      << " PC=0x" << std::hex << gCPUState.PC
                      << " opcode=0x" << (int)opcode
                      << " A=0x" << (int)gCPUState.A
                      << " X=0x" << (int)gCPUState.X
                      << " Y=0x" << (int)gCPUState.Y
                      << " SP=0x" << (int)gCPUState.SP
                      << " P=0x" << (int)gCPUState.P << std::dec << std::endl;
        }
    }

    if (dbg_dump_lax && gCPUState.PC == 0xE545) {
        std::cerr << "[LAX] Entering LAX($40,X) at PC=0xE545\n"
                  << "  mem[0x0043]=" << std::hex << (int)gMemoryBus.readMemory8(0x0043)
                  << " mem[0x0044]=" << std::hex << (int)gMemoryBus.readMemory8(0x0044)
                  << " mem[0x0580]=" << std::hex << (int)gMemoryBus.readMemory8(0x0580)
                  << " mem[0x0581]=" << std::hex << (int)gMemoryBus.readMemory8(0x0581)
                  << " A=" << (int)gCPUState.A << " X=" << (int)gCPUState.X
                  << " P=" << (int)gCPUState.P << std::dec << "\n";
    }

    int instr_cycles = cpuExecuteInstruction(gCPUState, cpuReadMemoryCallback,
                                             gMemoryBus.getRawMemory());

    int cycles_left = instr_cycles;

    // 1. Run all cycles of the instruction (DMA may extend this)
    while (cycles_left > 0) {
        if (gPPU.is_dma_pending() &&
            gPPU.get_dma_trigger_cycle() == gMemoryBus.getCycleCounter())
        {
            int dma_cycles = 513;
            if (cycles_left < dma_cycles) cycles_left = 0;
            else cycles_left -= dma_cycles;

            for (int d = 0; d < dma_cycles; ++d) {
                for (int p = 0; p < 3; ++p) gPPU.clock();
                apu_->tick(InstructionPhase::Read);
                gMemoryBus.incrementCycleCounter(1);
            }

            PPUState& ppu_state = gPPU.get_state_mut();
            uint16_t dma_addr = static_cast<uint16_t>(ppu_state.dma_page) << 8;
            for (int j = 0; j < 256; ++j) {
                ppu_state.oam[j] = gMemoryBus.readMemory8(dma_addr + j);
            }
            ppu_state.dma_pending = false;
            continue;
        }

        // Normal cycle
        gMemoryBus.incrementCycleCounter(1);

        uint8_t steal = apu_->tick(phase);
        if (steal > 0) {
            cycles_left += steal;
            for (uint8_t s = 0; s < steal; ++s) {
                apu_->tick(InstructionPhase::Read);
            }
        }

        for (int p = 0; p < 3; ++p) gPPU.clock();
        cycles_left--;
    }

    // 2. Instruction is complete – now check interrupts
    if (gPPU.should_trigger_nmi()) {
        serviceNMI();
        // Run 7 cycles for the interrupt sequence
        for (int i = 0; i < 7; ++i) {
            gMemoryBus.incrementCycleCounter(1);
            apu_->tick(InstructionPhase::Read);
            for (int p = 0; p < 3; ++p) gPPU.clock();
        }
    }

    if (irq_asserted && !gCPUState.getInterruptDisable()) {
        serviceIRQ();
        for (int i = 0; i < 7; ++i) {
            gMemoryBus.incrementCycleCounter(1);
            apu_->tick(InstructionPhase::Read);
            for (int p = 0; p < 3; ++p) gPPU.clock();
        }
    }

    return instr_cycles;
}

void Emulator::serviceNMI() {
    uint16_t nmi_lo = gMemoryBus.readMemory8(0xFFFA);
    uint16_t nmi_hi = gMemoryBus.readMemory8(0xFFFB);
    uint16_t nmi_addr = (nmi_hi << 8) | nmi_lo;

    uint16_t pc     = gCPUState.PC;
    uint8_t  status = gCPUState.P;

    gMemoryBus.writeMemory8(0x0100 + gCPUState.SP, static_cast<uint8_t>(pc >> 8));
    gCPUState.SP = (gCPUState.SP - 1) & 0xFF;
    gMemoryBus.writeMemory8(0x0100 + gCPUState.SP, static_cast<uint8_t>(pc & 0xFF));
    gCPUState.SP = (gCPUState.SP - 1) & 0xFF;
    gMemoryBus.writeMemory8(0x0100 + gCPUState.SP, (status & ~0x10u) | 0x20u);
    gCPUState.SP = (gCPUState.SP - 1) & 0xFF;

    gCPUState.P |= 0x04;
    gCPUState.PC = nmi_addr;

    gPPU.clear_nmi_flag();
}

void Emulator::serviceIRQ() {
    uint16_t irq_lo = gMemoryBus.readMemory8(0xFFFE);
    uint16_t irq_hi = gMemoryBus.readMemory8(0xFFFF);
    uint16_t irq_addr = (irq_hi << 8) | irq_lo;

    uint16_t pc     = gCPUState.PC;
    uint8_t  status = gCPUState.P;

    gMemoryBus.writeMemory8(0x0100 + gCPUState.SP, static_cast<uint8_t>(pc >> 8));
    gCPUState.SP = (gCPUState.SP - 1) & 0xFF;
    gMemoryBus.writeMemory8(0x0100 + gCPUState.SP, static_cast<uint8_t>(pc & 0xFF));
    gCPUState.SP = (gCPUState.SP - 1) & 0xFF;
    gMemoryBus.writeMemory8(0x0100 + gCPUState.SP, (status & ~0x10u) | 0x20u);
    gCPUState.SP = (gCPUState.SP - 1) & 0xFF;

    gCPUState.P |= 0x04;
    gCPUState.PC = irq_addr;

    if (irq_counter > 0) irq_counter--;
    irq_asserted = (irq_counter > 0) ? 1 : 0;
}

} // namespace NES