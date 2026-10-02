#pragma once

// Debugger panel displayed beside the 2x-scaled NES framebuffer.

namespace NES {

// Layout geometry (logical window units).
constexpr int kGameW = 512;  // 2x the NES width
constexpr int kGameH = 480;  // 2x the NES height
constexpr int kPanelW = 460; // Debugger panel width

constexpr int kDebugWindowW = kGameW + kPanelW;
constexpr int kDebugWindowH = kGameH;

// Draws the debugger panel after ImGui::NewFrame().
// Returns true when the user requests termination.
bool drawDebuggerUI();

namespace dbgui {
    struct ImmUI {
        char execAddr[8];
        char memReadAddr[8];
        char memWriteAddr[8];
        char cycleVal[16];
        char opcodeVal[4];
        char memEditAddr[8];
        char memEditVal[8];
        char dumpPath[256];
    };
    extern bool open;   // Whether the debugger panel is visible.
    extern ImmUI imm;
    void toggle();
}

} // namespace NES