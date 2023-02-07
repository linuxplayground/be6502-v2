        .include "via.inc"
        .include "zeropage.inc"
        .include "sysram.inc"
        .include "utils.inc"

RESET = %00000100
LATCH = %00000111
WRITE = %00000110

        .export _psg_init
        .export _play_vgm_data

        .code
_psg_init:
        ; set up VIA pin directions
        lda #$ff                ; porta used to send data to the ay-3-8910
        sta VIA_DDRA
        lda VIA_DDRB
        ora #(RESET|LATCH|WRITE); portb used to set registers and reset the ay-3-8910
        sta VIA_DDRB

        jsr reset               ; reset the AY-3-8910
        rts

; A = first byte of data stream low
; X = first byte of data stream high 
; only works for streams where the total number of bytes is less than 256
_play_vgm_data:
        pha
        phx
        phy
        sta vgm_data
        stx vgm_data + 1        ; set up the pointer
        ldy #0                  ; set up indirect index to 0
loop:                           ; loop until $66 is reached
        lda (vgm_data),y        ; read command
        cmp #$61
        beq pause
        cmp #$62
        beq pause_60
        cmp #$63
        beq pause_50
        cmp #$66
        beq done
        cmp #$a0
        beq register
        and #$f0
        cmp #$70
        beq short_pause
done:
        ply
        plx
        pla
        rts
pause:
        iny
        lda (vgm_data),y
        sta vgm_temp
        iny
        lda (vgm_data),y
        sta vgm_temp + 1
        jsr wait_samples
        iny
        jmp loop 
pause_50:
        iny
        lda #$03
        sta vgm_temp + 1
        lda #$72
        sta vgm_temp
        jsr wait_samples
        iny
        jmp loop
pause_60:
        iny
        lda #$02
        sta vgm_temp + 1
        lda #$df
        sta vgm_temp
        jsr wait_samples
        iny
        jmp loop
short_pause:
        iny
        lda (vgm_data),y
        and #$0f
        sta vgm_temp
        stz vgm_temp + 1
        jsr wait_samples
        iny
        jmp loop
register:
        iny
        lda (vgm_data),y
        tax
        iny
        lda (vgm_data),y        ; data
        jsr write_register
        iny
        jmp loop

reset:
        lda #$00
        sta VIA_PORTB
        lda #10
        jsr _delay_ms
        lda #RESET
        sta VIA_PORTB
        rts

wait_samples:
        lda vgm_temp            ; (3)                 
        bne @wait_samples_1     ; (2)   (could be 3 if branching across page)
        lda vgm_temp + 1        ; (3)
        beq @return             ; (2)   (could be 3 if branching across page)
        dec vgm_temp + 1        ; (5)     
@wait_samples_1:
        dec vgm_temp            ; (5)
        ; kill some cycles between loops.  Adjust as required.
        .repeat 16
        nop
        .endrepeat
        jmp wait_samples        ; (3)   loop = 29 cycles
@return:
        rts                     ; (6)   6 cycles to return


write_register:
        pha                             ; preserve registers

        lda #(LATCH)
        sta VIA_PORTB
        txa
        sta VIA_PORTA                   ; write register

        lda #(RESET)
        sta VIA_PORTB

        lda #(WRITE)
        sta VIA_PORTB
        pla
        sta VIA_PORTA                   ; write data

        lda #(RESET)
        sta VIA_PORTB
        rts
