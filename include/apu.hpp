#pragma once

#include "types.hpp"
#include <cstddef>  // For offsetof

namespace NES {

// Forward declaration
class MemoryBus;


// DMC instruction phase — provided by the emulation loop
// so APU_Interface can compute the correct steal duration.
//
// In this implementation, each instruction is classified into one phase based
// on its opcode, and that phase applies to all cycles of the instruction.
// This is a simplification; in reality, instruction phases vary cycle-by-cycle.
// For example, a RMW instruction performs read operations in early cycles and
// write operations in later cycles; this uniform
// phase classification provides reasonable timing approximation.
//
enum class InstructionPhase : u8 {
    Read       = 0,  // CPU is performing a read in current step → steal 1
    Write      = 1,  // CPU is performing a write                → steal 2
    RMW        = 2,  // CPU is in the write half of a RMW        → steal 4
    OAMDMALast = 3   // Last cycle of OAM DMA transfer           → steal 1
};


// FrameCounterState - Memory layout for assembly access via apu_timing.asm
// 
// This struct is accessed directly by x64 assembly functions using System V ABI
// (pointer passed in rdi). All fields use fixed-width types for predictable
// layout and offsets.
//
// Byte Offsets (for assembly access):
//   +0  (0x00): u8  mode5step       - 4-step mode (0) or 5-step mode (1)
//   +1  (0x01): u8  irqInhibit      - IRQ inhibit flag (bit 6 of $4017)
//   +2  (0x02): u8  frameIrqFlag    - Pending Frame IRQ flag (bit 6 of $4015)
//   +3  (0x03): u8  pendingReset    - Jitter-delayed reset queued flag
//   +4  (0x04): u32 pad1            - Padding for alignment
//   +8  (0x08): u64 resetAtCycle    - Absolute CPU cycle for sequencer reset
//   +16 (0x10): u64 divider         - Cycle offset within current sequence
//   +24 (0x18): u64 pad2            - Padding to 32 bytes
//
// Total Size: 32 bytes
//
// Assembly module: src/apu/apu_timing.asm
//
struct FrameCounterState {
    u8  mode5step;          // +0:  false = 4-step, true = 5-step
    u8  irqInhibit;         // +1:  IRQ inhibit flag (bit 6 of $4017)
    u8  frameIrqFlag;       // +2:  Pending frame IRQ flag (bit 6 of $4015)
    u8  pendingReset;       // +3:  Jitter-delayed reset queued
    u32 pad1;               // +4:  Padding for alignment
    u64 resetAtCycle;       // +8:  Absolute cycle for sequencer reset
    u64 divider;            // +16: Cycle offset within current sequence
    u64 pad2;               // +24: Padding to 32 bytes
} __attribute__((packed));

// Static assertions to validate struct layout matches assembly expectations
static_assert(sizeof(FrameCounterState) == 32, "FrameCounterState size mismatch - assembly expects 32 bytes");
static_assert(offsetof(FrameCounterState, mode5step) == 0, "FrameCounterState::mode5step offset mismatch");
static_assert(offsetof(FrameCounterState, irqInhibit) == 1, "FrameCounterState::irqInhibit offset mismatch");
static_assert(offsetof(FrameCounterState, frameIrqFlag) == 2, "FrameCounterState::frameIrqFlag offset mismatch");
static_assert(offsetof(FrameCounterState, pendingReset) == 3, "FrameCounterState::pendingReset offset mismatch");
static_assert(offsetof(FrameCounterState, pad1) == 4, "FrameCounterState::pad1 offset mismatch");
static_assert(offsetof(FrameCounterState, resetAtCycle) == 8, "FrameCounterState::resetAtCycle offset mismatch");
static_assert(offsetof(FrameCounterState, divider) == 16, "FrameCounterState::divider offset mismatch");
static_assert(offsetof(FrameCounterState, pad2) == 24, "FrameCounterState::pad2 offset mismatch");


// DMCState structure for assembly access via apu_timing.asm / dmc_timing.asm
// Total size: 64 bytes
// Memory layout with byte offsets for assembly:
//   +0   u8  enabled            - bit 4 of $4015 (DMC enabled)
//   +1   u8  irqEnable          - bit 7 of $4010 (DMC IRQ enable)
//   +2   u8  loopFlag           - bit 6 of $4010 (loop sample)
//   +3   u8  rateIndex          - bits 3-0 of $4010 (rate table index)
//   +4   u8  lengthCounter      - stub (always 0, audio out of scope)
//   +5   u8  sampleBufferEmpty  - fetch trigger flag
//   +6   u8  dmcIrqFlag         - bit 7 of $4015 (DMC IRQ pending)
//   +7   u8  pad1               - padding for alignment
//   +8   u16 sampleStartAddr    - 0xC000 + ($4012 * 64)
//   +10  u16 sampleLength       - ($4013 * 16) + 1
//   +12  u16 currentAddr        - current DMA fetch address (wraps $FFFF → $8000)
//   +14  u16 bytesRemaining     - bytes left in sample
//   +16  u32 rateTimer          - countdown timer for DMC fetch rate
//   +20  u32 pad2[11]           - padding to 64 bytes total
struct DMCState {
    u8  enabled;            // +0
    u8  irqEnable;          // +1
    u8  loopFlag;           // +2
    u8  rateIndex;          // +3
    u8  lengthCounter;      // +4
    u8  sampleBufferEmpty;  // +5
    u8  dmcIrqFlag;         // +6
    u8  pad1;               // +7
    u16 sampleStartAddr;    // +8
    u16 sampleLength;       // +10
    u16 currentAddr;        // +12
    u16 bytesRemaining;     // +14
    u32 rateTimer;          // +16
    u32 pad2[11];           // +20 - padding to align struct to 64 bytes
} __attribute__((packed));

// Static assertions to validate struct layout matches assembly expectations
static_assert(sizeof(DMCState) == 64, "DMCState size mismatch - assembly expects 64 bytes");
static_assert(offsetof(DMCState, enabled) == 0, "DMCState::enabled offset mismatch");
static_assert(offsetof(DMCState, irqEnable) == 1, "DMCState::irqEnable offset mismatch");
static_assert(offsetof(DMCState, loopFlag) == 2, "DMCState::loopFlag offset mismatch");
static_assert(offsetof(DMCState, rateIndex) == 3, "DMCState::rateIndex offset mismatch");
static_assert(offsetof(DMCState, lengthCounter) == 4, "DMCState::lengthCounter offset mismatch");
static_assert(offsetof(DMCState, sampleBufferEmpty) == 5, "DMCState::sampleBufferEmpty offset mismatch");
static_assert(offsetof(DMCState, dmcIrqFlag) == 6, "DMCState::dmcIrqFlag offset mismatch");
static_assert(offsetof(DMCState, pad1) == 7, "DMCState::pad1 offset mismatch");
static_assert(offsetof(DMCState, sampleStartAddr) == 8, "DMCState::sampleStartAddr offset mismatch");
static_assert(offsetof(DMCState, sampleLength) == 10, "DMCState::sampleLength offset mismatch");
static_assert(offsetof(DMCState, currentAddr) == 12, "DMCState::currentAddr offset mismatch");
static_assert(offsetof(DMCState, bytesRemaining) == 14, "DMCState::bytesRemaining offset mismatch");
static_assert(offsetof(DMCState, rateTimer) == 16, "DMCState::rateTimer offset mismatch");
static_assert(offsetof(DMCState, pad2) == 20, "DMCState::pad2 offset mismatch");

// Assembly Function Forward Declarations

// Forward declarations for assembly timing functions.
// These functions are implemented in x64 assembly (NASM, Intel syntax)
// and follow the System V ABI calling convention.
extern "C" {
    // Frame Counter timing functions (src/apu/apu_timing.asm)
    u8   frameCounterTick(struct FrameCounterState* state, u64 currentCycle);
    void frameCounterWrite4017(struct FrameCounterState* state, u8 value, u64 currentCycle);
    void frameCounterReset(struct FrameCounterState* state, u8 hard);
    
    // DMC timing functions (src/apu/dmc_timing.asm)
    u8   dmcTimingTick(struct DMCState* state, u8 instructionPhase, u64 currentCycle);
    void dmcTimingReset(struct DMCState* state, u8 hard);
}

// APU register interface and timing coordination.
class APU_Interface {
public:
    // Constructor - initializes APU with reference to memory bus
    explicit APU_Interface(MemoryBus& bus);

