#pragma once

#include "types.hpp"
#include "cpu_state.hpp"
#include <vector>
#include <cstring>

namespace NES {

class Cartridge;
class APU_Interface;

// Memory System Constants

// Memory region sizes
constexpr u16 RAM_SIZE = 0x0800;              // 2KB internal RAM
constexpr u32 TOTAL_ADDRESSABLE = 0x10000;    // 64KB total addressable space

// Memory region boundaries
constexpr u16 RAM_MIRROR_0 = 0x0000;          // Original RAM
constexpr u16 RAM_MIRROR_1 = 0x0800;          // Mirror 1
constexpr u16 RAM_MIRROR_2 = 0x1000;          // Mirror 2
constexpr u16 RAM_MIRROR_3 = 0x1800;          // Mirror 3

// Register regions
constexpr u16 PPU_REGISTER_BASE = 0x2000;
constexpr u16 PPU_REGISTER_SIZE = 0x0008;     // 8 registers
constexpr u16 PPU_MIRROR_START = 0x2008;
constexpr u16 PPU_MIRROR_END = 0x3FFF;

constexpr u16 APU_IO_START = 0x4000;
constexpr u16 APU_IO_END = 0x4017;
constexpr u16 APU_TEST_START = 0x4018;
constexpr u16 APU_TEST_END = 0x401F;

// Note: CARTRIDGE_START and CARTRIDGE_END are defined in types.hpp

// Bus Conflict Tracking

struct BusConflict {
    u64 cycle;           // Cycle when conflict occurred
    u16 address;         // Address involved
    u8 cpu_value;        // Value written by CPU
    u8 cartridge_value;  // Value from cartridge
    u8 result_value;     // Resulting value (AND of both)
    
    BusConflict() : cycle(0), address(0), cpu_value(0), cartridge_value(0), result_value(0) {}
    BusConflict(u64 c, u16 addr, u8 cpu_val, u8 cart_val, u8 res)
        : cycle(c), address(addr), cpu_value(cpu_val), cartridge_value(cart_val), result_value(res) {}
};

// Memory Region Enum

enum class MemoryRegion : u8 {
    RAM,           // $0000-$1FFF (with mirrors)
    PPU_REGISTERS, // $2000-$3FFF (with mirrors)
    APU_IO,        // $4000-$4015
    CONTROLLER_IO, // $4016-$4017
    APU_TEST,      // $4018-$401F
    CARTRIDGE,     // $4020-$FFFF
    INVALID        // Unknown region
};

// Memory Bus Class

class MemoryBus {
private:
    // Full 64KB address space (bus)
    // Note: Only $0000-$07FF is actual internal RAM, rest is registers/cartridge space
    u8 addressSpace[TOTAL_ADDRESSABLE];
    std::vector<BusConflict> conflict_log;  // Bus conflict history
    u64 memory_cycle_counter;               // Cycle counter for memory operations
    APU_Interface* apu_;                    // APU interface pointer (nullptr until initialized)
    u8 open_bus_;                           // Last byte on data bus (open-bus tracking)
    Cartridge* cartridge;                   // Attached cartridge (optional)

public:
    // Constructor and initialization
    MemoryBus();
    ~MemoryBus() = default;
    
    // Initialize memory to zero
    void reset();
    
    // Power-on initialization sequence
    void initPowerOnState();
    
    // Core 8-bit memory operations
    u8 readMemory8(u16 address);
    void writeMemory8(u16 address, u8 value);
    
    // 16-bit memory operations (little-endian)
    u16 readMemory16(u16 address);
    void writeMemory16(u16 address, u16 value);
    
    // PPU register access
    u8 readPPURegister(u16 address);
    void writePPURegister(u16 address, u8 value);
    
    // APU register access
    u8 readAPURegister(u16 address);
    void writeAPURegister(u16 address, u8 value);
    
    // Direct RAM access (bypasses mirroring and registers)
    u8 readRAM(u16 address);
    void writeRAM(u16 address, u8 value);

    // Raw pointer to the full 64KB flat address space (for CPU execution)
    u8* getRawMemory() { return addressSpace; }

    // Cartridge attachment
    void setCartridge(Cartridge* cart);
    Cartridge* getCartridge() const { return cartridge; }
    
    // APU attachment
    void setAPU(APU_Interface* apu) { apu_ = apu; }
    APU_Interface* getAPU() const { return apu_; }
    
    // Helper functions
    u16 getMirroredAddress(u16 address);
    MemoryRegion getMemoryRegion(u16 address);
    
    // Bus conflict detection
    void recordBusConflict(u16 address, u8 cpu_value, u8 cartridge_value, u8 result_value);
    const std::vector<BusConflict>& getBusConflicts() const { return conflict_log; }
    void clearBusConflicts() { conflict_log.clear(); }
    
    // Cycle tracking
    u64 getCycleCounter() const { return memory_cycle_counter; }
    void incrementCycleCounter(u64 cycles = 1) { memory_cycle_counter += cycles; }
    void resetCycleCounter() { memory_cycle_counter = 0; }
};

// Controller System Forward Declaration

// Forward declaration of ControllerSystem
class ControllerSystem;

// Controller I/O Register Access (for integration)

// Controller I/O functions
u8 readControllerIO(u16 address);
void writeControllerIO(u16 address, u8 value);
ControllerSystem& getControllerSystem();

// --- DEBUG hooks (for nestest memory-write tracing) ---
extern u16  dbg_pc;
extern bool dbg_mem_trace;
extern bool dbg_dump_lax;


extern MemoryBus gMemoryBus;

} // namespace NES

extern "C" {
    // Bus conflict simulation
    u8 asm_simulateBusConflict(u8 cpu_value, u8 cartridge_value);
}