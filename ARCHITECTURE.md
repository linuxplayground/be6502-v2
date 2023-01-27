# OS Architecture for BE6502

## Input

### ACIA - UART

### PS KEYBOARD

## Output

### ACIA - UART

### VDP (TMS9918A)

## Console

- uses a buffer that's written to by the ACIA and the Keyboard routines.
- provides virtual input and output routines.

## Interrupts

[x] Keyboard interrupt
[x] ACIA interrupt

## Build objectives

[x] Low level routines for ACIA - feed into console buffer
[x] Virtual console routines
   [x] output to ACIA via ACIA routines
   - output to VDP via VDP routines
[x]] Low level keyboard routines - feed into console buffer
[x] basic monitor
    - driven by console routines
[x] Xmodem
[x] wozmon
    - updated to use console routines for IO
- ehbasic
    - updated to use console routines for IO
