cmake_minimum_required(VERSION 3.10)
project(SuperMarioNES LANGUAGES CXX ASM_NASM)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

if(NOT CMAKE_BUILD_TYPE)
    set(CMAKE_BUILD_TYPE "Debug")
endif()
if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    message(STATUS "Enabling AddressSanitizer + LeakSanitizer for debug build")
    set(CMAKE_CXX_FLAGS_DEBUG "${CMAKE_CXX_FLAGS_DEBUG} -g -O0 -fsanitize=address,leak -fno-omit-frame-pointer")
    set(CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -fsanitize=address,leak")
    set(CMAKE_C_FLAGS_DEBUG "${CMAKE_C_FLAGS_DEBUG} -fsanitize=address,leak")
endif()


set(CMAKE_ASM_NASM_FLAGS "-f elf64 -I\"${CMAKE_SOURCE_DIR}/asm/opcodes/\"")

find_package(SDL2 REQUIRED)

# Include directories
include_directories(${CMAKE_SOURCE_DIR}/include)
include_directories(${CMAKE_SOURCE_DIR}/asm)
include_directories(${SDL2_INCLUDE_DIRS})
include_directories(${CMAKE_SOURCE_DIR}/imgui)
include_directories(${CMAKE_SOURCE_DIR}/imgui/backends)

# Gather source files
file(GLOB_RECURSE SRC_FILES "src/*.cpp")
file(GLOB_RECURSE ASM_FILES "asm/*.asm" "src/*.asm")


# Dear ImGui sources (only sdlrenderer2 + platform)
file(GLOB IMGUI_SOURCES
    imgui/*.cpp
    imgui/backends/imgui_impl_sdl2.cpp
    imgui/backends/imgui_impl_sdlrenderer2.cpp
)

list(FILTER SRC_FILES EXCLUDE REGEX ".*test.*")
list(FILTER ASM_FILES EXCLUDE REGEX ".*test.*")

# Add ALL sources to the executable
add_executable(nes_emulator ${SRC_FILES} ${ASM_FILES} ${IMGUI_SOURCES})

# Disable Linux PIE security for raw assembly
set_target_properties(nes_emulator PROPERTIES POSITION_INDEPENDENT_CODE OFF)
set(CMAKE_EXE_LINKER_FLAGS "-no-pie")

# Link libraries (OpenGL not needed with SDL_Renderer2)
target_link_libraries(nes_emulator ${SDL2_LIBRARIES} pthread)