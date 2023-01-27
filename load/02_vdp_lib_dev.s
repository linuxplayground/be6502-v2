        .include "console.inc"
        .include "vdp.inc"

        .code

; test application and entry point.
main:
        jsr _vdp_reset
        jsr _vdp_clear_screen
loop:
        jsr _con_in
        bcc @flush
        cmp #$1b                ; ESC
        beq exit
        ldy #0
@out:
        jsr _vdp_out
@flush:
        jsr _vdp_wait
        jsr _vdp_flush
        jmp loop
exit:
        rts
