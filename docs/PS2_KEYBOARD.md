# PS Keyboard

I am using a 104 Key Periboard-409 for my PS/2 needs.

This particular keyboard requires an initialisation sequence to be met before it will start sending scancodes.  I have 100% copied the work done on the [HBC-56 project](https://github.com/visrealm/hbc-56).  Except that, I did not hook it directly into my bus.  Instead, I have it hooked into the VIA and am using the CA1 interrupt pin on the VIA to handle the keyboard interrupts.

The rom includes the library to respond to keyboard interrupts, translate the scan codes to ASCII and then save the ASCII output to into a buffer in RAM.

The UART also saves it's data to the same buffer and a third "console" library provides access to the buffer.  This is how I can accept input on both the UART and the Keybaord at the same time.

The PIC MCU project is included in the HBC-56 project referenced at the top of this page.