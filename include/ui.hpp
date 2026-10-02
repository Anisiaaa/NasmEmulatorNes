#pragma once

#include <string>

struct SDL_Window;
struct SDL_Renderer;

namespace NES {

// What the user picked in the launcher UI.
struct LaunchSelection {
    bool start = false;        // true when the user pressed Play (launcher should close)
    int  mode = 0;             // 0 = play normally, 1 = play a TAS movie
    std::string romPath;       // selected .nes
    std::string tasPath;       // selected .fm2 (only used in TAS mode)
};

// Runs the init front-end (ImGui) until the user picks a game and presses
// Play (returns {start=true}) or closes the window (returns {start=false}).
// initialRom/initialTas pre-fill the selection from command line args if any.
LaunchSelection runLauncher(SDL_Window* window, SDL_Renderer* renderer,
                            const std::string& initialRom = "",
                            const std::string& initialTas = "");

// Inspect an FM2 file's header to show rough info (ROM title / frame count).
bool probeTasFile(const std::string& path, std::string& romTitle, int& frameCount);

} // namespace NES