    // Called once per CPU cycle by the emulation loop.
    // Returns the number of cycles the CPU should stall (0, 1, 2, or 4).
    // The 'phase' parameter indicates the current CPU instruction phase
    // for correct DMC cycle steal duration calculation.
    u8 tick(InstructionPhase phase = InstructionPhase::Read);

    // Register access — called by MemoryBus::readAPURegister / writeAPURegister.
    u8   read(u16 address);
    void write(u16 address, u8 value);

    // Reset handling.
    // hard=true  → full power-on reset ($4015=$00, $4017=$00, all state cleared)
    // hard=false → soft CPU reset ($4015=$00, $4017 mode/inhibit preserved, timer continues)
    void reset(bool hard);
    
    // Power-on initialization - writes $4017=$00 with immediate reset (no jitter)
    // This is called at cycle 0 by the test runner to simulate hardware power-on behavior
    void powerOnInit();

    // IRQ line state — polled by the CPU interrupt handler.
    // Returns true if either Frame Counter IRQ or DMC IRQ is pending.
    bool irqPending() const;

private:
    // Reference to MemoryBus for getCycleCounter() access
    MemoryBus& bus_;

    // Frame Counter state - passed to assembly functions via pointer
    FrameCounterState fc_;

    // DMC state - passed to assembly functions via pointer
    DMCState dmc_;

