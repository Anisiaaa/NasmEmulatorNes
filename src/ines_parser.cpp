#include <string>
#include <sstream>
#include <iomanip>
#include "types.hpp"

namespace NES {

// iNESHeader structure definition
// This matches the structure defined in cartridge.cpp
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
    u8 reserved[4];     // Reserved
};

namespace iNES {

// Returns the common name for a mapper based on its ID.
// @param mapper_id The mapper number (0-255+ for iNES 1.0/2.0)
// @return A string containing the mapper name, or "Unknown" if not recognized

std::string getMapperName(u16 mapper_id) {
    switch (mapper_id) {
        case 0: return "NROM";
        case 1: return "MMC1 (SxROM)";
        case 2: return "UxROM";
        case 3: return "CNROM";
        case 4: return "MMC3 (TxROM)";
        case 5: return "MMC5 (ExROM)";
        case 7: return "AxROM";
        case 9: return "MMC2 (PxROM)";
        case 10: return "MMC4 (FxROM)";
        case 11: return "Color Dreams";
        case 19: return "Namco 163";
        case 21: return "VRC4a/VRC4c";
        case 22: return "VRC2a";
        case 23: return "VRC4e/VRC4f/VRC2b";
        case 24: return "VRC6a";
        case 25: return "VRC4b/VRC4d/VRC2c";
        case 26: return "VRC6b";
        case 66: return "GxROM";
        case 69: return "Sunsoft FME-7";
        default: return "Unknown";
    }
}



std::string prettyPrint(const iNESHeader& header) {
    std::ostringstream oss;
    
    // Determine format version
    bool is_nes2 = (header.flags7 & 0x0C) == 0x08;
    
    // Calculate mapper ID
    u8 mapper_low = (header.flags6 >> 4) & 0x0F;
    u8 mapper_high = (header.flags7 >> 4) & 0x0F;
    u16 mapper_id = 0;
    
    if (is_nes2) {
        // iNES 2.0: 12-bit mapper ID using flags11
        u16 mapper_ext = (header.flags11 & 0x0F) << 8;
        mapper_id = mapper_ext | (mapper_high << 4) | mapper_low;
    } else {
        // iNES 1.0: 8-bit mapper ID
        mapper_id = (mapper_high << 4) | mapper_low;
    }
    
    // Calculate ROM sizes
    u32 prg_rom_size = 0;
    u32 chr_rom_size = 0;
    
    if (is_nes2) {
        // iNES 2.0 extended size calculation
        u8 prg_msb = header.flags9 & 0x0F;
        if (prg_msb == 0x0F) {
            // Exponent-multiplier format
            u8 exponent = (header.prg_rom_size >> 2) & 0x3F;
            u8 multiplier = header.prg_rom_size & 0x03;
            prg_rom_size = (1 << exponent) * (multiplier * 2 + 1);
        } else {
            u32 prg_units = ((prg_msb << 8) | header.prg_rom_size);
            prg_rom_size = prg_units * 0x4000;  // 16KB units
        }
        
        u8 chr_msb = (header.flags9 >> 4) & 0x0F;
        if (chr_msb == 0x0F) {
            // Exponent-multiplier format
            u8 exponent = (header.chr_rom_size >> 2) & 0x3F;
            u8 multiplier = header.chr_rom_size & 0x03;
            chr_rom_size = (1 << exponent) * (multiplier * 2 + 1);
        } else {
            u32 chr_units = ((chr_msb << 8) | header.chr_rom_size);
            chr_rom_size = chr_units * 0x2000;  // 8KB units
        }
    } else {
        // iNES 1.0 simple calculation
        prg_rom_size = header.prg_rom_size * 0x4000;  // 16KB units
        chr_rom_size = header.chr_rom_size * 0x2000;  // 8KB units
    }
    
    // Determine mirroring mode
    bool four_screen = (header.flags6 & 0x08) != 0;
    bool vertical_mirror = (header.flags6 & 0x01) != 0;
    std::string mirroring;
    if (four_screen) {
        mirroring = "Four-screen";
    } else if (vertical_mirror) {
        mirroring = "Vertical";
    } else {
        mirroring = "Horizontal";
    }
    
    // Check flags
    bool has_battery = (header.flags6 & 0x02) != 0;
    bool has_trainer = (header.flags6 & 0x04) != 0;
    
    // Build formatted output
    oss << "iNES Header Information:\n";
    oss << "  Format: " << (is_nes2 ? "iNES 2.0" : "iNES 1.0") << "\n";
    oss << "  Mapper: " << mapper_id << " (" << getMapperName(mapper_id) << ")\n";
    
    // PRG-ROM size
    if (prg_rom_size >= 1024) {
        u32 prg_kb = prg_rom_size / 1024;
        u32 prg_banks = prg_rom_size / 0x4000;  // 16KB banks
        oss << "  PRG-ROM: " << prg_kb << "KB (" << prg_banks << " x 16KB banks)\n";
    } else {
        oss << "  PRG-ROM: " << prg_rom_size << " bytes\n";
    }
    
    // CHR-ROM size
    if (chr_rom_size == 0) {
        oss << "  CHR-ROM: 0KB (uses CHR-RAM)\n";
    } else if (chr_rom_size >= 1024) {
        u32 chr_kb = chr_rom_size / 1024;
        u32 chr_banks = chr_rom_size / 0x2000;  // 8KB banks
        oss << "  CHR-ROM: " << chr_kb << "KB (" << chr_banks << " x 8KB banks)\n";
    } else {
        oss << "  CHR-ROM: " << chr_rom_size << " bytes\n";
    }
    
    // PRG-RAM size (iNES 2.0 provides this info)
    if (is_nes2 && header.flags8 != 0) {
        u8 prg_ram_shift = header.flags8 & 0x0F;
        if (prg_ram_shift > 0) {
            u32 prg_ram_size = 64 << prg_ram_shift;
            oss << "  PRG-RAM: " << prg_ram_size << " bytes\n";
        }
    }
    
    oss << "  Mirroring: " << mirroring << "\n";
    oss << "  Battery: " << (has_battery ? "Yes" : "No") << "\n";
    oss << "  Trainer: " << (has_trainer ? "Yes" : "No") << "\n";
    
    return oss.str();
}

} // namespace iNES
} // namespace NES
