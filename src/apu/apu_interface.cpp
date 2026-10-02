#include "apu.hpp"
#include "memory_system.hpp"
#include <cassert>
#include <cstring>
#include <iostream>

namespace NES {


APU_Interface::APU_Interface(MemoryBus& bus)
    : bus_(bus), lastQuarterFrame_(0), lastHalfFrame_(0), lastDivider_(0)
{
    reset(true);  // Initialize with power-on reset
}

void APU_Interface::reset(bool hard) {
    if (hard) {
        // Power-on reset: call assembly reset functions with hard=1
        frameCounterReset(&fc_, 1);
        dmcTimingReset(&dmc_, 1);
        
        // Zero all length counters
        pulse1_ = LengthCounter();
        pulse2_ = LengthCounter();
        triangle_ = LengthCounter();
        noise_ = LengthCounter();
        
        lastQuarterFrame_ = 0;
        lastHalfFrame_ = 0;
        lastDivider_ = 0;
        
        // Clear open bus
        openBus_ = 0;
        
        // Note: Power-on $4017 write is now handled externally by the test runner
        // This allows test ROMs to detect the write event
    } else {
        // Soft CPU reset: call assembly reset functions with hard=0
        // This preserves fc_.mode5step and fc_.irqInhibit but clears frameIrqFlag
        frameCounterReset(&fc_, 0);
        dmcTimingReset(&dmc_, 0);
        
        // Simulate $4015 = $00 write: disable all channels
        pulse1_.enabled = false;
        pulse2_.enabled = false;
        triangle_.enabled = false;
        noise_.enabled = false;
        
        // Clear open bus
        openBus_ = 0;
    }
}

void APU_Interface::powerOnInit() {
    // Power-on $4017 write behavior: hardware writes $00 with immediate reset (no jitter)
    // This is different from runtime CPU writes which have 3-4 cycle jitter delay
    //
    // At power-on (cycle 0):
    // - mode5step = 0 (4-step mode, from bit 7 of $00)
    // - irqInhibit = 0 (IRQ enabled, from bit 6 of $00)
    // - frameIrqFlag = 0
    // - divider = 0 (reset immediately, no pending reset)
    // - pendingReset = 0
    
    // Set mode and inhibit flags based on $00 value
    fc_.mode5step = 0;
    fc_.irqInhibit = 0;
    fc_.frameIrqFlag = 0;
    
    // Reset divider immediately (no jitter at power-on)
    fc_.pendingReset = 0;
    fc_.resetAtCycle = 0;
    fc_.divider = 0;
}


void APU_Interface::write(u16 address, u8 value) {
    // Update open bus before any dispatch
    openBus_ = value;
    
    // Route based on address
    if (address == 0x4015) {
        // $4015 - Status register / channel enable
        write4015(value);
    } 
    else if (address == 0x4017) {
        // $4017 - Frame counter control
        write4017(value, bus_.getCycleCounter());
    } 
    else if (address >= 0x4010 && address <= 0x4013) {
        // $4010-$4013 - DMC control registers
        writeDMC(address, value);
    }
    else if (address >= 0x4000 && address <= 0x4003) {
        // $4000-$4003 - Pulse channel 1
        writePulse1(address, value);
    }
    else if (address >= 0x4004 && address <= 0x4007) {
        // $4004-$4007 - Pulse channel 2
        writePulse2(address, value);
    }
    else if (address >= 0x4008 && address <= 0x400B) {
        // $4008-$400B - Triangle channel
        writeTriangle(address, value);
    }
    else if (address >= 0x400C && address <= 0x400F) {
        // $400C-$400F - Noise channel
        writeNoise(address, value);
    }
}


u8 APU_Interface::read(u16 address) {
    u8 result = openBus_;  // Default: return open bus value
    
    if (address == 0x4015) {
        // $4015 - Status register (read-clear side effect)
        result = read4015();
    }
    // All other addresses in $4000-$4017 return open bus
    
    // Update open bus with result
    openBus_ = result;
    
    return result;
}


u8 APU_Interface::read4015() {
    // Build status byte:
    // Bit 7: DMC IRQ flag
    // Bit 6: Frame IRQ flag (will be cleared after this read)
    // Bit 5: Reserved (0)
    // Bit 4: DMC active (bytes remaining > 0)
    // Bit 3: Noise length counter active (counter > 0)
    // Bit 2: Triangle length counter active (counter > 0)
    // Bit 1: Pulse 2 length counter active (counter > 0)
    // Bit 0: Pulse 1 length counter active (counter > 0)
    
    u8 status = 0;
    
    // Bit 7: DMC IRQ flag
    if (dmc_.dmcIrqFlag) {
        status |= 0x80;
    }
    
    // Bit 6: Frame IRQ flag (snapshot before clear)
    if (fc_.frameIrqFlag) {
        status |= 0x40;
    }
    
    // Bit 4: DMC active
    if (dmc_.bytesRemaining > 0) {
        status |= 0x10;
    }
    
    // Bits 3-0: Length counter active flags (counter > 0, not just enabled)
    if (noise_.counter > 0)    status |= 0x08;
    if (triangle_.counter > 0) status |= 0x04;
    if (pulse2_.counter > 0)   status |= 0x02;
    if (pulse1_.counter > 0)   status |= 0x01;
    
    // Read-clear side effect: clear Frame IRQ flag
    // (DMC IRQ flag is NOT cleared on read)
    fc_.frameIrqFlag = 0;
    
    return status;
}

void APU_Interface::write4015(u8 value) {
    // Set channel enable bits based on value
    pulse1_.enabled   = (value & 0x01) != 0;
    pulse2_.enabled   = (value & 0x02) != 0;
    triangle_.enabled = (value & 0x04) != 0;
    noise_.enabled    = (value & 0x08) != 0;
    
    // This prevents the counter from being non-zero while the channel is disabled
    if (!pulse1_.enabled) {
        pulse1_.counter = 0;
        pulse1_.lengthActive = false;
    }
    if (!pulse2_.enabled) {
        pulse2_.counter = 0;
        pulse2_.lengthActive = false;
    }
    if (!triangle_.enabled) {
        triangle_.counter = 0;
        triangle_.lengthActive = false;
    }
    if (!noise_.enabled) {
        noise_.counter = 0;
        noise_.lengthActive = false;
    }
    
    // Bit 4: DMC enable
    dmc_.enabled = (value & 0x10) != 0;
    
    // Clear DMC IRQ flag whenever bit 4 is written as 0
    if (!(value & 0x10)) {
        dmc_.dmcIrqFlag = 0;
    }
    
    // If DMC is being enabled and bytes remaining is 0, restart the sample
    if (dmc_.enabled && dmc_.bytesRemaining == 0) {
        dmc_.currentAddr = dmc_.sampleStartAddr;
        dmc_.bytesRemaining = dmc_.sampleLength;
        dmc_.sampleBufferEmpty = 1;  // Trigger sample fetch
    }
}

// $4017 Frame Counter Control Implementation

void APU_Interface::write4017(u8 value, u64 currentCycle) {
    // Delegate to assembly function
    // Assembly handles:
    // - Mode selection (bit 7)
    // - IRQ inhibit (bit 6)
    // - Jitter-adjusted reset scheduling
    // - Immediate flag clearing when inhibit set or 5-step mode selected
    frameCounterWrite4017(&fc_, value, currentCycle);
}

// DMC Register Implementation ($4010-$4013)

// NTSC DMC rate table (matches assembly dmc_rate_table_ntsc)
static const u32 DMC_RATE_TABLE_NTSC[16] = {
    428, 380, 340, 320, 286, 254, 226, 214,
    190, 160, 142, 128, 106,  84,  72,  54
};

// NES Length Counter lookup table (32 values)
// Index comes from bits 7-3 of channel control register (e.g., $4003, $4007, $400B, $400F)
static const u8 LENGTH_COUNTER_TABLE[32] = {
    10, 254, 20,  2, 40,  4, 80,  6,
    160,  8, 60, 10, 14, 12, 26, 14,
     12, 16, 24, 18, 48, 20, 96, 22,
    192, 24, 72, 26, 16, 28, 32, 30
};

u8 APU_Interface::getLengthValue(u8 index) {
    if (index >= 32) {
        #ifndef NDEBUG
        std::cerr << "Warning: Invalid length counter index: " << static_cast<int>(index) << std::endl;
        #endif
        assert(index < 32 && "Invalid length counter index");
        return 0;
    }
    return LENGTH_COUNTER_TABLE[index];
}

void APU_Interface::clockLengthCounters() {
    // Decrement length counters if enabled and not halted
    // When counter reaches 0, set lengthActive = false but keep enabled unchanged
    
    if (pulse1_.enabled && !pulse1_.halt && pulse1_.counter > 0) {
        pulse1_.counter--;
        if (pulse1_.counter == 0) {
            pulse1_.lengthActive = false;
        }
    }
    
    if (pulse2_.enabled && !pulse2_.halt && pulse2_.counter > 0) {
        pulse2_.counter--;
        if (pulse2_.counter == 0) {
            pulse2_.lengthActive = false;
        }
    }
    
    if (triangle_.enabled && !triangle_.halt && triangle_.counter > 0) {
        triangle_.counter--;
        if (triangle_.counter == 0) {
            triangle_.lengthActive = false;
        }
    }
    
    if (noise_.enabled && !noise_.halt && noise_.counter > 0) {
        noise_.counter--;
        if (noise_.counter == 0) {
            noise_.lengthActive = false;
        }
    }
}

void APU_Interface::writeDMC(u16 address, u8 value) {
    switch (address) {
        case 0x4010: {
            // $4010: DMC control
            // Bit 7: IRQ enable
            // Bit 6: Loop flag
            // Bits 3-0: Rate index (0-15)
            
            dmc_.irqEnable = (value & 0x80) != 0;
            // This prevents spurious IRQs after IRQ enable is disabled
            if (!dmc_.irqEnable) {
                dmc_.dmcIrqFlag = 0;
            }
            dmc_.loopFlag  = (value & 0x40) != 0;
            dmc_.rateIndex = value & 0x0F;
            
            // The rate timer is reloaded IMMEDIATELY when $4010 is written.
            // This affects the timing of the next DMC sample fetch.
            // On hardware, writing to $4010 resets the internal rate countdown
            // to the new rate value from DMC_RATE_TABLE_NTSC, regardless of
            // the timer's previous state.
            dmc_.rateTimer = DMC_RATE_TABLE_NTSC[dmc_.rateIndex];
            
            break;
        }
        
        case 0x4012: {
            // $4012: DMC sample address
            // Sample start address = 0xC000 + (value * 64)
            dmc_.sampleStartAddr = 0xC000 + (static_cast<u16>(value) * 64);
            break;
        }
        
        case 0x4013: {
            // $4013: DMC sample length
            // Sample length = (value * 16) + 1
            dmc_.sampleLength = (static_cast<u16>(value) * 16) + 1;
            break;
        }
        
        case 0x4011: {
            // $4011: DAC / PCM output level
            // Audio output is out of scope - accept silently
            // (no side effects on timing state)
            break;
        }
    }
}

// Channel Register Implementations

void APU_Interface::writePulse1(u16 address, u8 value) {
    switch (address) {
        case 0x4000:
            // Duty, length counter halt, constant volume, volume/envelope
            pulse1_.halt = (value & 0x20) != 0;
            break;
        case 0x4001:
            // Sweep unit
            break;
        case 0x4002:
            // Timer low
            break;
        case 0x4003:
            // Length counter load, timer high
            if (pulse1_.enabled) {
                u8 lengthIndex = (value >> 3);
                pulse1_.counter = getLengthValue(lengthIndex);
                pulse1_.lengthActive = true;
            }
            break;
    }
}

void APU_Interface::writePulse2(u16 address, u8 value) {
    switch (address) {
        case 0x4004:
            // Duty, length counter halt, constant volume, volume/envelope
            pulse2_.halt = (value & 0x20) != 0;
            break;
        case 0x4005:
            // Sweep unit
            break;
        case 0x4006:
            // Timer low
            break;
        case 0x4007:
            // Length counter load, timer high
            if (pulse2_.enabled) {
                u8 lengthIndex = (value >> 3);
                pulse2_.counter = getLengthValue(lengthIndex);
                pulse2_.lengthActive = true;
            }
            break;
    }
}

void APU_Interface::writeTriangle(u16 address, u8 value) {
    switch (address) {
        case 0x4008:
            // Length counter halt / linear counter control, linear counter load
            triangle_.halt = (value & 0x80) != 0;
            break;
        case 0x4009:
            // Unused
            break;
        case 0x400A:
            // Timer low
            break;
        case 0x400B:
            // Length counter load, timer high
            if (triangle_.enabled) {
                u8 lengthIndex = (value >> 3);
                triangle_.counter = getLengthValue(lengthIndex);
                triangle_.lengthActive = true;
            }
            break;
    }
}

void APU_Interface::writeNoise(u16 address, u8 value) {
    switch (address) {
        case 0x400C:
            // Length counter halt, constant volume, volume/envelope
            noise_.halt = (value & 0x20) != 0;
            break;
        case 0x400D:
            // Unused
            break;
        case 0x400E:
            // Loop noise, noise period
            break;
        case 0x400F:
            // Length counter load
            if (noise_.enabled) {
                u8 lengthIndex = (value >> 3);
                noise_.counter = getLengthValue(lengthIndex);
                noise_.lengthActive = true;
            }
            break;
    }
}


bool APU_Interface::detectQuarterFrame(u64 prev, u64 curr, bool mode5step) {
    // Quarter-frame boundaries in CPU cycles:
    // 4-step mode: 7457, 14913, 22371, 29829
    // 5-step mode: 7457, 14913, 22371, 29829, 37281
    
    // Check each boundary - return true if divider crossed it this cycle
    
    // Check 7457
    if (prev < STEP_7457 && curr >= STEP_7457) {
        return true;
    }
    
    // Check 14913
    if (prev < STEP_14913 && curr >= STEP_14913) {
        return true;
    }
    
    // Check 22371
    if (prev < STEP_22371 && curr >= STEP_22371) {
        return true;
    }
    
    // Check 29829
    if (prev < STEP_29829 && curr >= STEP_29829) {
        return true;
    }
    
    // Check 37281 (5-step mode only)
    if (mode5step && prev < STEP_37281 && curr >= STEP_37281) {
        return true;
    }
    
    // Handle wrap case: if curr < prev, divider wrapped to 0
    // 4-step mode: divider goes 0-29829 (wraps at 29830)
    // 5-step mode: divider goes 0-37281 (wraps at 37282)
    // Maximum divider value is one cycle after the last boundary
    if (curr < prev) {
        u64 maxValue = mode5step ? 37281 : 29829;  // Last boundary value (4-step: 29829, 5-step: 37281)
        
        // Check boundaries between prev and maxValue, then 0 to curr
        // Use consistent comparison: prev <= boundary (inclusive) to match normal crossing checks (curr >= boundary)
        if (prev <= STEP_7457 && STEP_7457 <= maxValue) {
            return true;
        }
        if (prev <= STEP_14913 && STEP_14913 <= maxValue) {
            return true;
        }
        if (prev <= STEP_22371 && STEP_22371 <= maxValue) {
            return true;
        }
        if (prev <= STEP_29829 && STEP_29829 <= maxValue) {
            return true;
        }
        if (mode5step && prev <= STEP_37281 && STEP_37281 <= maxValue) {
            return true;
        }
        
        // Also check boundaries between 0 and curr (after wrap)
        if (curr >= STEP_7457) {
            return true;
        }
        if (curr >= STEP_14913) {
            return true;
        }
        if (curr >= STEP_22371) {
            return true;
        }
        if (curr >= STEP_29829) {
            return true;
        }
        if (mode5step && curr >= STEP_37281) {
            return true;
        }
    }
    
    return false;
}

bool APU_Interface::detectHalfFrame(u64 prev, u64 curr, bool mode5step) {
    // Half-frame boundaries in CPU cycles:
    // 4-step mode: 14913, 29829 (wraps after 29830)
    // 5-step mode: 14913, 29829, 37281 (wraps after 37281)
    
    // Check if divider crossed 14913
    if (prev < STEP_14913 && curr >= STEP_14913) {
        return true;
    }
    
    // Check if divider crossed 29829
    if (prev < STEP_29829 && curr >= STEP_29829) {
        return true;
    }
    
    // Check if divider crossed 37281 (5-step mode only)
    if (mode5step && prev < STEP_37281 && curr >= STEP_37281) {
        return true;
    }
    
    // Handle wrap: if curr < prev, divider wrapped to 0
    // 4-step mode: divider goes 0-29829 (wraps at 29830)
    // 5-step mode: divider goes 0-37281 (wraps at 37382)
    // Maximum divider value is one cycle after the last boundary
    if (curr < prev) {
        u64 maxValue = mode5step ? 37281 : 29829;  // Last boundary value
        
        // Check boundaries between prev and maxValue
        // Use consistent comparison: prev <= boundary (inclusive) to match normal crossing checks (curr >= boundary)
        if (prev <= STEP_14913 && STEP_14913 <= maxValue) {
            return true;
        }
        if (prev <= STEP_29829 && STEP_29829 <= maxValue) {
            return true;
        }
        if (mode5step && prev <= STEP_37281 && STEP_37281 <= maxValue) {
            return true;
        }
        
        // Also check boundaries between 0 and curr (after wrap)
        if (curr >= STEP_14913) {
            return true;
        }
        if (curr >= STEP_29829) {
            return true;
        }
        if (mode5step && curr >= STEP_37281) {
            return true;
        }
    }
    
    return false;
}

// Tick Implementation

u8 APU_Interface::tick(InstructionPhase phase) {
    u64 currentCycle = bus_.getCycleCounter();
    
    // Store previous divider before tick (for frame step detection)
    u64 prevDivider = fc_.divider;
    
    // Advance Frame Counter by one cycle
    // Assembly function returns 1 if IRQ should be asserted this cycle, 0 otherwise
    // (IRQ line management is handled by emulation loop based on irqPending())
    (void)frameCounterTick(&fc_, currentCycle);
    
    // Read current divider after tick
    u64 currDivider = fc_.divider;
    bool mode5step = (fc_.mode5step != 0);
    
    // Detect half-frame event and clock length counters if needed
    if (detectHalfFrame(prevDivider, currDivider, mode5step)) {
        clockLengthCounters();
    }
    
    // Update lastDivider for next tick
    lastDivider_ = currDivider;
    
    // Advance DMC timing and compute cycle steal
    // The phase parameter represents the entire instruction's classification
    // (Read/Write/RMW) rather than the specific cycle-by-cycle phase.
    // The instruction-level phase is an intentional timing approximation.
    // Assembly function returns number of cycles to steal (0, 1, 2, or 4)
    u8 steal = dmcTimingTick(&dmc_, static_cast<u8>(phase), currentCycle);
    
    // If DMC requested a memory fetch (steal > 0), perform the fetch
    if (steal > 0 && dmc_.enabled && dmc_.sampleBufferEmpty && dmc_.bytesRemaining > 0) {
        // Read one byte from current DMC address
        // Use readMemory8 to go through proper memory bus access
        // DMC reads from $8000-$FFFF (or wraps $FFFF→$8000)
        u8 sample = bus_.readMemory8(dmc_.currentAddr);
        (void)sample;  // Suppress unused variable warning - sample data not needed for timing
        
        // Increment address (with wrap from $FFFF to $8000)
        if (dmc_.currentAddr == 0xFFFF) {
            dmc_.currentAddr = 0x8000;
        } else {
            dmc_.currentAddr++;
        }
        
        // Decrement bytes remaining
        dmc_.bytesRemaining--;
        
        // Check if sample finished
        if (dmc_.bytesRemaining == 0) {
            if (dmc_.loopFlag) {
                // Restart sample from beginning
                dmc_.currentAddr = dmc_.sampleStartAddr;
                dmc_.bytesRemaining = dmc_.sampleLength;
                // Keep sampleBufferEmpty = 1 to continue fetching
            } else {
                // Sample finished - stop fetching
                dmc_.sampleBufferEmpty = 0;
                // Set IRQ if enabled
                if (dmc_.irqEnable) {
                    dmc_.dmcIrqFlag = 1;
                }
            }
        }
        // If bytesRemaining > 0, keep sampleBufferEmpty = 1 (don't change it)
        // This allows continuous fetching as the output unit consumes samples
    }
    
    return steal;
}

// IRQ Pending Query

bool APU_Interface::irqPending() const {
    // Frame IRQ is pending if flag is set AND inhibit is clear
    bool frameIrqPending = (fc_.frameIrqFlag != 0) && (fc_.irqInhibit == 0);
    
    // DMC IRQ is pending if flag is set
    bool dmcIrqPending = (dmc_.dmcIrqFlag != 0);
    
    return frameIrqPending || dmcIrqPending;
}

} // namespace NES
