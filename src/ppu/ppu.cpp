#include "ppu.hpp"
#include "memory_system.hpp"
#include <cstring>

extern "C" void renderScanline(PPUState* state, int scanline, uint32_t* fb_row);
extern "C" uint32_t evaluateSprites(uint8_t* oam, uint8_t* secondary_oam,
                                     int scanline, int sprite_height,
                                     uint8_t* ppustatus);

extern "C" uint8_t ppu_read_nt_byte(PPUState* state, uint16_t addr) {
    PPU* ppu = PPU::from_state(state);
    return ppu->read_vram(addr);
}

extern "C" uint8_t ppu_read_chr(PPUState* state, uint16_t addr);
extern "C" uint8_t ppu_read_nt_byte(PPUState* state, uint16_t addr);

extern "C" void renderSpritesCpp(PPUState* state, int scanline, uint8_t* bg_row, uint32_t* fb_row) {
    if (!(state->mask & 0x10)) return;
    if (state->sprite_count == 0) return;

    for (int i = state->sprite_count - 1; i >= 0; --i) {
        uint8_t* entry = &state->secondary_oam[i * 4];
        int y = entry[0] + 1;
        int sprite_row = scanline - y;
        uint8_t tile   = entry[1];
        uint8_t attr   = entry[2];
        int x          = entry[3];

        uint16_t chr_addr;
        if (state->ctrl & 0x20) {
            int bank = (tile & 1) << 12;
            int base_tile = tile & 0xFE;
            if (attr & 0x80) sprite_row = 15 - sprite_row;
            if (sprite_row >= 8) { base_tile++; sprite_row -= 8; }
            chr_addr = bank | (base_tile << 4) | (sprite_row & 7);
        } else {
            uint16_t table = (state->ctrl & 0x08) ? 0x1000 : 0;
            if (attr & 0x80) sprite_row = 7 - sprite_row;
            chr_addr = table | (tile << 4) | (sprite_row & 7);
        }

        uint8_t chr_lo = ppu_read_chr(state, chr_addr);
        uint8_t chr_hi = ppu_read_chr(state, chr_addr + 8);

        int pal_base = 0x10 + ((attr & 0x03) << 2);
        bool behind_bg = (attr & 0x20) != 0;

        for (int p = 0; p < 8; ++p) {
            int px = x + p;
            if (px >= 256) break;
            if (px < 8 && !(state->mask & 0x04)) continue;

            int bit = (attr & 0x40) ? p : (7 - p);
            int lo = (chr_lo >> bit) & 1;
            int hi = (chr_hi >> bit) & 1;
            if (lo == 0 && hi == 0) continue;

            if (behind_bg && bg_row[px] != 0) continue;

            if (state->sprite_zero_in_range && i == 0 &&
                (state->mask & 0x08) && (state->mask & 0x10)) {
                state->status |= 0x40;
            }

            int idx = (hi << 1) | lo;
            uint8_t pal = pal_base + idx;
            uint8_t nes_col = state->palette_ram[pal] & 0x3F;
            fb_row[px] = nes_palette_rgb[nes_col];
        }
    }
}

