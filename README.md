# NES Emulator

A Linux-focused NES emulator written in C++17 and x86-64 NASM assembly. It
uses SDL2 for windowing and rendering and Dear ImGui for the debugger and user
interface.

## Current status

The emulator includes:

- 6502 CPU execution with assembly opcode and addressing-mode routines
- PPU rendering and register handling
- APU and DMC timing logic
- NROM and MMC3 cartridge mapper support
- Controller input
- Save-state support
- TAS movie playback through FM2 files
- An ImGui debugger interface

Some emulator behavior is still incomplete or approximate. Battery-backed
cartridge saves and SDL audio output are not implemented, MMC3 IRQ handling is
incomplete, and save states do not yet capture every component of the machine.

## Requirements

- Linux
- CMake 3.10 or newer
- A C++17 compiler
- NASM
- SDL2 development files

On Debian or Ubuntu, the dependencies can be installed with:

```bash
sudo apt install build-essential cmake nasm libsdl2-dev
```

## Building

Configure and build a release version from the project directory:

```bash
cmake -S . -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

The executable is created at `build/nes_emulator`.

For a debug build with AddressSanitizer and LeakSanitizer:

```bash
cmake -S . -B build-debug -DCMAKE_BUILD_TYPE=Debug
cmake --build build-debug
```

## Running

Run the executable with a legally obtained NES ROM:

```bash
./build/nes_emulator /path/to/game.nes
```

Alternatively, use `run.sh` to build a release version automatically when
`build-portable/nes_emulator` does not exist:

```bash
./run.sh /path/to/game.nes
```

The graphical launcher files are intended for Linux desktop environments:

- `NES Emulator.sh`
- `NES Emulator.desktop`

This repository does not distribute commercial ROMs. ROM files are ignored by
Git; provide your own legally obtained ROMs locally.

## Controls

The default controller mapping is available in the emulator UI. Controller
input and TAS playback can be selected through the graphical interface.

## Third-party software

This project includes Dear ImGui source code and its SDL2 backends under
`imgui/`. Dear ImGui is distributed under the MIT License or the public-domain
dedication described in its source files. The included third-party copyright
and license notices remain applicable to those files.

## License

Copyright © 2026 Anisia Bantu. All rights reserved.
This repository contains a bachelor’s thesis project.