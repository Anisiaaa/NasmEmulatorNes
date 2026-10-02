#include "cartridge.hpp"
#include <fstream>
#include <cstring>
#include <stdexcept>
#include <iostream>

namespace NES {

struct iNESHeader {
    u8 magic[4];        // "NES\x1A"
    u8 prg_rom_size;    // PRG-ROM size in 16KB units
    u8 chr_rom_size;    // CHR-ROM size in 8KB units
    u8 flags6;          // Mapper low nibble, mirroring, battery, trainer
    u8 flags7;          // Mapper high nibble, ROM format
    u8 flags8;          // PRG-RAM size (iNES 2.0)
    u8 flags9;          // CHR-RAM size (iNES 2.0)
    u8 flags10;         // TV system (iNES 2.0)
    u8 flags11;         // Mapper high nibble (iNES 2.0)
    u8 reserved[4];
    
    bool isValid() const { return magic[0] == 0x4E && magic[1] == 0x45 && magic[2] == 0x53; }
    bool isNES2() const { return (flags7 & 0x0C) == 0x08; }
    
    // Feature Checks
    bool hasTrainer() const { return (flags6 & 0x04) != 0; }
    bool hasBattery() const { return (flags6 & 0x02) != 0; }
    u8 getMirrorMode() const { return flags6 & 0x01; }
    
    u16 getMapperID() const {
        u8 mapper_low = (flags6 >> 4) & 0x0F;
        u8 mapper_high = (flags7 >> 4) & 0x0F;
        if (isNES2()) {
            u16 mapper_ext = (flags11 & 0x0F) << 8;
            return mapper_ext | (mapper_high << 4) | mapper_low;
        }
        return (mapper_high << 4) | mapper_low;
    }
    
    u32 getPRGROMSize() const {
        if (isNES2()) {
            u8 prg_msb = flags9 & 0x0F;
            if (prg_msb == 0x0F) {
                u8 exponent = (prg_rom_size >> 2) & 0x3F;
                u8 multiplier = prg_rom_size & 0x03;
                return (1 << exponent) * (multiplier * 2 + 1);
            }
            return ((prg_msb << 8) | prg_rom_size) * 0x4000;
        }
        return prg_rom_size * 0x4000;
    }
    
    u32 getCHRROMSize() const {
        if (isNES2()) {
            u8 chr_msb = (flags9 >> 4) & 0x0F;
            if (chr_msb == 0x0F) {
                u8 exponent = (chr_rom_size >> 2) & 0x3F;
                u8 multiplier = chr_rom_size & 0x03;
                return (1 << exponent) * (multiplier * 2 + 1);
            }
            return ((chr_msb << 8) | chr_rom_size) * 0x2000;
        }
        return chr_rom_size * 0x2000;
    }
};

// --- Base Mapper ---
Mapper::Mapper(u32 prg_size, u32 chr_size, u8 mirror_mode)
    : prg_rom_size(prg_size), chr_rom_size(chr_size), mirror_mode(mirror_mode),
      prg_ram(0x2000, 0x00), chr_ram(chr_size > 0 ? 0 : 0x2000, 0x00) {}
Mapper::~Mapper() = default;

u8 Mapper::readPRG(u16 address) {
    if (address < 0x6000) return 0xFF;
    if (address < 0x8000) return prg_ram[address - 0x6000];
    return prg_rom[(address - 0x8000) % prg_rom_size];
}
void Mapper::writePRG(u16 address, u8 value) {
    if (address >= 0x6000 && address < 0x8000) prg_ram[address - 0x6000] = value;
}
u8 Mapper::readCHR(u16 address) {
    address &= 0x1FFF;   // force wrap inside 8KB pattern table
    if (chr_rom_size > 0)
        return chr_rom[address % chr_rom_size];
    else
        return chr_ram[address];
}
void Mapper::writeCHR(u16 address, u8 value) {
    if (chr_rom_size == 0) chr_ram[address] = value;
}
u8 Mapper::getMirrorMode() const { return mirror_mode; }
void Mapper::processCycle() {}
void Mapper::setPRGROM(const std::vector<u8>& rom) { prg_rom = rom; }
void Mapper::setCHRROM(const std::vector<u8>& rom) { chr_rom = rom; }


// --- Mapper 0 (NROM) - For Super Mario Bros. (World) ---
class NROMMapper : public Mapper {
public:
    NROMMapper(u32 prg_size, u32 chr_size, u8 mirror_mode) : Mapper(prg_size, chr_size, mirror_mode) {}
    u8 readPRG(u16 address) override {
        if (address < 0x6000) return 0xFF;
        if (address < 0x8000) return prg_ram[address - 0x6000];
        u32 offset = (address - 0x8000);
        if (prg_rom_size == 0x4000) offset = offset % 0x4000;
        return prg_rom[offset % prg_rom_size];
    }
};


// --- Mapper 4 (MMC3) - For Super Mario Bros. 3 (USA) ---
class MMC3Mapper : public Mapper {
private:
    u8 bank_select;
    u8 bank_data[8];
    u8 mirroring;
    u8 sram_protect;
    
