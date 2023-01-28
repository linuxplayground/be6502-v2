        .include "sysram.inc"
        .include "acia.inc"
        .include "console_macros.inc"
        .include "zeropage.inc"
        .include "vdp.inc"

        .export _con_init
        .export _con_in
        .export _con_out
        .export _con_prompt
        .export _con_nl
        .export _con_print
        .export _con_nl

        .code

_con_init:
        stz con_r_idx
        stz con_w_idx
        rts

_con_in:
        sei
        lda con_r_idx
        cmp con_w_idx
        cli
        beq @no_data
        tax
        lda con_buf,x
        inc con_r_idx
        sec
        rts
@no_data:
        clc
        rts

_con_out:
        jsr _acia_write_byte
        jsr _vdp_out
        rts

_con_prompt:
        mac_con_print str_prompt
        rts

_con_nl:
        mac_con_print str_nl
        rts

_con_print:
        ldy #0
@loop:
        lda (str_ptr),y
        beq @return
        jsr _con_out
        iny
        jmp @loop
@return:
        rts

        .rodata
str_prompt:
        .asciiz "> "

str_nl: .byte $0a,$0d,$00
