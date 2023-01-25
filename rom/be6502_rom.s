        .include "zeropage.inc"
        .include "sysram.inc"
        .include "console.inc"
        .include "acia.inc"
        .include "kbd.inc"
        .include "via.inc"

.macro mac_setup_string addr
        lda #<addr
        sta str_ptr
        lda #>addr
        sta str_ptr + 1
.endmacro

        .code
cold_boot:
        sei
        jsr _acia_init
        jsr _con_init
        jsr _kbd_init
        cli
menu:
        jsr do_prompt

wait_for_input:
        jsr _con_in
        bcc wait_for_input
        jsr _con_out
        jmp wait_for_input

do_prompt:
        mac_setup_string str_prompt
        jsr _con_print
        rts

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
        bne @exit_irq
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
str_prompt:
        .asciiz "> "
str_nl: .byte $0d,$0a,$00

