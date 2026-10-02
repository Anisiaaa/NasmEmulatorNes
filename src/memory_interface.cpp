#include "memory_system.hpp"
#include "cartridge.hpp"
#include "controller.hpp"
#include "ppu.hpp"
#include "apu.hpp"
#include <iostream>
#include <cstring>
#include <cassert>

namespace NES {

// Forward declaration of the global PPU instance (defined in emulator.cpp)
extern PPU gPPU;


MemoryBus gMemoryBus;


MemoryBus::MemoryBus() : memory_cycle_counter(0), apu_(nullptr), open_bus_(0), cartridge(nullptr) {
    reset();
}

void MemoryBus::reset() {
    // Initialize RAM and internal registers to zero, but preserve cartridge ROM mapping
    // Only clear $0000-$1FFF (RAM mirrors) and leave cartridge space intact
    std::memset(addressSpace, 0x00, 0x2000);  // Clear RAM area only
    memory_cycle_counter = 0;
    open_bus_ = 0;
    conflict_log.clear();
    // Note: cartridge pointer is NOT reset here - it persists across soft resets
    // Note: addressSpace[$8000-$FFFF] is NOT cleared - cartridge ROM persists
    // Note: apu_ is not reset here - it's managed externally
}

void MemoryBus::initPowerOnState() {
    // Power-on behavior: $4017 is written with $00 by hardware at cycle 0
    // This write must be visible via the memory bus for test ROMs to detect it
    // The write goes through normal APU write handler which applies jitter (3-4 cycles)
    
    if (apu_ == nullptr) {
        // APU not initialized yet - skip power-on write
        return;
    }
    
    // Write $00 to $4017 via memory bus (makes write visible to test ROMs)
    writeMemory8(0x4017, 0x00);
    
    // Cycle counter should remain at 0 - the memory bus write increments it,
    // but we need to decrement it back to 0 for proper power-on timing
    memory_cycle_counter = 0;
}


MemoryRegion MemoryBus::getMemoryRegion(u16 address) {
    if (address <= 0x1FFF) {
        return MemoryRegion::RAM;
    } else if (address >= PPU_REGISTER_BASE && address <= PPU_MIRROR_END) {
        return MemoryRegion::PPU_REGISTERS;
    } else if (address >= APU_IO_START && address <= 0x4015) {
        return MemoryRegion::APU_IO;
    } else if (address == 0x4016 || address == 0x4017) {
        return MemoryRegion::CONTROLLER_IO;
    } else if (address >= APU_TEST_START && address <= APU_TEST_END) {
        return MemoryRegion::APU_TEST;
    } else if (address >= CARTRIDGE_START && address <= CARTRIDGE_END) {
        return MemoryRegion::CARTRIDGE;
    }
    return MemoryRegion::INVALID;
}


u16 MemoryBus::getMirroredAddress(u16 address) {
    // RAM mirroring: $0000-$07FF is repeated 4 times through $0000-$1FFF
    if (address <= 0x1FFF) {
        // Mirror address to the original $0000-$07FF region
        return address & 0x07FF;
    }
    
    // PPU register mirroring: $2000-$2007 is repeated through $2008-$3FFF
    if (address >= PPU_REGISTER_BASE && address <= PPU_MIRROR_END) {
        // Map to the base PPU register ($2000-$2007)
        u16 offset = address - PPU_REGISTER_BASE;
        return PPU_REGISTER_BASE + (offset % PPU_REGISTER_SIZE);
    }
    
    // No mirroring for other regions
    return address;
}


u8 MemoryBus::readMemory8(u16 address) {
#ifndef NDEBUG
    // Debug build: verify address is within bounds
    if (address >= TOTAL_ADDRESSABLE) {
        std::cerr << "ERROR: Out of bounds read at address 0x" 
                  << std::hex << address << std::dec << std::endl;
        assert(address < TOTAL_ADDRESSABLE && "Memory read out of bounds");
        // Update open bus even for error case before potential assert
        open_bus_ = 0x00;
        return 0x00;
    }
#endif

    MemoryRegion region = getMemoryRegion(address);
    u8 result = 0x00;
    
    switch (region) {
        case MemoryRegion::RAM: {
            // RAM with mirroring
            u16 mirroredAddr = getMirroredAddress(address);
            result = addressSpace[mirroredAddr];
            break;
        }
        
        case MemoryRegion::PPU_REGISTERS: {
            result = readPPURegister(address);
            break;
        }
        
        case MemoryRegion::APU_IO: {
            result = readAPURegister(address);
            break;
        }
        
        case MemoryRegion::CONTROLLER_IO: {
            // Controller I/O registers ($4016-$4017)
            result = readControllerIO(address);
            break;
        }
        
        case MemoryRegion::APU_TEST: {
            result = 0x00;
            break;
        }
        
        case MemoryRegion::CARTRIDGE: {
            // Use cartridge pointer for reads to support mapper bank switching.
            if (cartridge) {
                result = cartridge->readPRG(address);
            } else {
                // Fallback: read from addressSpace (may contain stale data if cartridge detached)
                result = addressSpace[address];
            }
            break;
        }
        
        case MemoryRegion::INVALID:
        default:
            result = 0x00;
            break;
    }
    
    // Track open bus value - ensures APU open-bus reads return the last byte on data bus
    open_bus_ = result;
    return result;
}

void MemoryBus::writeMemory8(u16 address, u8 value) {
#ifndef NDEBUG
    // Debug build: verify address is within bounds
    if (address >= TOTAL_ADDRESSABLE) {
        std::cerr << "ERROR: Out of bounds write at address 0x" 
                  << std::hex << address << std::dec << " with value 0x" 
                  << std::hex << static_cast<int>(value) << std::dec << std::endl;
        assert(address < TOTAL_ADDRESSABLE && "Memory write out of bounds");
        // Update open bus even for error case before potential assert
        open_bus_ = value;
        return;
    }
#endif

    MemoryRegion region = getMemoryRegion(address);
    
    // Update open bus - written values appear on the data bus
    open_bus_ = value;
    
    switch (region) {
        case MemoryRegion::RAM: {
            // RAM with mirroring - write to all mirrors
            u16 mirroredAddr = getMirroredAddress(address);
            // Write to base address and all mirror regions
            addressSpace[mirroredAddr + 0x0000] = value;
            addressSpace[mirroredAddr + 0x0800] = value;
            addressSpace[mirroredAddr + 0x1000] = value;
            addressSpace[mirroredAddr + 0x1800] = value;
            break;
        }
        
        case MemoryRegion::PPU_REGISTERS: {
            writePPURegister(address, value);
            break;
        }
        
        case MemoryRegion::APU_IO: {
            // OAM DMA register ($4014): trigger a DMA transfer
            if (address == 0x4014) {
                gPPU.trigger_dma(value);
                break;
            }
            writeAPURegister(address, value);
            break;
        }
        
        case MemoryRegion::CONTROLLER_IO: {
            // Controller I/O registers ($4016-$4017)
            writeControllerIO(address, value);
            break;
        }
        
        case MemoryRegion::APU_TEST: {
            break;
        }
        
        case MemoryRegion::CARTRIDGE: {
            if (cartridge) {
                cartridge->writePRG(address, value);
            } else {
                addressSpace[address] = value;
            }
            break;
        }
        
        case MemoryRegion::INVALID:
        default:
            break;
    }
}

// 16-bit Memory Operations (Little-Endian)

u16 MemoryBus::readMemory16(u16 address) {
    u8 lo = readMemory8(address);
    u8 hi = readMemory8(address + 1);
    return (static_cast<u16>(hi) << 8) | lo;
}

void MemoryBus::writeMemory16(u16 address, u16 value) {
    u8 lo = static_cast<u8>(value & 0xFF);
    u8 hi = static_cast<u8>((value >> 8) & 0xFF);
    writeMemory8(address, lo);
    writeMemory8(address + 1, hi);
}

// Direct RAM Access (Bypasses Mirroring and Registers)

u8 MemoryBus::readRAM(u16 address) {
    if (address < TOTAL_ADDRESSABLE) {
        return addressSpace[address];
    }
    return 0x00;
}

void MemoryBus::writeRAM(u16 address, u8 value) {
    if (address < TOTAL_ADDRESSABLE) {
        addressSpace[address] = value;
    }
}

// PPU Register Access

u8 MemoryBus::readPPURegister(u16 address) {
    // Get the base PPU register address (0x2000-0x2007)
    u16 baseAddr = getMirroredAddress(address);
    u8 regIndex = baseAddr - PPU_REGISTER_BASE;

    if (regIndex >= PPU_REGISTER_SIZE) {
        return 0x00;
    }

    return gPPU.read_register(regIndex);
}

void MemoryBus::writePPURegister(u16 address, u8 value) {
    // Get the base PPU register address (0x2000-0x2007)
    u16 baseAddr = getMirroredAddress(address);
    u8 regIndex = baseAddr - PPU_REGISTER_BASE;

    if (regIndex >= PPU_REGISTER_SIZE) {
        return;
    }

    gPPU.write_register(regIndex, value);
}

// APU Register Access

u8 MemoryBus::readAPURegister(u16 address) {
    // APU registers are at $4000-$4017
    if (address >= APU_IO_START && address <= APU_IO_END) {
        if (apu_ != nullptr) {
            u8 result = apu_->read(address);
            open_bus_ = result;
            return result;
        }
        return open_bus_;
    }
    // Out of range - update open bus with 0x00 before returning
    open_bus_ = 0x00;
    return 0x00;
}

void MemoryBus::writeAPURegister(u16 address, u8 value) {
    // Set open bus value before any dispatch
    open_bus_ = value;
    
    // Dispatch to APU interface if available
    if (apu_ != nullptr) {
        apu_->write(address, value);
    }
}

// Bus Conflict Detection and Logging

void MemoryBus::recordBusConflict(u16 address, u8 cpu_value, u8 cartridge_value, u8 result_value) {
    BusConflict conflict(memory_cycle_counter, address, cpu_value, cartridge_value, result_value);
    conflict_log.push_back(conflict);
}

// Cartridge Attachment with ROM Mapping

void MemoryBus::setCartridge(Cartridge* cart) {
    cartridge = cart;
    
    if (cartridge) {
        // Copy cartridge PRG-ROM into address space for direct CPU access
        // NES cartridges appear at $8000-$FFFF (32KB)
        // For 16KB ROMs (NROM-128), mirror at $8000 and $C000
        // For 32KB ROMs (NROM-256), map directly
        
        // Determine PRG-ROM size from cartridge
        // Let the cartridge handle mirroring while populating the flat view.
        for (uint32_t addr = 0x8000; addr <= 0xFFFF; addr++) {
            addressSpace[addr] = cartridge->readPRG(static_cast<u16>(addr));
        }
        
        std::cout << "Cartridge PRG-ROM copied to address space ($8000-$FFFF)" << std::endl;
        
    }
}

} // namespace NES