    // IRQ hardware state
    u8 irq_latch;
    u8 irq_counter;
    bool irq_enabled;
    bool irq_pending;
    bool reload_irq;
    
    // A12 Tracking for cycle-accurate screen splits
    u16 a12_low_cycles;
    bool a12_prev;

public:
    MMC3Mapper(u32 prg_size, u32 chr_size, u8 mirror_mode)
        : Mapper(prg_size, chr_size, mirror_mode), bank_select(0), mirroring(mirror_mode),
          sram_protect(0), irq_latch(0), irq_counter(0), irq_enabled(false), irq_pending(false),
          reload_irq(false), a12_low_cycles(0), a12_prev(false) 
    {
        std::fill(bank_data, bank_data + 8, 0);
    }
    
    u8 readPRG(u16 address) override {
        if (address < 0x6000) return 0xFF;
        if (address < 0x8000) return (sram_protect & 0x80) ? prg_ram[address - 0x6000] : 0xFF;
        
        u32 bank_num = 0;
        bool mode = (bank_select & 0x40) != 0;
        
        if (address < 0xA000) bank_num = mode ? 0x3E : (bank_data[6] & 0x3F);
        else if (address < 0xC000) bank_num = bank_data[7] & 0x3F;
        else if (address < 0xE000) bank_num = mode ? (bank_data[6] & 0x3F) : 0x3E;
        else bank_num = 0x3F;
        
        u32 offset = ((address - 0x8000) & 0x1FFF) + (bank_num << 13);
        return prg_rom[offset % prg_rom_size];
    }
    
    void writePRG(u16 address, u8 value) override {
    // PRG-RAM region ($6000-$7FFF)
    if (address >= 0x6000 && address < 0x8000) {
        // Only write if SRAM is enabled (bit7) and writes are NOT inhibited (bit6)
        if ((sram_protect & 0x80) && !(sram_protect & 0x40))
            prg_ram[address - 0x6000] = value;
        return;
    }
    // MMC3 registers
    if ((address & 0xE001) == 0x8000)       // $8000-$9FFE even
        bank_select = value;
    else if ((address & 0xE001) == 0x8001)  // $8001-$9FFF odd
        bank_data[bank_select & 0x07] = value;
    else if ((address & 0xE001) == 0xA000)  // $A000-$BFFE even
        mirror_mode = value & 0x01;
    else if ((address & 0xE001) == 0xA001)  // $A001-$BFFF odd
        sram_protect = value;
    else if ((address & 0xE001) == 0xC000)  // $C000-$DFFE even
        irq_latch = value;
    else if ((address & 0xE001) == 0xC001)  // $C001-$DFFF odd
        reload_irq = true;
    else if ((address & 0xE001) == 0xE000)  // $E000-$FFFE even
        { irq_enabled = false; irq_pending = false; }
    else if ((address & 0xE001) == 0xE001)  // $E001-$FFFF odd
        irq_enabled = true;
}
    
