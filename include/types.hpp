#pragma once

#include <cstdint>

// NES-specific types for clarity
using u8 = uint8_t;
using u16 = uint16_t;
using u32 = uint32_t;
using u64 = uint64_t;

using i8 = int8_t;
using i16 = int16_t;
using i32 = int32_t;
using i64 = int64_t;

// NES Memory addresses
namespace NES {
    // Memory map
    constexpr u16 RAM_START = 0x0000;
    constexpr u16 RAM_END = 0x07FF;
    constexpr u16 PPU_START = 0x2000;
    constexpr u16 PPU_END = 0x3FFF;
    constexpr u16 APU_START = 0x4000;
    constexpr u16 APU_END = 0x4017;
    constexpr u16 CARTRIDGE_START = 0x4020;
    constexpr u16 CARTRIDGE_END = 0xFFFF;

    // PPU Registers
    constexpr u16 PPUCTRL = 0x2000;
    constexpr u16 PPUMASK = 0x2001;
    constexpr u16 PPUSTATUS = 0x2002;
    constexpr u16 OAMADDR = 0x2003;
    constexpr u16 OAMDATA = 0x2004;
    constexpr u16 PPUSCROLL = 0x2005;
    constexpr u16 PPUADDR = 0x2006;
    constexpr u16 PPUDATA = 0x2007;

    // Screen dimensions
    constexpr u32 SCREEN_WIDTH = 256;
    constexpr u32 SCREEN_HEIGHT = 240;

    // Timing
    constexpr double REFRESH_RATE = 60.0988; // Hz (NTSC)
    constexpr u32 CYCLES_PER_FRAME = 29780; // Approximate
    constexpr u32 CYCLES_PER_SCANLINE = 114;
    constexpr u32 SCANLINES_PER_FRAME = 262;

    // Colors (NES palette)
    constexpr u32 NES_PALETTE[64] = {
        0x666666, 0x002A88, 0x1412A7, 0x3B00A4, 0x5C007E, 0x6E0040, 0x6C0600, 0x561D00,
        0x333500, 0x0B4800, 0x005200, 0x004F08, 0x00404D, 0x000000, 0x000000, 0x000000,
        0xADADAD, 0x155FD9, 0x4240FF, 0x7527FE, 0xA01ACC, 0xB71E7B, 0xB53120, 0x994E00,
        0x6B6D00, 0x388700, 0x0C9300, 0x008F32, 0x007C8D, 0x000000, 0x000000, 0x000000,
        0xFFFEFF, 0x64B0FF, 0x9290FF, 0xC676FF, 0xF36AFF, 0xFE6ECC, 0xFE8170, 0xEA9E22,
        0xBCBE00, 0x88D800, 0x5CE430, 0x45E082, 0x48CDDE, 0x4F4F4F, 0x000000, 0x000000,
        0xFFFEFF, 0xC0DFFF, 0xD3D2FF, 0xE8C8FF, 0xFBC2FF, 0xFEC4EA, 0xFECCC5, 0xF7D8A5,
        0xE4E594, 0xCFEF96, 0xBDF4AB, 0xB3F3CC, 0xB5EBF2, 0xB8B8B8, 0x000000, 0x000000
    };
}  // NAMESPACE NES