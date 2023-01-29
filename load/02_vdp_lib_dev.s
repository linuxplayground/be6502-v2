        .include "console.inc"
        .include "vdp.inc"
        .include "vdp_macros.inc"
        .include "sysram.inc"
        .code

; test application and entry point.
main:
        jsr _vdp_clear_screen
        lda #23
        sta vdp_y
        lda #31
        sta vdp_x
        vdp_vdp_xy_to_ptr
        lda #'@'
        jsr _vdp_put
        
loop:
        jsr _con_in
        bcc loop
        cmp #$1b                ; ESC
        beq exit
        jsr _con_out
        jmp loop
exit:
        rts