#include "ui.hpp"

#include <SDL2/SDL.h>
#include "imgui.h"
#include "imgui_impl_sdl2.h"
#include "imgui_impl_sdlrenderer2.h"

#include <filesystem>
#include <vector>
#include <string>
#include <fstream>
#include <algorithm>
#include <cctype>
#include <cstdio>

namespace fs = std::filesystem;

namespace NES {

namespace {

std::vector<std::string> scanDir(const std::string& dir, const std::string& ext) {
    std::vector<std::string> out;
    fs::path p(dir);
    if (!fs::exists(p) || !fs::is_directory(p))
        return out;
    try {
        for (const auto& e : fs::directory_iterator(p)) {
            if (fs::is_regular_file(e.path())) {
                std::string ext2 = e.path().extension().string();
                std::transform(ext2.begin(), ext2.end(), ext2.begin(),
                               [](unsigned char c){ return (char)std::tolower(c); });
                if (ext2 == ext)
                    out.push_back(e.path().string());
            }
        }
    } catch (...) {}
    std::sort(out.begin(), out.end());
    return out;
}

std::string basename(const std::string& path) {
    return fs::path(path).filename().string();
}

void applyStyle() {
    ImGuiStyle& s = ImGui::GetStyle();
    ImVec4* c = s.Colors;
    s.WindowRounding = 0.0f;
    s.FrameRounding = 4.0f;
    s.GrabRounding = 4.0f;
    s.ChildRounding = 4.0f;
    s.FramePadding = ImVec2(8, 6);
    s.WindowPadding = ImVec2(10, 10);
    s.ItemSpacing = ImVec2(8, 8);

    ImVec4 bg(0.10f, 0.10f, 0.13f, 1.00f);
    ImVec4 panel(0.14f, 0.14f, 0.18f, 1.00f);
    ImVec4 panel2(0.18f, 0.18f, 0.23f, 1.00f);
    ImVec4 accent(0.85f, 0.25f, 0.20f, 1.00f);   // NES red
    ImVec4 accentHover(0.95f, 0.35f, 0.28f, 1.00f);
    ImVec4 text(0.92f, 0.92f, 0.94f, 1.00f);
    ImVec4 muted(0.55f, 0.55f, 0.62f, 1.00f);

    c[ImGuiCol_WindowBg] = bg;
    c[ImGuiCol_ChildBg] = panel;
    c[ImGuiCol_PopupBg] = panel2;
    c[ImGuiCol_FrameBg] = panel;
    c[ImGuiCol_FrameBgHovered] = panel2;
    c[ImGuiCol_FrameBgActive] = panel2;
    c[ImGuiCol_TitleBg] = panel;
    c[ImGuiCol_TitleBgActive] = panel;
    c[ImGuiCol_Button] = panel;
    c[ImGuiCol_ButtonHovered] = panel2;
    c[ImGuiCol_ButtonActive] = panel2;
    c[ImGuiCol_Header] = panel;
    c[ImGuiCol_HeaderHovered] = panel2;
    c[ImGuiCol_HeaderActive] = panel2;
    c[ImGuiCol_Text] = text;
    c[ImGuiCol_TextDisabled] = muted;
    c[ImGuiCol_Border] = ImVec4(0.24f, 0.24f, 0.30f, 1.00f);
    c[ImGuiCol_Separator] = ImVec4(0.24f, 0.24f, 0.30f, 1.00f);
    c[ImGuiCol_CheckMark] = accent;
    c[ImGuiCol_SliderGrab] = accent;
    c[ImGuiCol_SliderGrabActive] = accent;
    c[ImGuiCol_ScrollbarBg] = bg;
    c[ImGuiCol_ScrollbarGrab] = panel2;
    c[ImGuiCol_ScrollbarGrabHovered] = muted;
    c[ImGuiCol_ScrollbarGrabActive] = muted;
}

} // anonymous namespace

bool probeTasFile(const std::string& path, std::string& romTitle, int& frameCount) {
    romTitle.clear();
    frameCount = 0;
    std::ifstream fin(path);
    if (!fin.is_open()) return false;

    std::string line;
    while (std::getline(fin, line)) {
        if (!line.empty() && line.back() == '\r') line.pop_back();
        if (line.empty()) continue;
        if (line[0] == '|') { frameCount++; continue; }
        const std::string romKey = "romFilename ";
        if (line.compare(0, romKey.size(), romKey) == 0)
            romTitle = line.substr(romKey.size());
    }
    return true;
}

LaunchSelection runLauncher(SDL_Window* window, SDL_Renderer* renderer,
                            const std::string& initialRom,
                            const std::string& initialTas) {
    LaunchSelection sel;

    IMGUI_CHECKVERSION();
    ImGui::CreateContext();
    ImGuiIO& io = ImGui::GetIO();
    io.IniFilename = nullptr;
    applyStyle();

    ImGui_ImplSDL2_InitForSDLRenderer(window, renderer);
    ImGui_ImplSDLRenderer2_Init(renderer);

    // Default scan folders (relative to working directory).
    char romDir[512];
    char tasDir[512];
    std::snprintf(romDir, sizeof(romDir), "roms");
    std::snprintf(tasDir, sizeof(tasDir), "speedruns");

    std::vector<std::string> roms   = scanDir(romDir, ".nes");
    std::vector<std::string> tases  = scanDir(tasDir, ".fm2");

    int activeTab = 0;   // 0 = Play, 1 = TAS, 2 = Debug
    int selRom = -1;
    int selTas = -1;
    int mode = 0;        // 0 = play normally, 1 = play a TAS movie

    for (size_t i = 0; i < roms.size(); ++i)
        if (!initialRom.empty() && roms[i] == initialRom) { selRom = (int)i; break; }
    for (size_t i = 0; i < tases.size(); ++i)
        if (!initialTas.empty() && tases[i] == initialTas) { selTas = (int)i; break; }

    bool done = false;
    while (!done) {
        bool launch = false;
        SDL_Event ev;
        while (SDL_PollEvent(&ev)) {
            ImGui_ImplSDL2_ProcessEvent(&ev);
            if (ev.type == SDL_QUIT) done = true;
        }
        if (done) break;

        ImGui_ImplSDLRenderer2_NewFrame();
        ImGui_ImplSDL2_NewFrame();
        ImGui::NewFrame();

        const ImGuiViewport* vp = ImGui::GetMainViewport();
        ImGui::SetNextWindowPos(vp->WorkPos);
        ImGui::SetNextWindowSize(vp->WorkSize);
        ImGui::Begin("Launcher", nullptr,
                     ImGuiWindowFlags_NoResize | ImGuiWindowFlags_NoMove |
                     ImGuiWindowFlags_NoCollapse | ImGuiWindowFlags_NoTitleBar |
                     ImGuiWindowFlags_NoSavedSettings);

        ImGui::BeginChild("sidebar", ImVec2(220.0f, 0), true);
        ImGui::TextColored(ImVec4(0.85f,0.25f,0.20f,1.0f), "NES");
        ImGui::TextColored(ImVec4(0.92f,0.92f,0.94f,1.0f), "Emulator");
        ImGui::Separator();
        ImGui::Spacing();

        auto tabButton = [&](int id, const char* label) {
            if (activeTab == id) {
                ImGui::PushStyleColor(ImGuiCol_Button, ImVec4(0.85f,0.25f,0.20f,1.0f));
                ImGui::PushStyleColor(ImGuiCol_ButtonHovered, ImVec4(0.90f,0.30f,0.24f,1.0f));
                if (ImGui::Button(label, ImVec2(-1.0f, 40.0f))) activeTab = id;
                ImGui::PopStyleColor(2);
            } else {
                if (ImGui::Button(label, ImVec2(-1.0f, 40.0f))) activeTab = id;
            }
        };
        tabButton(0, "  Play");
        tabButton(1, "  TAS");
        tabButton(2, "  Debug");
        ImGui::EndChild();

        ImGui::SameLine();

        const ImVec4 accent(0.85f, 0.25f, 0.20f, 1.0f);
        ImGui::BeginChild("content", ImVec2(0, 0), true);

        if (activeTab == 0) {
            ImGui::TextColored(ImVec4(0.92f,0.92f,0.94f,1.0f), "Play");
            ImGui::TextDisabled("Select a game to run, then press Start.");
            ImGui::Separator();

            ImGui::TextColored(accent, "ROM");
            ImGui::SetNextItemWidth(-86.0f);
            ImGui::InputText("##romdir", romDir, sizeof(romDir));
            ImGui::SameLine();
            if (ImGui::Button("Scan")) { roms = scanDir(romDir, ".nes"); selRom = -1; }
            ImGui::BeginChild("romlist", ImVec2(0, 170), true);
            if (roms.empty()) ImGui::TextDisabled("No .nes files found in '%s'", romDir);
            for (int i = 0; i < (int)roms.size(); ++i) {
                if (ImGui::Selectable(basename(roms[(size_t)i]).c_str(), selRom == i))
                    selRom = i;
            }
            ImGui::EndChild();

            ImGui::Spacing();
            ImGui::Text("Mode");
            ImGui::RadioButton("Play normally", &mode, 0);
            ImGui::RadioButton("View a TAS movie", &mode, 1);

            if (mode == 1) {
                ImGui::Spacing();
                ImGui::Separator();
                ImGui::TextColored(accent, "TAS movie");
                ImGui::SetNextItemWidth(-86.0f);
                ImGui::InputText("##tasdir", tasDir, sizeof(tasDir));
                ImGui::SameLine();
                if (ImGui::Button("Scan##t")) { tases = scanDir(tasDir, ".fm2"); selTas = -1; }
                ImGui::BeginChild("taslist", ImVec2(0, 170), true);
                if (tases.empty()) ImGui::TextDisabled("No .fm2 files found in '%s'", tasDir);
                for (int i = 0; i < (int)tases.size(); ++i) {
                    if (ImGui::Selectable(basename(tases[(size_t)i]).c_str(), selTas == i))
                        selTas = i;
                }
                ImGui::EndChild();
            }

            ImGui::Spacing();
            const bool canStart = (selRom >= 0) && (mode == 0 || selTas >= 0);
            if (!canStart) ImGui::PushStyleVar(ImGuiStyleVar_Alpha, 0.4f);
            if (ImGui::Button("Start Playback", ImVec2(-1.0f, 50.0f)) && canStart) {
                sel.mode    = mode;
                sel.romPath = roms[(size_t)selRom];
                sel.tasPath = (mode == 1) ? tases[(size_t)selTas] : "";
                sel.start   = true;
                launch = true;
            }
            if (!canStart) ImGui::PopStyleVar();
        }
        if (activeTab == 1) {
            ImGui::TextColored(ImVec4(0.92f,0.92f,0.94f,1.0f), "TAS");
            ImGui::TextDisabled("Pick a TAS (tool-assisted speedrun) movie to view.");
            ImGui::Separator();

            ImGui::TextColored(accent, "TAS movie");
            ImGui::SetNextItemWidth(-86.0f);
            ImGui::InputText("##tasdir2", tasDir, sizeof(tasDir));
            ImGui::SameLine();
            if (ImGui::Button("Scan##t2")) { tases = scanDir(tasDir, ".fm2"); selTas = -1; }
            ImGui::BeginChild("taslist2", ImVec2(0, 200), true);
            if (tases.empty()) ImGui::TextDisabled("No .fm2 files found in '%s'", tasDir);
            for (int i = 0; i < (int)tases.size(); ++i) {
                if (ImGui::Selectable(basename(tases[(size_t)i]).c_str(), selTas == i))
                    selTas = i;
            }
            ImGui::EndChild();

            ImGui::Spacing();
            if (selTas >= 0) {
                std::string romTitle;
                int frames = 0;
                probeTasFile(tases[(size_t)selTas], romTitle, frames);
                ImGui::Text("File   : %s", basename(tases[(size_t)selTas]).c_str());
                ImGui::Text("Frames : %d", frames);
                if (frames > 0) ImGui::Text("Time   : %.1fs", frames / 60.0);
                if (!romTitle.empty()) ImGui::Text("Recorded with ROM: %s", romTitle.c_str());
                ImGui::Spacing();
            }

            const bool canTas = (selTas >= 0);
            if (!canTas) ImGui::PushStyleVar(ImGuiStyleVar_Alpha, 0.4f);
            if (ImGui::Button("Play TAS", ImVec2(-1.0f, 50.0f)) && canTas) {
                sel.mode    = 1;
                sel.tasPath = tases[(size_t)selTas];
                sel.romPath = (selRom >= 0) ? roms[(size_t)selRom] : "";
                sel.start   = true;
                launch = true;
            }
            if (!canTas) ImGui::PopStyleVar();
        }

        if (activeTab == 2) {
            ImGui::TextColored(ImVec4(0.92f,0.92f,0.94f,1.0f), "Debug");
            ImGui::TextDisabled("This panel will hold the debug view.");
            ImGui::Separator();
            ImGui::TextWrapped("Coming soon: CPU registers, PPU state and memory inspector.");
        }
        ImGui::EndChild();

        ImGui::End(); // Launcher window

        ImGui::Render();
        SDL_SetRenderDrawColor(renderer, 26, 26, 34, 255);
        SDL_RenderClear(renderer);
        ImGui_ImplSDLRenderer2_RenderDrawData(ImGui::GetDrawData(), renderer);
        SDL_RenderPresent(renderer);

        if (launch) done = true;
    } // while (!done)

    ImGui_ImplSDLRenderer2_Shutdown();
    ImGui_ImplSDL2_Shutdown();
    ImGui::DestroyContext();
    return sel;
}

} // namespace NES