    u8 readCHR(u16 address) override {
        if (chr_rom_size == 0) return chr_ram[address];
        
        // --- A12 RISING EDGE HARDWARE TRACKER ---
        bool a12 = (address & 0x1000) != 0;
        if (a12 && !a12_prev && a12_low_cycles >= 3) {
            if (irq_counter == 0 || reload_irq) {
                irq_counter = irq_latch;
                reload_irq = false;
            } else {
                irq_counter--;
            }
            if (irq_counter == 0 && irq_enabled) {
                irq_pending = true;
            }
        }
        
        a12_prev = a12;
        if (a12) a12_low_cycles = 0;
        // ----------------------------------------
        
        u32 bank_num = 0;
        bool mode = (bank_select & 0x80) != 0;
        if (address < 0x0800) bank_num = mode ? bank_data[2] : (bank_data[0] & 0xFE);
        else if (address < 0x1000) bank_num = mode ? bank_data[3] : (bank_data[0] | 0x01);
        else if (address < 0x1800) bank_num = mode ? bank_data[4] : (bank_data[1] & 0xFE);
        else if (address < 0x2000) bank_num = mode ? bank_data[5] : (bank_data[1] | 0x01);
        
        u32 offset = (address & 0x07FF) + (bank_num << 10);
        return chr_rom[offset % chr_rom_size];
    }
    
    void processCycle() override { if (!a12_prev) a12_low_cycles++; }
    bool hasIRQPending() const override { return irq_pending; }
    void acknowledgeIRQ() override { irq_pending = false; }
};

// --- Cartridge Loading logic ---
Cartridge::Cartridge() : prg_rom_size(0), chr_rom_size(0), mapper_id(0), has_battery(false) {}
Cartridge::~Cartridge() = default;

bool Cartridge::loadFromFile(const std::string& filename) {
    std::ifstream file(filename, std::ios::binary);
    if (!file) return false;
    
    iNESHeader header;
    file.read(reinterpret_cast<char*>(&header), sizeof(iNESHeader));
    if (!header.isValid()) return false;
    
    mapper_id = header.getMapperID();
    prg_rom_size = header.getPRGROMSize();
    chr_rom_size = header.getCHRROMSize();
    has_battery = header.hasBattery();
    
    std::vector<u8> prg_data(prg_rom_size);
    if (header.hasTrainer()) file.seekg(512, std::ios::cur);
    file.read(reinterpret_cast<char*>(prg_data.data()), prg_rom_size);
    
    std::vector<u8> chr_data;
    if (chr_rom_size > 0) {
        chr_data.resize(chr_rom_size);
        file.read(reinterpret_cast<char*>(chr_data.data()), chr_rom_size);
    }
    
    createMapper(mapper_id, prg_rom_size, chr_rom_size, header.getMirrorMode());
    mapper->setPRGROM(prg_data);
    mapper->setCHRROM(chr_data);

    
    
    loadSaveData(filename);
    return true;
}

void Cartridge::createMapper(u8 id, u32 prg_size, u32 chr_size, u8 mirror_mode) {
    switch (id) {
        case 0: mapper = std::make_unique<NROMMapper>(prg_size, chr_size, mirror_mode); break;
        case 4: mapper = std::make_unique<MMC3Mapper>(prg_size, chr_size, mirror_mode); break;
        default: throw std::runtime_error("Mapper " + std::to_string(id) + " not supported. Only SMB1 (0) and SMB3 (4) are allowed.");
    }
}

u8 Cartridge::readPRG(u16 address) const { return mapper ? mapper->readPRG(address) : 0xFF; }
void Cartridge::writePRG(u16 address, u8 value) { if (mapper) mapper->writePRG(address, value); }
u8 Cartridge::readCHR(u16 address) const { return mapper ? mapper->readCHR(address) : 0xFF; }
void Cartridge::writeCHR(u16 address, u8 value) { if (mapper) mapper->writeCHR(address, value); }
u8 Cartridge::getMirrorMode() const { return mapper ? mapper->getMirrorMode() : 0; }
void Cartridge::processCycle() { if (mapper) mapper->processCycle(); }
u16 Cartridge::getMapperID() const { return mapper_id; }

void Cartridge::loadSaveData(const std::string& rom_filename) {
    // Basic Stub - implement normal save logic if needed
}
void Cartridge::saveSaveData(const std::string& rom_filename) {
    // Basic Stub - implement normal save logic if needed
}

} // namespace NES