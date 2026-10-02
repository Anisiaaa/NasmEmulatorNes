
#pragma once

#include <SDL2/SDL.h>
#include <cstdint>

// Forward declaration
class PPU;

namespace NES {

class Graphics {
public:
    Graphics();
    ~Graphics();

    // Initialize SDL renderer and texture
    bool initialize(SDL_Window* window);

    // Cleanup SDL resources
    void cleanup();

    // Render the current PPU framebuffer to the window
    void render(const PPU& ppu);

private:
    SDL_Renderer* renderer_;
    SDL_Texture* texture_;
    bool initialized_;
};

} // namespace NES
