#include "types.hpp"
#include "controller.hpp"
#include "memory_system.hpp"
#include <cstring>
#include <iostream>

namespace NES {

ControllerSystem::ControllerSystem()
    : strobe1(false), strobe2(false), multiplex_position(0), controller_count(1) {
    reset();
}

void ControllerSystem::reset() {
    for (int i = 0; i < 4; ++i) {
        controllers[i].buttons          = 0x00;
        controllers[i].serial_position  = 0;
        controllers[i].button_snapshot  = 0x00;
    }
    strobe1 = false;
    strobe2 = false;
    multiplex_position = 0;
    controller_count = 1;
}

void ControllerSystem::setControllerCount(u8 count) {
    controller_count = (count <= 4) ? count : 4;
}

u8 ControllerSystem::getControllerCount() const {
    return controller_count;
}

void ControllerSystem::setButton(u8 index, u8 button_mask, bool pressed) {
    if (index >= 4) return;
    if (pressed) {
        controllers[index].buttons |= button_mask;    // set bit = pressed
    } else {
        controllers[index].buttons &= ~button_mask;   // clear bit = released
    }
    if (index == 0 && std::getenv("NES_CTRL_DEBUG")) {
        std::fprintf(stderr, "[CTRL-SET] buttons=0x%02X mask=0x%02X pressed=%d\n",
                     controllers[index].buttons, button_mask, pressed);
    }
}

void ControllerSystem::pressButton(u8 controller, u8 button) {
    if (controller >= 4) return;
    controllers[controller].buttons |= (u8)(1 << button);
}

void ControllerSystem::releaseButton(u8 controller, u8 button) {
    if (controller >= 4) return;
    controllers[controller].buttons &= (u8)~(1 << button);
}

bool ControllerSystem::isButtonPressed(u8 controller, u8 button) const {
    if (controller >= 4) return false;
    return (controllers[controller].buttons & (1 << button)) != 0;
}

u8 ControllerSystem::getButtonState(u8 controller) const {
    if (controller >= 4) return 0x00;
    return controllers[controller].buttons;
}

void ControllerSystem::setButtonState(u8 controller, u8 buttons) {
    if (controller >= 4) return;
    controllers[controller].buttons = buttons;
}

void ControllerSystem::pressAllButtons(u8 controller) {
    if (controller >= 4) return;
    controllers[controller].buttons = 0xFF;
}

void ControllerSystem::releaseAllButtons(u8 controller) {
    if (controller >= 4) return;
    controllers[controller].buttons = 0x00;
}

// Emulates real hardware: Latch is transparent/open while strobe is high,
// and it captures the final snapshot state at the moment strobe goes low.
void ControllerSystem::handleStrobe1(u8 value) {
    bool new_strobe = (value & 0x01) != 0;
    for (u8 i = 0; i < controller_count; i++) {
        // Latch/capture the current live button state at the strobe write.
        controllers[i].button_snapshot = controllers[i].buttons;

        // Reset the shift position whenever strobe is asserted, and also on
        // the falling edge when the CPU releases the latch.
        if (new_strobe || strobe1) {
            controllers[i].serial_position = 0;
        }
    }

    strobe1 = new_strobe;
    if (std::getenv("NES_CTRL_DEBUG")) {
        std::fprintf(stderr, "[CTRL-STRB1] val=0x%02X new_strobe=%d buttons=0x%02X snap=0x%02X pos=%d\n",
                     value, new_strobe, controllers[0].buttons, controllers[0].button_snapshot, controllers[0].serial_position);
    }
}

void ControllerSystem::handleStrobe2(u8 value) {
    bool new_strobe = (value & 0x01) != 0;
    for (u8 i = 1; i < controller_count; i++) {
        controllers[i].button_snapshot = controllers[i].buttons;
        if (new_strobe || strobe2) {
            controllers[i].serial_position = 0;
        }
    }

    strobe2 = new_strobe;
}

u8 ControllerSystem::readController1() {
    if (controller_count == 0) return 0xFF;
    return getSerialData(0);
}

u8 ControllerSystem::readController2() {
    if (controller_count < 2) return 0xFF;
    u8 idx = 1 + multiplex_position;
    if (idx >= controller_count) idx = controller_count - 1;
    return getSerialData(idx);
}

u8 ControllerSystem::readController3() {
    if (controller_count < 3) return 0xFF;
    return getSerialData(2);
}

u8 ControllerSystem::readController4() {
    if (controller_count < 4) return 0xFF;
    return getSerialData(3);
}

u8 ControllerSystem::getSerialData(u8 controller) {
    if (controller >= 4) return 0xFF;

    // While strobe line is held high, shift register stays open at position 0 (Button A)
    if (strobe1 || (controller > 0 && strobe2)) {
        controllers[controller].button_snapshot = controllers[controller].buttons;
        controllers[controller].serial_position = 0;
        u8 r = (controllers[controller].button_snapshot & 0x01) ? 0x00 : 0x01;
        if (controller == 0 && std::getenv("NES_CTRL_DEBUG")) {
            std::fprintf(stderr, "[CTRL-SER] addr=%s snap=0x%02X bit0=%d -> 0x%02X\n",
                         (controller == 0) ? "0x4016" : "0x4017",
                         controllers[controller].button_snapshot,
                         controllers[controller].button_snapshot & 1, r);
        }
        return r;
    }

    u8 pos = controllers[controller].serial_position;

    // Standard NES controllers continuously stream 1 bits once 8 buttons are exhausted
    if (pos >= 8) {
        if (controller == 0 && std::getenv("NES_CTRL_DEBUG")) {
            std::fprintf(stderr, "[CTRL-SER] addr=%s pos>=8 -> 0x01\n",
                         (controller == 0) ? "0x4016" : "0x4017");
        }
        return 0x01;
    }

    u8 bit = (controllers[controller].button_snapshot >> pos) & 0x01;
    controllers[controller].serial_position++;
    u8 r = bit ? 0x00 : 0x01;
    if (controller == 0 && std::getenv("NES_CTRL_DEBUG")) {
        std::fprintf(stderr, "[CTRL-SER] addr=%s pos=%d snap=0x%02X bit=%d -> 0x%02X\n",
                     (controller == 0) ? "0x4016" : "0x4017",
                     pos, controllers[controller].button_snapshot, bit, r);
    }
    return r;
}

u8 ControllerSystem::getButtonBit(u8 controller) {
    if (controller >= 4) return 0xFF;
    u8 pos = controllers[controller].serial_position;
    if (pos >= 8) return 1;
    return ((controllers[controller].button_snapshot >> pos) & 0x01) ? 0x00 : 0x01;
}

u8 ControllerSystem::readIO(u16 address) {
    switch (address) {
        case 0x4016: return readController1();
        case 0x4017: return readController2();
        default: return 0xFF;
    }
}

void ControllerSystem::writeIO(u16 address, u8 value) {
    switch (address) {
        case 0x4016: handleStrobe1(value); break;
        case 0x4017: handleStrobe2(value); break;
    }
}

ControllerSystem gControllerSystem;

u8 readControllerIO(u16 address) {
    return gControllerSystem.readIO(address);
}

void writeControllerIO(u16 address, u8 value) {
    gControllerSystem.writeIO(address, value);
}

ControllerSystem& getControllerSystem() {
    return gControllerSystem;
}

} // namespace NES
