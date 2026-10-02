#pragma once
#include "memory_system.hpp"
#include "cpu_state.hpp"
#include "ppu.hpp"
#include "apu.hpp"

namespace NES {

extern PPU gPPU;

class Emulator {
public:
    Emulator();
    ~Emulator();

    void reset();
    int  step();
    bool isFrameReady() const { return gPPU.is_frame_ready(); }

private:
    static InstructionPhase getInstructionPhase(uint8_t opcode);
    void serviceNMI();
    void serviceIRQ();

    APU_Interface* apu_;
    bool pending_irq_;
};

void initializeEmulator();

} // namespace NES