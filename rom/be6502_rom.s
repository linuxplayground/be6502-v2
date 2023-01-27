        .include "zeropage.inc"
        .include "sysram.inc"
        .include "syscalls.inc"
        .include "console.inc"
        .include "console_macros.inc"
        .include "acia.inc"
        .include "kbd.inc"
        .include "via.inc"
        .include "xmodem.inc"
        .include "wozmon.inc"

        .code
cold_boot:
        sei
        ldx #$ff
        txs
        
        jsr _acia_init
        jsr _con_init
        jsr _kbd_init
        stz usr_irq
        stz usr_irq + 1
        cli
menu:
        mac_con_print str_help
prompt:
        jsr _con_prompt
wait_for_input:
        jsr _con_in
        bcc wait_for_input

        cmp #'x'
        beq run_xmodem
        cmp #'m'
        beq run_wozmon
        cmp #'r'
        beq run_program
        cmp #'h'
        beq run_help
        cmp #'c'
        beq cold_boot
        cmp #$0a                        ; CR
        beq new_line
        jsr _con_out
        jmp prompt
        jmp wait_for_input

run_xmodem:
        sei                             ; disable interrupts so xmodem can own the acia.
        jsr _xmodem
        cli
        jmp menu

run_help:
        mac_con_print str_help
        jsr _con_prompt
        jmp wait_for_input

run_wozmon:
        jsr _wozmon
        jmp menu

run_program:
        jsr $1000
        jsr _con_nl
        jmp menu

new_line:
        jsr _con_nl
        jmp prompt

nmi:
        rti
irq:
        pha
        phx
        phy
        
        bit ACIA_STATUS
        bpl @kbd_irq
        jsr _acia_read_byte
        ldx con_w_idx
        sta con_buf,x
        inc con_w_idx
@kbd_irq:
        bit VIA_IFR
        bpl @usr_irq
        jsr _kbd_isr
        jmp @exit_irq
@usr_irq:
        lda usr_irq + 1
        beq @exit_irq
        jmp (usr_irq)

@exit_irq:
        ply
        plx
        pla

        rti

        .segment "VECTORS"

        .word nmi
        .word cold_boot
        .word irq

        .rodata
str_help:
        .byte "Press X to run XMODEM", $0d,$0a
        .byte "Press M to run WOZMON", $0d,$0a
        .byte "Press R to run PROGR ", $0d,$0a
        .byte "Press C to run REBOOT", $0d,$0a
        .byte "Press H to show HELP ", $0d,$0a
        .byte $00


