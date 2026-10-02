#include "emulator_state.hpp"
#include "memory_system.hpp"
#include "controller.hpp"
#include "ppu.hpp"
#include "cpu_state.hpp"
#include <stdexcept>
#include <cstring>

namespace NES {

// Save-state format version — increment when EmulatorState structure changes
// Version 1: Initial implementation with expanded PPUState (Loopy registers, secondary OAM, etc.)
constexpr uint32_t SAVE_STATE_VERSION = 1;
constexpr uint32_t SAVE_STATE_MAGIC   = 0x4E455353;  // "NESS" magic number

// When building the test runner, define the global instances here
// (in the full emulator, they're defined in emulator.cpp)
#ifdef NES_TEST_RUNNER
CPUState gCPUState;
PPU gPPU;
#endif

std::vector<uint8_t> serializeState(const EmulatorState& state) {
    std::vector<uint8_t> data;
    // Reserve: magic (4) + version (4) + state size (4) + state data
    data.reserve(12 + sizeof(state));
    
    // Write magic number
    const uint8_t* magic_bytes = reinterpret_cast<const uint8_t*>(&SAVE_STATE_MAGIC);
    data.insert(data.end(), magic_bytes, magic_bytes + sizeof(SAVE_STATE_MAGIC));
    
    // Write version number
    const uint8_t* version_bytes = reinterpret_cast<const uint8_t*>(&SAVE_STATE_VERSION);
    data.insert(data.end(), version_bytes, version_bytes + sizeof(SAVE_STATE_VERSION));
    
    // Write state size for additional validation
    uint32_t state_size = static_cast<uint32_t>(sizeof(state));
    const uint8_t* size_bytes = reinterpret_cast<const uint8_t*>(&state_size);
    data.insert(data.end(), size_bytes, size_bytes + sizeof(state_size));
    
    // Write actual state data
    const uint8_t* raw = reinterpret_cast<const uint8_t*>(&state);
    data.insert(data.end(), raw, raw + sizeof(state));
    
    return data;
}

EmulatorState deserializeState(const std::vector<uint8_t>& data) {
    // Minimum size check: magic + version + size + at least some state data
    if (data.size() < 12) {
        throw std::runtime_error("Save-state file too small (corrupted or invalid format)");
    }
    
    // Validate magic number
    uint32_t magic;
    std::memcpy(&magic, data.data(), sizeof(magic));
    if (magic != SAVE_STATE_MAGIC) {
        throw std::runtime_error("Invalid save-state magic number (not a valid save file)");
    }
    
    // Validate version
    uint32_t version;
    std::memcpy(&version, data.data() + 4, sizeof(version));
    if (version != SAVE_STATE_VERSION) {
        throw std::runtime_error("Incompatible save-state version (save file is from a different emulator version)");
    }
    
    // Validate state size
    uint32_t stored_size;
    std::memcpy(&stored_size, data.data() + 8, sizeof(stored_size));
    if (stored_size != sizeof(EmulatorState)) {
        throw std::runtime_error("Save-state size mismatch (emulator structure has changed)");
    }
    
    // Validate total data size
    if (data.size() != 12 + sizeof(EmulatorState)) {
        throw std::runtime_error("Save-state file size mismatch");
    }
    
    // Deserialize state data
    EmulatorState state;
    std::memcpy(&state, data.data() + 12, sizeof(state));
    return state;
}

// Helper to capture the current emulator state — only available in the full
// emulator build (requires gCPUState and gPPU globals from emulator.cpp).
#ifndef NES_TEST_RUNNER
std::vector<uint8_t> captureState() {
    EmulatorState st{};
    // CPU state – assumed global variable gCPUState (defined elsewhere)
    extern CPUState gCPUState;
    st.cpu = gCPUState;
    // Memory – copy full RAM (addressable space) from the global bus
    extern MemoryBus gMemoryBus;
    std::memcpy(st.ram, gMemoryBus.getRawMemory(), NES::TOTAL_ADDRESSABLE);
    st.memory_cycle_counter = gMemoryBus.getCycleCounter();
    // Controllers snapshot – assuming a global controller system provides access
    extern ControllerSystem gControllerSystem;
    for (size_t i = 0; i < 4; ++i) {
        st.controllers[i].buttons = gControllerSystem.getButtonState(static_cast<u8>(i));
    }

    // PPU snapshot – assuming a global PPU instance
    extern PPU gPPU;
    st.ppu = gPPU.get_state();
    return serializeState(st);
}

// Helper to restore a previously captured state
void restoreState(const std::vector<uint8_t>& data) {
    EmulatorState st = deserializeState(data);
    extern CPUState gCPUState;
    gCPUState = st.cpu;
    extern MemoryBus gMemoryBus;
    // Write RAM back
    for (size_t i = 0; i < NES::TOTAL_ADDRESSABLE; ++i) {
        gMemoryBus.writeRAM(static_cast<u16>(i), st.ram[i]);
    }
    // Restore cycle counter
    gMemoryBus.resetCycleCounter();
    gMemoryBus.incrementCycleCounter(st.memory_cycle_counter);
    // Restore controllers
    extern ControllerSystem gControllerSystem;
    for (size_t i = 0; i < 4; ++i) {
        gControllerSystem.setButtonState(static_cast<u8>(i), st.controllers[i].buttons);
    }
    // Restore PPU state
    extern PPU gPPU;
    gPPU.get_state_mut() = st.ppu;
}
#endif // NES_TEST_RUNNER

} // namespace NES