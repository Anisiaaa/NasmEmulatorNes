#pragma once

#include <cstdint>
#include <fstream>
#include <string>
#include <vector>

namespace NES {

class TASMovie {
public:
    bool loadFromFile(const std::string& filename) {
        std::ifstream file(filename);
        if (!file)
            return false;

        frames_.clear();
        rom_filename_.clear();
        std::string line;
        while (std::getline(file, line)) {
            if (line.rfind("romFilename ", 0) == 0) {
                rom_filename_ = line.substr(12);
                continue;
            }
            if (line.rfind("|", 0) != 0)
                continue;

            const std::size_t first = line.find('|', 1);
            if (first == std::string::npos)
                continue;
            const std::size_t second = line.find('|', first + 1);
            if (second == std::string::npos)
                continue;

            const std::string buttons = line.substr(first + 1, second - first - 1);
            uint8_t state = 0;
            for (char button : buttons) {
                switch (button) {
                    case 'R': state |= 0x01; break;
                    case 'L': state |= 0x02; break;
                    case 'D': state |= 0x04; break;
                    case 'U': state |= 0x08; break;
                    case 'S': state |= 0x10; break;
                    case 'T': state |= 0x20; break;
                    case 'B': state |= 0x40; break;
                    case 'A': state |= 0x80; break;
                    default: break;
                }
            }
            frames_.push_back(state);
        }
        return !frames_.empty();
    }

    bool isLoaded() const { return !frames_.empty(); }
    std::size_t totalFrames() const { return frames_.size(); }
    const std::string& romFilename() const { return rom_filename_; }

    bool getFrameButtons(std::size_t frame, uint8_t& buttons) const {
        if (frame >= frames_.size())
            return false;
        buttons = frames_[frame];
        return true;
    }

    bool shouldReset(std::size_t) const { return false; }

private:
    std::vector<uint8_t> frames_;
    std::string rom_filename_;
};

} // namespace NES
