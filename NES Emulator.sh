#!/bin/bash
# =============================================================================
#  NES Emulator - double-click launcher
#
#  This script is meant to be double-clicked / run from a file manager so the
#  emulator window opens without having to type any terminal commands.
#
#  What it does:
#    1. Changes into the project directory so ROMs, TAS movies and the UI
#       launcher can find their files relative to the project root.
#    2. Runs the NEWEST built emulator binary it can find.
# =============================================================================

# Resolve the directory this script lives in (handles spaces in the path).
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
cd "$SCRIPT_DIR" || exit 1

# Keep AddressSanitizer quiet about third-party (SDL) memory leaks while still
# trapping real memory errors.
export ASAN_OPTIONS=detect_leaks=0:halt_on_error=1

# Pick the best available binary: newest build first.
CANDIDATES=(
    "$SCRIPT_DIR/build/nes_emulator"
    "$SCRIPT_DIR/.build-check/nes_emulator"
    "$SCRIPT_DIR/nes_emulator"
)

for bin in "${CANDIDATES[@]}"; do
    if [ -x "$bin" ]; then
        exec "$bin" "$@"
    fi
done

# Nothing usable found - tell the user (fancy dialog if available).
if command -v zenity >/dev/null 2>&1; then
    zenity --error \
        --title="NES Emulator" \
        --text="No built emulator binary was found.\n\nFrom a terminal in the project folder, run:\n\n  cmake -S . -B build -DCMAKE_BUILD_TYPE=Release\n  cmake --build build"
else
    echo "Could not find a built emulator binary." >&2
    echo "Build it from this project directory with:" >&2
    echo "  cmake -S . -B build -DCMAKE_BUILD_TYPE=Release" >&2
    echo "  cmake --build build" >&2
fi
exit 1