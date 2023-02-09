        .include "zeropage.inc"
        .include "sysram.inc"
        .include "syscalls.inc"
        .include "console.inc"
        .include "console_macros.inc"
        .include "ehbasic.inc"
        .include "acia.inc"
        .include "kbd.inc"
        .include "via.inc"
        .include "xmodem.inc"
        .include "wozmon.inc"
        .include "vdp.inc"
        .include "vdp_macros.inc"

        .export menu

        .import __TMS_START__
VDP_VRAM                = __TMS_START__ + $00   ; TMS Mode 0
VDP_REG                 = __TMS_START__ + $01   ; TMS Mode 1

        .import __ACIA_START__
ACIA_COMMAND = __ACIA_START__ + $02

; ACIA command register bit values

ACIA_PARITY_ODD              = %00000000
ACIA_PARITY_EVEN             = %01000000
ACIA_PARITY_MARK             = %10000000
ACIA_PARITY_SPACE            = %11000000
ACIA_PARITY_DISABLE          = %00000000
ACIA_PARITY_ENABLE           = %00100000
ACIA_ECHO_DISABLE            = %00000000
ACIA_ECHO_ENABLE             = %00010000
ACIA_TX_INT_DISABLE_RTS_HIGH = %00000000
ACIA_TX_INT_ENABLE_RTS_LOW   = %00000100
ACIA_TX_INT_DISABLE_RTS_LOW  = %00001000
ACIA_TX_INT_DISABLE_BREAK    = %00001100
ACIA_RX_INT_ENABLE           = %00000000
ACIA_RX_INT_DISABLE          = %00000010
ACIA_DTR_HIGH                = %00000000
ACIA_DTR_LOW                 = %00000001

        .code
cold_boot:
        sei
        ldx #$ff
        txs

        jsr _vdp_reset
        vdp_set_text_color $06, $0f
        jsr _con_init
        jsr _acia_init
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
        cmp #'b'
        beq run_basic
        cmp #$0a                        ; CR
        beq new_line
        jsr _con_out
        jmp prompt
        jmp wait_for_input

run_xmodem:
        jsr _con_nl
        sei                             ; disable interrupts so xmodem can own the acia.
        jsr _xmodem
        cli
        jmp menu
run_basic:
        jmp BASIC_init
run_help:
        jsr _con_nl
        mac_con_print str_help
        jsr _con_prompt
        jmp wait_for_input

run_wozmon:
        jsr _con_nl
        jsr _wozmon
        jmp menu

run_program:
        jsr _con_nl
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
@kbd_irq:
        bit VIA_IFR
        bpl @acia_irq
        jsr _kbd_isr
        bra @exit_irq
@acia_irq:
        bit ACIA_STATUS
        bpl @vdp_irq
        jsr _acia_read_byte
        ldx con_w_idx
        sta con_buf,x
        inc con_w_idx
        bra @exit_irq
@vdp_irq:
        lda VDP_REG
        and #$80
        beq @usr_irq
        jsr _vdp_irq
        bra @exit_irq
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
load_message: .byte "Press 'x' to start xmodem receive ...", $0a, $0d
              .byte "Press 'r' to run your program ...", $0a, $0d
              .byte "Press 'b' to run basic ...", $0a, $0d
              .byte "Press 'm' to start Wozmon ...", $0a, $0d, $00
        .byte $00

