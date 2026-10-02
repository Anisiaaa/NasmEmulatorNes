#pragma once

#include <cstdint>
#include <cstring>
#include <cstddef>
#include <memory>
#include "cartridge.hpp"

#define CYCLES_PER_SCANLINE 341
#define SCANLINES_PER_FRAME 262
#define VISIBLE_SCANLINES 240
#define PPU_SCREEN_WIDTH 256
#define PPU_SCREEN_HEIGHT 240

typedef uint8_t (*ChrReadFn)(void*, uint16_t);
extern "C" const uint32_t nes_palette_rgb[64];

enum class MirrorMode : uint8_t {
    HORIZONTAL  = 0,
    VERTICAL    = 1,
    SINGLE_LOW  = 2,
    SINGLE_HIGH = 3
};

struct PPUState {
    uint8_t ctrl;
    uint8_t mask;
    uint8_t status;
    uint8_t oam_addr;

    uint16_t v;
    uint16_t t;
    uint8_t fine_x;

    uint8_t open_bus;
    uint8_t ppudata_buffer;

    uint8_t vram[0x0800];
    uint8_t palette_ram[32];
    uint8_t oam[256];
    uint8_t secondary_oam[32];

    int cycle;
    int scanline;
    uint64_t frame_count;

    bool nmi_flag;
    bool nmi_enabled;
    bool odd_frame;
    bool frame_ready;

    bool write_toggle;

    bool dma_pending;
    uint8_t dma_page;
    uint64_t dma_trigger_cycle;

    uint8_t sprite_count;
    bool sprite_zero_in_range;

    MirrorMode mirror_mode;

    uint32_t framebuffer[PPU_SCREEN_WIDTH * PPU_SCREEN_HEIGHT];

    // Must be at the very end – do NOT move above other fields!
    bool nmi_triggered;
};

class PPU {
public:
    PPU();
    ~PPU();

    void initialize();
    void reset();

    void write_register(uint8_t addr, uint8_t value);
    uint8_t read_register(uint8_t addr);

    void clock();

    const PPUState& get_state() const;
    PPUState& get_state_mut();

    bool in_vblank() const;
    bool sprite_0_hit() const;
    bool should_trigger_nmi();
    void clear_nmi_flag();
    uint64_t get_frame_count() const;

    const uint32_t* get_framebuffer() const;

    void set_mirror_mode(MirrorMode mode);
    MirrorMode get_mirror_mode() const;

    void set_cartridge(NES::Cartridge* cart);

    void trigger_dma(uint8_t page);
    bool is_dma_pending() const;
    void complete_dma(const uint8_t* cpu_ram);
    uint64_t get_dma_trigger_cycle() const;

    bool is_frame_ready() const;
    void clear_frame_ready();

    uint8_t  read_vram(uint16_t addr);
    void     write_vram(uint16_t addr, uint8_t value);

    static PPU* from_state(PPUState* state);

private:
    PPUState state;
    NES::Cartridge* cartridge = nullptr;

    uint8_t  ppudata_read();
    void     ppudata_write(uint8_t value);

    void increment_x();
    void increment_y();
    void copy_x();
    void copy_y();

    void update_status_register();
    void handle_scanline_end();
    void handle_vblank_start();
    void handle_vblank_end();
    uint16_t apply_vram_mirroring(uint16_t addr);
};