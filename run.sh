#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR" || exit 1
export ASAN_OPTIONS=detect_leaks=0:halt_on_error=1
unset NES_DEBUG_INPUT_FILE

if [ -x "$SCRIPT_DIR/build-portable/nes_emulator" ]; then
    exec "$SCRIPT_DIR/build-portable/nes_emulator" "$@"
fi

if ! command -v cmake >/dev/null 2>&1; then
    echo "Could not find a built emulator binary, and cmake is not installed." >&2
    echo "Install cmake and SDL2 development files, then run this script again." >&2
    exit 1
fi

echo "Building the emulator from this recovery directory..." >&2
cmake -S "$SCRIPT_DIR" -B "$SCRIPT_DIR/build-portable" -DCMAKE_BUILD_TYPE=Release || exit 1
cmake --build "$SCRIPT_DIR/build-portable" -- -j2 || exit 1
exec "$SCRIPT_DIR/build-portable/nes_emulator" "$@"