    // Length Counter implementation for pulse1, pulse2, triangle, noise
    // Tracks length counter values and halt flags per NES APU specification
    // 
    //   - 'enabled' is controlled by $4015 write (bits 0-3)
    //   - 'lengthActive' tracks whether counter > 0
    //   - When counter reaches 0, set lengthActive = false but keep enabled unchanged
    //
    // Audio output should check both: if (enabled && lengthActive) { generate audio }
    struct LengthCounter { 
        bool enabled = false;      // Channel enabled via $4015
        bool lengthActive = false; // True when counter > 0 (separate from enabled)
        u8 counter = 0;            // Length counter value (0-255)
        bool halt = false;         // Halt flag from channel control register
    };
    
    LengthCounter pulse1_;
    LengthCounter pulse2_;
    LengthCounter triangle_;
    LengthCounter noise_;

    // Open-bus value — last byte placed on the CPU data bus.
    // Used for reads of write-only or unreadable APU registers.
    u8 openBus_ = 0;
    
    // Frame Counter step tracking for length counter clocking
    u64 lastQuarterFrame_ = 0;
    u64 lastHalfFrame_ = 0;
    
    // Frame step tracking state for event detection (Task 1.1)
    u64 lastDivider_ = 0;  // Previous divider value for edge detection
    
    // Frame step boundary constants in CPU cycles (Task 1.1)
    // The Frame Counter divider tracks CPU cycles directly
    static constexpr u64 STEP_7457 = 7457;    // Quarter-frame
    static constexpr u64 STEP_14913 = 14913;  // Half-frame + quarter
    static constexpr u64 STEP_22371 = 22371;  // Quarter-frame
    static constexpr u64 STEP_29829 = 29829;  // Half-frame + quarter + IRQ (4-step)
    static constexpr u64 STEP_37281 = 37281;  // Half-frame + quarter (5-step)

    // Private register dispatch helpers
    u8   read4015();                           // $4015 status register (read-clear side effect)
    void write4015(u8 value);                  // $4015 channel enable
    void write4017(u8 value, u64 currentCycle); // $4017 frame counter control
    void writeDMC(u16 address, u8 value);      // $4010-$4013 DMC registers
    void writePulse1(u16 address, u8 value);   // $4000-$4003 Pulse 1 registers
    void writePulse2(u16 address, u8 value);   // $4004-$4007 Pulse 2 registers
    void writeTriangle(u16 address, u8 value); // $4008-$400B Triangle registers
    void writeNoise(u16 address, u8 value);    // $400C-$400F Noise registers
    
    // Length counter helpers
    void clockLengthCounters();                // Clock all length counters (half-frame)
    u8 getLengthValue(u8 index);               // Get length from length table
    
protected:
    // Frame step detection helpers (Task 1.3, 1.4) - protected for testing
    bool detectQuarterFrame(u64 prev, u64 curr, bool mode5step);  // Detect quarter-frame boundary crossing
    bool detectHalfFrame(u64 prev, u64 curr, bool mode5step);     // Detect half-frame boundary crossing
};

} // namespace NES