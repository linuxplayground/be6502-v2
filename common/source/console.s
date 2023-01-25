        .include "sysram.inc"
        .include "acia.inc"
        .include "zeropage.inc"

        .export _con_init
        .export _con_in
        .export _con_out
        .export _con_print
        .export _con_new_line

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
        rts

_con_print:
        ldy #0
@loop:
        lda (str_ptr),y
        beq @return
        jsr _acia_write_byte
        iny
        jmp @loop
@return:
        rts

_con_new_line:
        lda #$0d
        jsr _acia_read_byte
        lda #$0a
        jsr _acia_write_byte
        rts