extern "C" void renderBackground_cpp(uint16_t v, uint8_t fine_x,
    uint8_t* /*vram*/, PPUState* ppu_state, void* /*unused*/,
    uint8_t* palette_ram, uint8_t* bg_row, uint8_t ppumask)
{
    if (!(ppumask & 0x08)) {
        memset(bg_row, palette_ram[0], 256);
        return;
    }

    uint16_t loopy_v = v & 0x7FFF;

    // Decompose the scroll (loopy v) register.
    int coarse_x = loopy_v & 0x1F;              // bits 0-4: coarse X
    int coarse_y = (loopy_v >> 5) & 0x1F;       // bits 5-9: coarse Y
    int fine_y   = (loopy_v >> 12) & 0x07;      // bits 12-14: fine Y
    int nt_h     = (loopy_v >> 10) & 1;         // bit 10: horizontal nametable select
    int nt_v     = (loopy_v >> 11) & 1;         // bit 11: vertical nametable select

    int pixel_col = 0;
    int tile_x    = coarse_x;                   // tile position at left edge
    int sl_nt_h   = nt_h;                       // current horizontal nametable
    bool first    = true;

    // Render tiles until the 256-pixel row is filled. We may need up to 33
    // tiles when fine_x > 0 (the first tile is partially clipped).
    while (pixel_col < 256) {
        // Nametable address (16x16-tile grid, 32x30 tiles).
        uint16_t nt_base = 0x2000 | (nt_v << 11) | (sl_nt_h << 10);
        uint16_t nt_addr = nt_base | (coarse_y << 5) | tile_x;
        uint8_t tile_idx = ppu_read_nt_byte(ppu_state, nt_addr);

        // Attribute table entry for the 4x4-tile block containing this tile.
        uint16_t at_addr = (nt_base + 0x3C0) | ((coarse_y >> 2) << 3) | (tile_x >> 2);
        uint8_t attr_byte = ppu_read_nt_byte(ppu_state, at_addr);
        int shift = ((coarse_y & 2) << 1) | (tile_x & 2);
        uint8_t attr_bits = (attr_byte >> shift) & 0x03;

        // Pattern address: tile*16 + fine_y row; optional 0x1000 table select.
        uint16_t chr_addr = (tile_idx * 16) + fine_y;
        if (ppu_state->ctrl & 0x10) chr_addr += 0x1000;
        uint8_t chr_lo = ppu_read_chr(ppu_state, chr_addr);
        uint8_t chr_hi = ppu_read_chr(ppu_state, chr_addr + 8);

        // Number of pixels this tile contributes and the bit to start from.
        int start_bit = 7;
        int count     = 8;
        if (first && fine_x != 0) {
            // Leftmost tile is shifted left by fine_x: only the rightmost
            // (8-fine_x) pixels are visible, starting at bit (7-fine_x).
            start_bit = 7 - fine_x;
            count     = 8 - fine_x;
        }
        first = false;

        for (int p = 0; p < count && pixel_col < 256; ++p) {
            int bit = start_bit - p;
            uint8_t lo = (chr_lo >> bit) & 1;
            uint8_t hi = (chr_hi >> bit) & 1;
            uint8_t color_idx = (attr_bits << 2) | (hi << 1) | lo;
            if (lo == 0 && hi == 0) color_idx = 0;
            bg_row[pixel_col++] = color_idx;
        }

        // Advance to the next tile column, wrapping into the other horizontal
        // nametable at the 32-tile boundary (this is what scrolls the screen).
        tile_x++;
        if (tile_x == 32) {
            tile_x = 0;
            sl_nt_h ^= 1;
        }
    }

    // Suppress the leftmost 8 pixels when the "left column" background is off.
    if (!(ppumask & 0x02)) {
        memset(bg_row, palette_ram[0], 8);
    }
}

extern "C" uint8_t ppu_read_chr(PPUState* state, uint16_t addr) {
    if (!state) return 0;
    PPU* ppu = PPU::from_state(state);
    if (!ppu) return 0;
    if (addr >= 0x2000) return 0;
    return ppu->read_vram(addr);
}

PPU* PPU::from_state(PPUState* state_ptr) {
    return reinterpret_cast<PPU*>(
        reinterpret_cast<char*>(state_ptr) - offsetof(PPU, state)
    );
}

PPU::PPU()  { initialize(); }
PPU::~PPU() {}

