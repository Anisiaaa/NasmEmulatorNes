#pragma once

#include "cpu_state.hpp"
#include "memory_system.hpp"
#include "controller.hpp"
#include "ppu.hpp"

namespace NES {

// State required to serialize and resume emulator execution.

struct EmulatorState {
    CPUState cpu;                     // CPU registers and cycle count
    uint8_t ram[TOTAL_ADDRESSABLE]; // Full 64 KB address space (only RAM is needed for TAS)
    uint64_t memory_cycle_counter;   // Cycle counter from MemoryBus
    ControllerState controllers[4];  // Snapshot of each controller
    PPUState ppu;                    // Complete PPU registers, VRAM, OAM, palette, framebuffer, etc.
    // Saved so TAS playback can resume at the correct frame.
    uint64_t tas_frame_counter = 0;
};

/** Serialize the given state into a byte vector (binary format). */
std::vector<uint8_t> serializeState(const EmulatorState& state);

/** Deserialize a byte vector back into an EmulatorState. Throws on size mismatch. */
EmulatorState deserializeState(const std::vector<uint8_t>& data);

/** Capture the current emulator state into a binary blob. */
std::vector<uint8_t> captureState();

/** Restore the emulator from a previously captured binary blob. */
void restoreState(const std::vector<uint8_t>& data);

} // namespace NES