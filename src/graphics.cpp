#include "graphics.hpp"
#include "ppu.hpp"
#include <iostream>

// The official NES NTSC Palette for 64-color index mapping
const uint32_t NES_PALETTE[64] = {
    0xFF7C7C7C, 0xFF0000FC, 0xFF0000BC, 0xFF4428BC, 0xFF940084, 0xFFA80020, 0xFFA81000, 0xFF881400,
    0xFF503000, 0xFF007800, 0xFF006800, 0xFF005800, 0xFF004058, 0xFF000000, 0xFF000000, 0xFF000000,
    0xFFBCBCBC, 0xFF0078F8, 0xFF0058F8, 0xFF6844FC, 0xFFD800CC, 0xFFA40058, 0xFFF83800, 0xFFE45C10,
    0xFFAC7C00, 0xFF00B800, 0xFF00A800, 0xFF00A844, 0xFF008888, 0xFF000000, 0xFF000000, 0xFF000000,
    0xFFF8F8F8, 0xFF3CBCFC, 0xFF6888FC, 0xFF9878F8, 0xFFF838F8, 0xFFF85898, 0xFFF87858, 0xFFFCA044,
    0xFFF8B800, 0xFFB8F818, 0xFF58D854, 0xFF58F898, 0xFF00E8D8, 0xFF787878, 0xFF000000, 0xFF000000,
    0xFFFCFCFC, 0xFFA4E4FC, 0xFFB8B8F8, 0xFFD8B8F8, 0xFFF8B8F8, 0xFFF8A4C0, 0xFFF0D0B0, 0xFFFCE0A8,
    0xFFF8D878, 0xFFD8F878, 0xFFB8F8B8, 0xFFF8D8F8, 0xFF00F8F8, 0xFFC8C8C8, 0xFF000000, 0xFF000000
};

namespace NES {

Graphics::Graphics() 
    : renderer_(nullptr)
    , texture_(nullptr)
    , initialized_(false) {
}

Graphics::~Graphics() {
    cleanup();
}

bool Graphics::initialize(SDL_Window* window) {
    if (!window) return false;

    // Create SDL renderer with VSync to match standard 60FPS
    renderer_ = SDL_CreateRenderer(window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!renderer_) return false;

    // Create texture for NES screen (256x240)
    texture_ = SDL_CreateTexture(
        renderer_,
        SDL_PIXELFORMAT_ARGB8888,
        SDL_TEXTUREACCESS_STREAMING,
        PPU_SCREEN_WIDTH,
        PPU_SCREEN_HEIGHT
    );

    if (!texture_) {
        SDL_DestroyRenderer(renderer_);
        return false;
    }

    initialized_ = true;
    return true;
}

void Graphics::cleanup() {
    if (texture_) SDL_DestroyTexture(texture_);
    if (renderer_) SDL_DestroyRenderer(renderer_);
    initialized_ = false;
}

void Graphics::render(const PPU& ppu) {
    if (!initialized_) return;

    // The PPU provides a fully-rendered 32-bit ARGB framebuffer.
    const uint32_t* fb = ppu.get_framebuffer();
    uint32_t display_buffer[256 * 240];

    for (int i = 0; i < 256 * 240; i++) {
        display_buffer[i] = fb[i];
    }

    // Update the texture with the fully rendered ARGB frame
    SDL_UpdateTexture(texture_, nullptr, display_buffer, PPU_SCREEN_WIDTH * sizeof(uint32_t));

    // Draw to window
    SDL_RenderClear(renderer_);
    SDL_RenderCopy(renderer_, texture_, nullptr, nullptr);
    SDL_RenderPresent(renderer_);
}

} // namespace NES