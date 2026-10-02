#pragma once
#include "types.hpp"
#include <memory>
#include <string>
#include <vector>

namespace NES {

using ::u8;
using ::u16;
using ::u32;
using ::u64;

class Mapper {
public:
    Mapper(u32 prg_size, u32 chr_size, u8 mirror_mode);
    virtual ~Mapper();

    virtual u8 readPRG(u16 address);
    virtual void writePRG(u16 address, u8 value);
    virtual u8 readCHR(u16 address);
    virtual void writeCHR(u16 address, u8 value);
    virtual u8 getMirrorMode() const;
    virtual void processCycle();

    // IRQ interface methods
    virtual bool hasIRQPending() const { return false; }
    virtual void acknowledgeIRQ() {}

    void setPRGROM(const std::vector<u8>& rom);
    void setCHRROM(const std::vector<u8>& rom);

protected:
    u32 prg_rom_size;
    u32 chr_rom_size;
    u8 mirror_mode;
    std::vector<u8> prg_rom;
    std::vector<u8> chr_rom;
    std::vector<u8> prg_ram;
    std::vector<u8> chr_ram;
};

class Cartridge {
public:
    Cartridge();
    ~Cartridge();

    bool loadFromFile(const std::string& filename);

    u8 readPRG(u16 address) const;
    void writePRG(u16 address, u8 value);
    u8 readCHR(u16 address) const;
    void writeCHR(u16 address, u8 value);

    u8 getMirrorMode() const;
    void processCycle();

    u16 getMapperID() const;  // Returns u16 to support iNES 2.0 extended mapper IDs
    u32 getPRGROMSize() const { return prg_rom_size; }
    u32 getCHRROMSize() const { return chr_rom_size; }

    void saveSaveData(const std::string& rom_filename);

    // IRQ passthrough methods
    bool hasIRQPending() const {
        return mapper && mapper->hasIRQPending();
    }

    void acknowledgeIRQ() {
        if (mapper) mapper->acknowledgeIRQ();
    }

private:
    void createMapper(u8 id, u32 prg_size, u32 chr_size, u8 mirror_mode);
    void loadSaveData(const std::string& rom_filename);

    std::unique_ptr<Mapper> mapper;
    u32 prg_rom_size;
    u32 chr_rom_size;
    u16 mapper_id;  // Changed to u16 to support iNES 2.0 extended mapper IDs (0-4095)
    bool has_battery;
};

} // namespace NES