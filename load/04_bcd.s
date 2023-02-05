        .include "console.inc"

score = $E0

        .code
        stz score
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
        lda score
        jmp bcd_out

bcd_out:
        pha
        .repeat 4
        lsr
        .endrepeat
        ora #'0'
        jsr _con_out
        pla
bdd_out_l:
        and #$0f
        ora #'0'
        jsr _con_out
        rts

inc_score:
        sed
        lda #1
        clc
        adc score
        sta score
        cld
        rts
