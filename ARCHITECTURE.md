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

- Keyboard interrupt
- ACIA interrupt

## Build objectives

- Low level routines for ACIA - feed into console buffer
- Virtual console routines
   - output to ACIA via ACIA routines
   - output to VDP via VDP routines
- Low level keyboard routines - feed into console buffer
- basic monitor
    - driven by console routines
- wozmon
    - updated to use console routines for IO
- ehbasic
    - updated to use console routines for IO
