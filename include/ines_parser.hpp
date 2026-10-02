#pragma once
#include <string>
#include "types.hpp"

namespace NES {

// iNESHeader structure definition
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

std::string getMapperName(u16 mapper_id);

// Formats an iNES header into a human-readable string representation.
// Displays:
// - Format version (iNES 1.0 vs iNES 2.0)
// - Mapper number and name
// - PRG-ROM and CHR-ROM sizes (in KB and bank counts)
// - PRG-RAM presence (if any)
// - Mirroring mode (horizontal, vertical, four-screen)
// - Battery-backed save RAM indicator
// - Trainer presence indicator
// @param header The iNES header structure to format
// @return A formatted multi-line string with labeled fields
// Example output:
// ```
// iNES Header Information:
// Format: iNES 2.0
// Mapper: 4 (MMC3)
// PRG-ROM: 256KB (16 x 16KB banks)
// CHR-ROM: 128KB (16 x 8KB banks)
// Mirroring: Horizontal
// Battery: Yes
// Trainer: No
// ```

std::string prettyPrint(const iNESHeader& header);

} // namespace iNES
} // namespace NES