void PPU::initialize() {
    std::memset(&state, 0, sizeof(PPUState));
    state.ctrl        = 0;
    state.mask        = 0;
    state.status      = 0xA0;
    state.oam_addr    = 0;
    state.v           = 0;
    state.t           = 0;
    state.fine_x      = 0;
    state.open_bus    = 0;
    state.ppudata_buffer = 0;
    state.cycle       = 0;
    state.scanline    = 0;
    state.frame_count = 0;
    state.nmi_flag    = false;
    state.nmi_triggered = false;
    state.nmi_enabled = false;
    state.odd_frame   = false;
    state.frame_ready = false;
    state.write_toggle = false;
    state.dma_pending = false;
    state.dma_page    = 0;
    state.sprite_count = 0;
    state.sprite_zero_in_range = false;
    state.mirror_mode = MirrorMode::VERTICAL;
    std::memset(state.vram,         0, sizeof(state.vram));
    std::memset(state.palette_ram,  0, sizeof(state.palette_ram));
    std::memset(state.oam,          0, sizeof(state.oam));
    std::memset(state.secondary_oam,0, sizeof(state.secondary_oam));
    std::memset(state.framebuffer,  0, sizeof(state.framebuffer));
}

void PPU::reset() {
    state.ctrl         = 0;
    state.mask         = 0;
    state.status       = 0xA0;
    state.v            = 0;
    state.t            = 0;
    state.fine_x       = 0;
    state.write_toggle = false;
    state.nmi_flag     = false;
    state.nmi_triggered = false;
    state.nmi_enabled  = false;
    state.odd_frame    = false;
    state.frame_ready  = false;
    state.open_bus     = 0;
    state.ppudata_buffer = 0;
    state.dma_pending  = false;
    state.dma_page     = 0;
    state.sprite_count = 0;
    state.sprite_zero_in_range = false;
}

uint16_t PPU::apply_vram_mirroring(uint16_t addr) {
    addr &= 0x3FFF;
    if (addr < 0x2000) return addr;
    if (addr >= 0x3F00) return addr;
    if (addr >= 0x3000) addr -= 0x1000;
    uint16_t nt_offset = addr - 0x2000;
    uint16_t page      = nt_offset >> 10;
    uint16_t in_page   = nt_offset & 0x03FF;
    static const uint8_t mirror_table[4][4] = {
        { 0, 0, 1, 1 },  // HORIZONTAL
        { 0, 1, 0, 1 },  // VERTICAL
        { 0, 0, 0, 0 },  // SINGLE_LOW
        { 1, 1, 1, 1 },  // SINGLE_HIGH
    };
    uint8_t mode = static_cast<uint8_t>(state.mirror_mode);
    uint8_t phys = mirror_table[mode][page];
    return (phys << 10) | in_page;
}

uint8_t PPU::read_vram(uint16_t addr) {
    addr &= 0x3FFF;
    if (addr < 0x2000) {
        addr &= 0x1FFF;
        return cartridge ? cartridge->readCHR(addr) : 0;
    }
    if (addr < 0x3F00) {
        uint16_t phys = apply_vram_mirroring(addr);
        return state.vram[phys & 0x07FF];
    }
    uint8_t pal_idx = (addr - 0x3F00) & 0x1F;
    if (pal_idx == 0x10 || pal_idx == 0x14 || pal_idx == 0x18 || pal_idx == 0x1C)
        pal_idx &= 0x0F;
    return state.palette_ram[pal_idx];
}

void PPU::write_vram(uint16_t addr, uint8_t value) {
    addr &= 0x3FFF;
    if (addr < 0x2000) {
        if (cartridge) cartridge->writeCHR(addr, value);
        return;
    }
    if (addr < 0x3F00) {
        uint16_t phys = apply_vram_mirroring(addr);
        state.vram[phys & 0x07FF] = value;
        return;
    }
    uint8_t pal_idx = (addr - 0x3F00) & 0x1F;
    state.palette_ram[pal_idx] = value;
    if (pal_idx == 0x10 || pal_idx == 0x14 || pal_idx == 0x18 || pal_idx == 0x1C)
        state.palette_ram[pal_idx & 0x0F] = value;
    if (pal_idx == 0x00 || pal_idx == 0x04 || pal_idx == 0x08 || pal_idx == 0x0C)
        state.palette_ram[pal_idx | 0x10] = value;
}

