#ifndef CONTROLLER_HPP
#define CONTROLLER_HPP

#include "types.hpp"

namespace NES {

    // Button Constants matching the physical NES hardware read order:
    // bit 0 = A ... bit 7 = Right. Internal button state uses pressed = 1.
    // The NES controller data line is active-low: pressed returns 0.
    constexpr u8 BUTTON_A       = 0x01;
    constexpr u8 BUTTON_B       = 0x02;
    constexpr u8 BUTTON_SELECT  = 0x04;
    constexpr u8 BUTTON_START   = 0x08;
    constexpr u8 BUTTON_UP      = 0x10;
    constexpr u8 BUTTON_DOWN    = 0x20;
    constexpr u8 BUTTON_LEFT    = 0x40;
    constexpr u8 BUTTON_RIGHT   = 0x80;

    struct ControllerState {
        u8 buttons;           // current live window button state
        u8 serial_position;   // position in the shift register while reading
        u8 button_snapshot;   // safe snapshot caught on the falling edge of strobe
    };

    class ControllerSystem {
    private:
        ControllerState controllers[4];
        bool strobe1;
        bool strobe2;
        u8 multiplex_position;
        u8 controller_count;

    public:
        ControllerSystem();
        void reset();

        void setControllerCount(u8 count);
        u8 getControllerCount() const;

        void setButton(u8 index, u8 button_mask, bool pressed);
        void pressButton(u8 controller, u8 button);
        void releaseButton(u8 controller, u8 button);
        bool isButtonPressed(u8 controller, u8 button) const;
        
        u8 getButtonState(u8 controller) const;
        void setButtonState(u8 controller, u8 buttons);
        
        void pressAllButtons(u8 controller);
        void releaseAllButtons(u8 controller);

        void handleStrobe1(u8 value);
        void handleStrobe2(u8 value);

        u8 readController1();
        u8 readController2();
        u8 readController3();
        u8 readController4();

        u8 getSerialData(u8 controller);
        u8 getButtonBit(u8 controller);

        u8 readIO(u16 address);
        void writeIO(u16 address, u8 value);
    };

    extern ControllerSystem gControllerSystem;

    u8 readControllerIO(u16 address);
    void writeControllerIO(u16 address, u8 value);
    ControllerSystem& getControllerSystem();

} // namespace NES

#endif // CONTROLLER_HPP
