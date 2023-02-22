        .include "console.inc"

score = $E1
score_h = $E2
TMP = $E0

        .code
        stz score
        stz score_h
        stz TMP
count:
        jsr _con_in
        bcc count
        cmp #$0d
        beq output
        cmp #$0a
        beq output
        jsr inc_score
        jmp count
output:
        lda score_h
        jsr bcd_out
        lda score
        jsr bcd_out
        rts
        
bcd_out:
        sta TMP
        .repeat 4
        lsr
        .endrepeat
        ora #'0'
        jsr _con_out
        lda TMP
bcd_out_l:
        and #$0f
        ora #'0'
        jsr _con_out
        rts

inc_score:
        clc
        sed
        lda #09
        adc score
        sta score
        bcc :+
        lda #0
        adc score_h
        sta score_h
:       cld
        rts