uint8_t PPU::ppudata_read() {
    uint16_t addr = state.v & 0x3FFF;
    uint8_t result;
    if (addr < 0x3F00) {
        result = state.ppudata_buffer;
        state.ppudata_buffer = read_vram(addr);
    } else {
        result = read_vram(addr);
        state.ppudata_buffer = read_vram(addr & 0x2FFF);
    }
    uint16_t inc = (state.ctrl & 0x04) ? 32 : 1;
    state.v = (state.v + inc) & 0x7FFF;
    state.open_bus = result;
    return result;
}

void PPU::ppudata_write(uint8_t value) {
    write_vram(state.v & 0x3FFF, value);
    uint16_t inc = (state.ctrl & 0x04) ? 32 : 1;
    state.v = (state.v + inc) & 0x7FFF;
}

void PPU::write_register(uint8_t addr, uint8_t value) {
    state.open_bus = value;
    switch (addr) {
        case 0x0000:
            state.ctrl = value;
            state.nmi_enabled = (value & 0x80) != 0;
            state.t = (state.t & ~0x0C00u) | (static_cast<uint16_t>(value & 0x03) << 10);
            break;
        case 0x0001:
            state.mask = value;
            break;
        case 0x0002: break;
        case 0x0003:
            state.oam_addr = value;
            break;
        case 0x0004:
            state.oam[state.oam_addr] = value;
            state.oam_addr++;
            break;
        case 0x0005:
            if (!state.write_toggle) {
                state.fine_x = value & 0x07;
                state.t = (state.t & ~0x001Fu) | (static_cast<uint16_t>(value >> 3));
                state.write_toggle = true;
            } else {
                state.t = (state.t & ~0x73E0u)
                        | (static_cast<uint16_t>(value & 0x07) << 12)
                        | (static_cast<uint16_t>(value >> 3)   <<  5);
                state.write_toggle = false;
            }
            break;
        case 0x0006:
            if (!state.write_toggle) {
                state.t = (state.t & 0x00FFu) | (static_cast<uint16_t>(value & 0x3F) << 8);
                state.t &= ~0x4000u;
                state.write_toggle = true;
            } else {
                state.t = (state.t & 0xFF00u) | value;
                state.v = state.t;
                state.ppudata_buffer = read_vram(state.v & 0x3FFF);
                state.write_toggle = false;
            }
            break;
        case 0x0007:
            ppudata_write(value);
            break;
    }
}

uint8_t PPU::read_register(uint8_t addr) {
    switch (addr) {
        case 0x0002: {
            uint8_t result = (state.status & 0xE0) | (state.open_bus & 0x1F);
            state.status &= ~0x80u;
            state.write_toggle = false;
            state.open_bus = result;
            return result;
        }
        case 0x0004: return state.oam[state.oam_addr];
        case 0x0007: return ppudata_read();
        default: return state.open_bus;
    }
}

void PPU::increment_x() {
    if ((state.v & 0x001F) == 31) {
        state.v &= ~0x001Fu;
        state.v ^= 0x0400;
    } else {
        state.v++;
    }
}

void PPU::increment_y() {
    if ((state.v & 0x7000) != 0x7000) {
        state.v += 0x1000;
    } else {
        state.v &= ~0x7000u;
        uint16_t coarse_y = (state.v & 0x03E0) >> 5;
        if (coarse_y == 29) {
            coarse_y = 0;
            state.v ^= 0x0800;
        } else if (coarse_y == 31) {
            coarse_y = 0;
        } else {
            coarse_y++;
        }
        state.v = (state.v & ~0x03E0u) | (coarse_y << 5);
    }
}

void PPU::copy_x() {
    state.v = (state.v & ~0x041Fu) | (state.t & 0x041F);
}

void PPU::copy_y() {
    state.v = (state.v & ~0x7BE0u) | (state.t & 0x7BE0);
}

