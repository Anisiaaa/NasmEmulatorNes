#include <iostream>
#include <fstream>
#include <iomanip>
#include <cstdlib>
#include <cstdio>
#include <SDL2/SDL.h>
#include "emulator.hpp"
#include "cartridge.hpp"
#include "graphics.hpp"
#include "ppu.hpp"
#include "cpu_state.hpp"
#include "controller.hpp"
#include "tas.hpp"
#include "ui.hpp"

bool gNestestMode = false;

extern "C" {
    int64_t testAdd(int64_t a, int64_t b);
    const char* getCPUVersion();
}

namespace NES {
    extern CPUState gCPUState;
}

static bool inputTraceEnabled() {
    return std::getenv("NES_INPUT_TRACE") != nullptr;
}

int main(int argc, char* argv[]) {
    if (argc > 1) {
        std::cerr << "[MAIN] Command line ROM (still selectable in the UI): "
                  << argv[1] << std::endl;
    }

    std::cerr << "[MAIN] Starting emulator..." << std::endl;
    std::cout << "=== NES Emulator - Linux Build ===" << std::endl;
    std::cout << "CPU Version: " << getCPUVersion() << std::endl;

    if (SDL_Init(SDL_INIT_VIDEO | SDL_INIT_EVENTS) < 0) {
        std::cerr << "SDL2 initialization failed: " << SDL_GetError() << std::endl;
        return 1;
    }

    SDL_Window* window = SDL_CreateWindow(
        "NES Emulator",
        SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED,
        512, 480, SDL_WINDOW_SHOWN
    );
    if (!window) {
        std::cerr << "Window creation failed: " << SDL_GetError() << std::endl;
        SDL_Quit();
        return 1;
    }

    SDL_RaiseWindow(window);
    SDL_SetWindowInputFocus(window);
    std::cerr << "[MAIN] Click the NES Emulator window to control the game." << std::endl;
    std::cerr << "[MAIN] Controls: Arrows=Move  A/Z=Jump(A)  X=Run(B)  Enter=Start  RShift=Select" << std::endl;

    SDL_Renderer* renderer = SDL_CreateRenderer(
        window, -1, SDL_RENDERER_ACCELERATED | SDL_RENDERER_PRESENTVSYNC);
    if (!renderer) {
        std::cerr << "Renderer creation failed: " << SDL_GetError() << std::endl;
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    std::string initialRom = (argc >= 2) ? argv[1] : "";
    std::string initialTas = (argc >= 3) ? argv[2] : "";
    NES::LaunchSelection sel = NES::runLauncher(window, renderer, initialRom, initialTas);

    if (!sel.start) {
        // User closed the launcher without starting anything.
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 0;
    }

    std::string rom_path = sel.romPath;

    // The launcher renderer is no longer needed once a game is selected.
    // Release it before Graphics creates the gameplay renderer for this window.
    SDL_DestroyRenderer(renderer);
    renderer = nullptr;

    NES::TASMovie tas_movie;
    if (sel.mode == 1 && !sel.tasPath.empty()) {
        if (!tas_movie.loadFromFile(sel.tasPath)) {
            std::cerr << "Failed to load TAS movie: " << sel.tasPath << std::endl;
            SDL_DestroyRenderer(renderer);
            SDL_DestroyWindow(window);
            SDL_Quit();
            return 1;
        }
        std::cout << "TAS movie loaded: " << sel.tasPath << " ("
                  << tas_movie.totalFrames() << " frames, "
                  << (tas_movie.totalFrames() / 60) << "s)" << std::endl;
        if (!tas_movie.romFilename().empty())
            std::cout << "Movie was recorded with ROM: "
                      << tas_movie.romFilename() << std::endl;
    }

    NES::Cartridge cart;
    if (!cart.loadFromFile(rom_path)) {
        std::cerr << "Failed to load ROM: " << rom_path << std::endl;
        SDL_DestroyRenderer(renderer);
        SDL_DestroyWindow(window);
        SDL_Quit();
        return 1;
    }

    std::cout << "PRG-ROM size: " << cart.getPRGROMSize() << std::endl;
    std::cout << "CHR-ROM size: " << cart.getCHRROMSize() << std::endl;

    NES::initializeEmulator();
    NES::Emulator emulator;
    NES::gMemoryBus.setCartridge(&cart);

    NES::gPPU.set_mirror_mode(static_cast<MirrorMode>(cart.getMirrorMode()));
    NES::gPPU.set_cartridge(&cart);

    bool isNestest = (rom_path.find("nestest") != std::string::npos);
    if (isNestest) {
        gNestestMode = true;
        NES::dbg_dump_lax = true;
    }

    emulator.reset();

    std::ofstream nestestLog;
    if (isNestest) {
        nestestLog.open("nestest_out.log");
        if (!nestestLog.is_open()) {
            std::cerr << "Failed to open nestest_out.log" << std::endl;
            isNestest = false;
        } else {
            std::cout << "Nestest logging started -> nestest_out.log" << std::endl;
        }
    }

    NES::Graphics graphics;
    if (!isNestest) {
        if (!graphics.initialize(window)) {
            std::cerr << "Failed to initialize graphics: " << SDL_GetError() << std::endl;
            SDL_DestroyRenderer(renderer);
            SDL_DestroyWindow(window);
            SDL_Quit();
            return 1;
        }
        std::cout << "Graphics initialized successfully" << std::endl;
    }

    if (isNestest) {
        const int MAX_STEPS = 8991;
        for (int i = 0; i < MAX_STEPS; ++i) {
            // Save PC and state BEFORE executing instruction
            uint16_t pc = NES::gCPUState.PC;
            uint8_t a_before = NES::gCPUState.A;
            uint8_t x_before = NES::gCPUState.X;
            uint8_t y_before = NES::gCPUState.Y;
            uint8_t p_before = NES::gCPUState.P;
            uint8_t sp_before = NES::gCPUState.SP;
            
            // Read opcode bytes (instruction can be 1-3 bytes, but read 3 for simplicity)
            uint8_t op1 = NES::gMemoryBus.readMemory8(pc);
            uint8_t op2 = NES::gMemoryBus.readMemory8(pc + 1);
            uint8_t op3 = NES::gMemoryBus.readMemory8(pc + 2);
            
            emulator.step();

            nestestLog << std::hex << std::uppercase << std::setfill('0')
                       << std::setw(4) << pc << "  "
                       << std::setw(2) << (int)op1 << " "
                       << std::setw(2) << (int)op2 << " "
                       << std::setw(2) << (int)op3 << "  "
                       << "A:" << std::setw(2) << (int)a_before << " "
                       << "X:" << std::setw(2) << (int)x_before << " "
                       << "Y:" << std::setw(2) << (int)y_before << " "
                       << "P:" << std::setw(2) << (int)p_before << " "
                       << "SP:" << std::setw(2) << (int)sp_before
                       << std::dec << std::endl;
        }
        nestestLog.close();

        // Check nestest result - error code is at $6002-$6003, $6004 is completion flag
        uint16_t error_code = (NES::gMemoryBus.readMemory8(0x6003) << 8) | NES::gMemoryBus.readMemory8(0x6002);
        uint8_t completed = NES::gMemoryBus.readMemory8(0x6004);
        std::cout << "Nestest error code: 0x" << std::hex << std::uppercase
                  << std::setfill('0') << std::setw(4) << error_code << std::dec << std::endl;
        std::cout << "Nestest completed flag: 0x" << std::hex << std::uppercase
                  << std::setfill('0') << std::setw(2) << (int)completed << std::dec << std::endl;
        if (error_code == 0x0000 && completed == 0x00) {
            std::cout << "NESTEST PASSED!" << std::endl;
        } else {
            std::cout << "NESTEST FAILED!" << std::endl;
        }
    } else {
        const int TARGET_FPS = 60;
        const Uint32 FRAME_DELAY = 1000 / TARGET_FPS;
        int frame_count = 0;
        bool quit = false;

        bool rightDown  = false;
        bool leftDown   = false;
        bool downDown   = false;
        bool upDown     = false;
        bool aDown      = false;
        bool bDown      = false;
        bool selectDown = false;
        bool startDown  = false;

                auto updateControllerState = [&]() {
            SDL_Event e;
            while (SDL_PollEvent(&e)) {
                if (e.type == SDL_QUIT) {
                    quit = true;
                } else if (e.type == SDL_KEYDOWN && e.key.keysym.sym == SDLK_ESCAPE) {
                    quit = true;
                }
            }

            SDL_PumpEvents();
            
            // Check if window has focus
            Uint32 window_flags = SDL_GetWindowFlags(window);
            bool has_focus = (window_flags & SDL_WINDOW_INPUT_FOCUS) != 0;
            
            const Uint8* keys = SDL_GetKeyboardState(NULL);

            const char* debug_input_file = std::getenv("NES_DEBUG_INPUT_FILE");
            static int last_input_frame = -1;
            static bool file_input_active = false;
            bool using_file_input = file_input_active;
            if (debug_input_file && last_input_frame != frame_count) {
                std::ifstream fin(debug_input_file);
                if (fin.is_open()) {
                    std::string line;
                    has_focus = true;
                    file_input_active = true;
                    using_file_input = true;
                    while (std::getline(fin, line)) {
                        auto eq = line.find('=');
                        if (eq == std::string::npos) continue;
                        std::string key = line.substr(0, eq);
                        std::string val = line.substr(eq + 1);
                        bool pressed = (val == "1" || val == "true");
                        if (key == "RIGHT")   rightDown = pressed;
                        if (key == "LEFT")    leftDown = pressed;
                        if (key == "DOWN")    downDown = pressed;
                        if (key == "UP")      upDown = pressed;
                        if (key == "A")       aDown = pressed;
                        if (key == "B")       bDown = pressed;
                        if (key == "SELECT")  selectDown = pressed;
                        if (key == "START")   startDown = pressed;
                    }
                } else {
                    file_input_active = false;
                }
                last_input_frame = frame_count;
            }
            if (!using_file_input) {
                rightDown  = keys[SDL_SCANCODE_RIGHT];
                leftDown   = keys[SDL_SCANCODE_LEFT];
                downDown   = keys[SDL_SCANCODE_DOWN];
                upDown     = keys[SDL_SCANCODE_UP];
                // Accept the usual Z binding plus layout-safe/common A-button
                // alternatives. SDL scancodes identify physical keys, so on
                // QWERTZ layouts the key labelled Z may report as Y.
                aDown      = keys[SDL_SCANCODE_A] ||
                             keys[SDL_SCANCODE_Z] ||
                             keys[SDL_SCANCODE_Y] ||
                             keys[SDL_SCANCODE_SPACE] ||
                             keys[SDL_SCANCODE_LCTRL];
                bDown      = keys[SDL_SCANCODE_X];
                selectDown = keys[SDL_SCANCODE_RSHIFT];
                startDown  = (keys[SDL_SCANCODE_RETURN] || keys[SDL_SCANCODE_KP_ENTER]);
            }


            if (inputTraceEnabled()) {
                std::cerr << "[INPUT] focus=" << has_focus
                          << " right=" << rightDown
                          << " left=" << leftDown
                          << " down=" << downDown
                          << " up=" << upDown
                          << " a=" << aDown
                          << " b=" << bDown
                          << " select=" << selectDown
                          << " start=" << startDown
                          << " frame=" << frame_count
                          << std::endl;
            }

            NES::gControllerSystem.setButton(0, NES::BUTTON_RIGHT,  rightDown);
            NES::gControllerSystem.setButton(0, NES::BUTTON_LEFT,   leftDown);
            NES::gControllerSystem.setButton(0, NES::BUTTON_DOWN,   downDown);
            NES::gControllerSystem.setButton(0, NES::BUTTON_UP,     upDown);
            NES::gControllerSystem.setButton(0, NES::BUTTON_A,      aDown);
            NES::gControllerSystem.setButton(0, NES::BUTTON_B,      bDown);
            NES::gControllerSystem.setButton(0, NES::BUTTON_SELECT, selectDown);
            NES::gControllerSystem.setButton(0, NES::BUTTON_START,  startDown);

            if (tas_movie.isLoaded()) {
                u8 tas_buttons = 0x00;
                if (tas_movie.getFrameButtons(frame_count, tas_buttons))
                    NES::gControllerSystem.setButtonState(0, tas_buttons);
            }
        };

        while (!quit) {
            Uint32 frame_start = SDL_GetTicks();

            // TAS playback: honour power/reset commands in the movie.
            if (tas_movie.shouldReset(frame_count)) {
                std::cout << "[TAS] Reset command at frame "
                          << frame_count << std::endl;
                emulator.reset();
                NES::gControllerSystem.reset();
            }

            updateControllerState();

            int instructions = 0;
            while (!NES::gPPU.is_frame_ready()) {
                emulator.step();
                instructions++;
                if ((instructions & 0x0F) == 0) {
                    updateControllerState();
                }
                if (instructions > 200000) {
                    std::cerr << "ERROR: Too many instructions! Frame=" << frame_count << std::endl;
                    break;
                }
            }
            
            // Log frame completion details
            if (std::getenv("NES_CPU_TRACE")) {
                std::cerr << "[FRAME] frame=" << frame_count 
                          << " instructions=" << instructions
                          << " PC=0x" << std::hex << NES::gCPUState.PC << std::dec << std::endl;
            }
            
            graphics.render(NES::gPPU);
            NES::gPPU.clear_frame_ready();
            frame_count++;

            if (std::getenv("NES_GAME_TRACE")) {
                u8 fc  = NES::gMemoryBus.readMemory8(0x06FC);  // controller1 result
                u8 fd  = NES::gMemoryBus.readMemory8(0x06FD);  // controller2 result
                u8 m70 = NES::gMemoryBus.readMemory8(0x0770);  // game mode
                u8 m71 = NES::gMemoryBus.readMemory8(0x0771);
                u8 m72 = NES::gMemoryBus.readMemory8(0x0772);
                u8 m4a = NES::gMemoryBus.readMemory8(0x074A);  // music/ctrl
                u8 m5f = NES::gMemoryBus.readMemory8(0x075F);  // world/level
                u8 m77 = NES::gMemoryBus.readMemory8(0x0777);  // pause
                const PPUState& ps = NES::gPPU.get_state();
                // Additional SMB1 control registers for deep inspection
                u8 p0400 = NES::gMemoryBus.readMemory8(0x0400);  // std joypad1 held
                u8 p0408 = NES::gMemoryBus.readMemory8(0x0408);  // std joypad2 held
                u8 p0410 = NES::gMemoryBus.readMemory8(0x0410);  // std joypad1 edges
                u8 p074a = NES::gMemoryBus.readMemory8(0x074A);  // start/select edge
                // Frame-buffer life-sign: quick checksum over all pixels.
                uint64_t fb_hash = 0;
                for (int i = 0; i < 256 * 240; i++) fb_hash += ps.framebuffer[i];
                // OAM life-sign: count sprites with Y < 0xEF in the game's OAM buffer.
                int oam_count = 0;
                for (int i = 0; i < 256; i += 4) {
                    if (NES::gMemoryBus.readMemory8(0x0200 + i) < 0xEF) oam_count++;
                }
                std::fprintf(stderr,
                    "[GAME] f=%d ctrl=0x%02X ctrl2=0x%02X mode70=0x%02X m71=0x%02X "
                    "m72=0x%02X music4A=0x%02X lvl5F=0x%02X pause77=0x%02X "
                    "p400=0x%02X p408=0x%02X p410=0x%02X p74A=0x%02X "
                    "ppuctrl=0x%02X ppumask=0x%02X line=%d cyc=%d "
                    "reg70F=0x%02X reg74E=0x%02X reg753=0x%02X mario6D=0x%02X fbHash=%lu o=0x%02X\n",
                    frame_count, fc, fd, m70, m71, m72, m4a, m5f, m77,
                    p0400, p0408, p0410, p074a,
                    ps.ctrl, ps.mask, ps.scanline, ps.cycle,
                    NES::gMemoryBus.readMemory8(0x070F),
                    NES::gMemoryBus.readMemory8(0x074E),
                    NES::gMemoryBus.readMemory8(0x0753),
                    NES::gMemoryBus.readMemory8(0x006D),
                    fb_hash, oam_count);
            }

            if (std::getenv("NES_SHOT") && (frame_count % 100 == 0)) {
                char path[128];
                std::snprintf(path, sizeof(path), "/tmp/nes_frame_%04d.ppm", frame_count);
                FILE* f = std::fopen(path, "wb");
                if (f) {
                    std::fprintf(f, "P6\n%d %d\n255\n", 256, 240);
                    const uint32_t* fb = NES::gPPU.get_state().framebuffer;
                    for (int y = 0; y < 240; y++) {
                        for (int x = 0; x < 256; x++) {
                            uint32_t px = fb[y * 256 + x];
                            unsigned char rgb[3] = {
                                (unsigned char)(px >> 16),  // R
                                (unsigned char)(px >> 8),   // G
                                (unsigned char)(px)         // B
                            };
                            std::fwrite(rgb, 1, 3, f);
                        }
                    }
                    std::fclose(f);
                }
            }

            Uint32 frame_time = SDL_GetTicks() - frame_start;
            if (FRAME_DELAY > frame_time)
                SDL_Delay(FRAME_DELAY - frame_time);
        }
    }

    SDL_DestroyRenderer(renderer);
    SDL_DestroyWindow(window);
    SDL_Quit();
    std::cout << "=== Emulator terminated ===" << std::endl;
    return 0;
}