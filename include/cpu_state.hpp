#pragma once

#include <cstdint>

// CPU Status register flags
namespace CPUFlags {
    constexpr uint8_t CARRY = 0x01;
    constexpr uint8_t ZERO = 0x02;
    constexpr uint8_t INTERRUPT_DISABLE = 0x04;
    constexpr uint8_t DECIMAL = 0x08;
    constexpr uint8_t BREAK = 0x10;
    constexpr uint8_t UNUSED = 0x20;  // Always set to 1
    constexpr uint8_t OVERFLOW = 0x40;
    constexpr uint8_t NEGATIVE = 0x80;
}

// 6502 CPU State Structure
struct CPUState {
    uint16_t PC;    // Program Counter (16-bit)
    uint8_t A;      // Accumulator
    uint8_t X;      // X Register
    uint8_t Y;      // Y Register
    uint8_t SP;     // Stack Pointer (points to $0100 + SP)
    uint8_t P;      // Status Register (flags)
    uint64_t cycles; // Total cycle count
    
    // Initialize to reset state
    void reset() {
        PC = 0x0000;
        A = 0x00;
        X = 0x00;
        Y = 0x00;
        SP = 0xFD;  // Stack pointer starts at $FD (stack at $0100-$01FF)
        P = CPUFlags::UNUSED | CPUFlags::INTERRUPT_DISABLE;  // Reset state
        cycles = 0;
    }
    
    // Flag helper methods
    bool getCarry() const { return (P & CPUFlags::CARRY) != 0; }
    bool getZero() const { return (P & CPUFlags::ZERO) != 0; }
    bool getInterruptDisable() const { return (P & CPUFlags::INTERRUPT_DISABLE) != 0; }
    bool getDecimal() const { return (P & CPUFlags::DECIMAL) != 0; }
    bool getBreak() const { return (P & CPUFlags::BREAK) != 0; }
    bool getOverflow() const { return (P & CPUFlags::OVERFLOW) != 0; }
    bool getNegative() const { return (P & CPUFlags::NEGATIVE) != 0; }
    
    void setCarry(bool value) {
        if (value) P |= CPUFlags::CARRY;
        else P &= ~CPUFlags::CARRY;
    }
    void setZero(bool value) {
        if (value) P |= CPUFlags::ZERO;
        else P &= ~CPUFlags::ZERO;
    }
    void setInterruptDisable(bool value) {
        if (value) P |= CPUFlags::INTERRUPT_DISABLE;
        else P &= ~CPUFlags::INTERRUPT_DISABLE;
    }
    void setDecimal(bool value) {
        if (value) P |= CPUFlags::DECIMAL;
        else P &= ~CPUFlags::DECIMAL;
    }
    void setOverflow(bool value) {
        if (value) P |= CPUFlags::OVERFLOW;
        else P &= ~CPUFlags::OVERFLOW;
    }
    void setNegative(bool value) {
        if (value) P |= CPUFlags::NEGATIVE;
        else P &= ~CPUFlags::NEGATIVE;
    }
    
    // Set Z and N flags based on result value
    void setZN(uint8_t value) {
        setZero(value == 0);
        setNegative((value & 0x80) != 0);
    }
};

// Note: AddressingMode enum and Instruction struct are defined in types.hpp