void PPU::clock() {
    bool rendering_enabled = (state.mask & 0x18) != 0;

    if (state.scanline == 261 && state.cycle == 339 && state.odd_frame && rendering_enabled) {
        state.cycle    = 0;
        state.scanline = 0;
        state.odd_frame = !state.odd_frame;
        state.frame_count++;
        return;
    }

    if (state.scanline == 261 && state.cycle == 1) {
        state.status &= ~0xC0u;
        state.nmi_flag = false;
        state.nmi_triggered = false;
    }

    if (state.scanline == 261 && state.cycle >= 280 && state.cycle <= 304 && rendering_enabled) {
        copy_y();
    }

    if (state.scanline >= 0 && state.scanline <= 239) {
        if (state.cycle == 1 && rendering_enabled) {
            renderScanline(&state, state.scanline, &state.framebuffer[state.scanline * 256]);
        }

        if (state.cycle == 65 && rendering_enabled) {
            int next_scanline = state.scanline + 1;
            int sprite_height = (state.ctrl & 0x20) ? 16 : 8;
            uint32_t result = evaluateSprites(state.oam, state.secondary_oam,
                                              next_scanline, sprite_height,
                                              &state.status);
            state.sprite_count         = static_cast<uint8_t>(result & 0xFF);
            state.sprite_zero_in_range = (result & 0x100) != 0;
        }

        if (state.cycle == 256 && rendering_enabled) {
            increment_y();
        }

        if (state.cycle == 257 && rendering_enabled) {
            copy_x();
        }
    }

    if (state.scanline == 239 && state.cycle == 256) {
        state.frame_ready = true;
    }

    if (state.scanline == 241 && state.cycle == 1) {
        state.status |= 0x80;
        if (state.nmi_enabled) {
            state.nmi_flag = true;
        }
    }

    state.cycle++;
    if (state.cycle >= CYCLES_PER_SCANLINE) {
        state.cycle = 0;
        state.scanline++;
        if (state.scanline >= SCANLINES_PER_FRAME) {
            state.scanline  = 0;
            state.odd_frame = !state.odd_frame;
            state.frame_count++;
        }
    }
}

const PPUState& PPU::get_state() const { return state; }
PPUState& PPU::get_state_mut() { return state; }
bool PPU::in_vblank() const { return (state.status & 0x80) != 0; }
bool PPU::sprite_0_hit() const { return (state.status & 0x40) != 0; }

bool PPU::should_trigger_nmi() {
    if (state.nmi_flag && !state.nmi_triggered) {
        state.nmi_triggered = true;
        return true;
    }
    return false;
}

void PPU::clear_nmi_flag() {
    state.nmi_flag = false;
    state.nmi_triggered = true;
}

uint64_t PPU::get_frame_count() const { return state.frame_count; }
const uint32_t* PPU::get_framebuffer() const { return state.framebuffer; }

void PPU::set_mirror_mode(MirrorMode mode) { state.mirror_mode = mode; }
MirrorMode PPU::get_mirror_mode() const { return state.mirror_mode; }
void PPU::set_cartridge(NES::Cartridge* cart) { cartridge = cart; }

void PPU::trigger_dma(uint8_t page) {
    state.dma_pending = true;
    state.dma_page    = page;
    state.dma_trigger_cycle = NES::gMemoryBus.getCycleCounter();
}

bool PPU::is_dma_pending() const { return state.dma_pending; }

void PPU::complete_dma(const uint8_t* cpu_ram) {
    for (int i = 0; i < 256; i++) {
        state.oam[(state.oam_addr + i) & 0xFF] =
            cpu_ram[(static_cast<uint16_t>(state.dma_page) << 8) | i];
    }
    state.dma_pending = false;
}

uint64_t PPU::get_dma_trigger_cycle() const { return state.dma_trigger_cycle; }
bool PPU::is_frame_ready() const { return state.frame_ready; }
void PPU::clear_frame_ready() { state.frame_ready = false; }

void PPU::update_status_register() {}
void PPU::handle_scanline_end()    {}
void PPU::handle_vblank_start()    { state.status |= 0x80; }
void PPU::handle_vblank_end()      { state.status &= 0x7F; }