# Universal Asynchronous Receiver Transmitter

The Rockwell 6551 is bug free.  If you choose to use the WDC65C51 there is a small bug that you need to be aware of.  Do you own googling - I have the rockwell.

The devide is set up with receive interrupts enabled.  It will trigger an interrupt to the CPU whenever there is data on the receive line.  The CPU will read the data, store it into the input buffer and clear the interrupt.

The input buffer is the same buffer that's used by the Keyboard interrupt.

Interrupts are processed in order starting with Keyboard, then UART then VDP and finally any user defined interrutps.

I have not bothered with hardware handshaking or flow control.  These devices can not run at any baud rate over 19200bps.  So at this low speed I have found it to be very reliable.
