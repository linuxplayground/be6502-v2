        .include "console.inc"
        .include "console_macros.inc"
        .include "zeropage.inc"

        ; to develop the VDP functionality, I need to also develop the console
        ; lib to integrate with them.  To save from having to continuously
        ; extract, burn and insert the rom chip, I am developing this library
        ; on a "loadable" application.  Or to use a CP/M term, a TPA



VDP_SPRITE_PATTERN_TABLE    = 0
VDP_PATTERN_TABLE           = $800
VDP_SPRITE_ATTRIBUTE_TABLE  = $1000
VDP_NAME_TABLE              = $1400
VDP_COLOR_TABLE             = $2000

        .import __TMS_START__
VDP_VRAM                = __TMS_START__ + $00   ; TMS Mode 0
VDP_REG                 = __TMS_START__ + $01   ; TMS Mode 1


.macro vdp_delay_slow
        .repeat 16
        nop
        .endrepeat
.endmacro

.macro vdp_delay_fast
        .repeat 4
        nop
        .endrepeat
.endmacro

        ; .zeropage
vdp_l= $e0
vdp_h= $e1
vdp_cur_l= $e2
vdp_cur_h= $e3
screen= $0600


        .code

; test application and entry point.
main:
        jsr _vdp_reset
        jsr _vdp_clear_screen

        lda #<screen
        sta vdp_cur_l
        lda #>screen
        sta vdp_cur_h

loop:
        jsr _con_in
        bcc @flush
        cmp #$1b                ; ESC
        beq exit
        ldy #0
@out:
        sta (vdp_cur_l),y
        inc vdp_cur_l
        bne @flush
        inc vdp_cur_h
@flush:
        jsr _vdp_flush
        jmp loop
exit:
        rts


;=============================================================================
;     VDP FUNCTIONS
;=============================================================================
_vdp_reset:
        jsr vdp_clear_ram
        jsr vdp_set_graphics_1_mode
        jsr vdp_init_patterns
        jsr vdp_init_colors
        rts

; clear the screen
_vdp_clear_screen:
        lda #<screen            ; point at start of screen ram
        sta vdp_l
        lda #>screen
        sta vdp_h

        ldy #0
@lp:
        lda #' '
        sta (vdp_l),y
        inc vdp_l
        bne @lp
        inc vdp_h
        lda vdp_h
        cmp #$09
        beq @exit
        jmp @lp
@exit:
        rts

; clear vdp memory all the way from 0 to 3FFF
vdp_clear_ram:
        lda #0
        sta VDP_REG
        ora #$40
        sta VDP_REG
        lda #$FF
        sta vdp_l
        lda #$3F
        sta vdp_h
@clr_1:
        lda #$00
        sta VDP_VRAM
        vdp_delay_slow
        dec vdp_l
        lda vdp_l
        bne @clr_1
        dec vdp_h
        lda vdp_h
        bne @clr_1
        rts

vdp_set_graphics_1_mode:
        ldx #$00
@loop:
        lda vdp_graphics_1_inits,x
        sta VDP_REG
        vdp_delay_slow
        txa
        ora #$80
        sta VDP_REG
        vdp_delay_slow
        inx
        cpx #8
        bne @loop
        rts

; load the font
vdp_init_patterns:
        lda #<VDP_PATTERN_TABLE
        sta VDP_REG
        vdp_delay_slow
        lda #>VDP_PATTERN_TABLE
        ora #$40
        sta VDP_REG
        vdp_delay_slow
        
        lda #<patterns
        sta vdp_l
        lda #>patterns
        sta vdp_h
        ldy #0
@ip_1:
        lda (vdp_l),y
        sta VDP_VRAM
        vdp_delay_slow
        lda vdp_l
        clc
        adc #1
        sta vdp_l
        lda #0
        adc vdp_h
        sta vdp_h
        cmp #>end_patterns
        bne @ip_1
        lda vdp_l
        cmp #<end_patterns
        bne @ip_1
        rts

; load the initial colour pallette
vdp_init_colors:
        lda #<VDP_COLOR_TABLE
        sta VDP_REG
        vdp_delay_slow
        lda #>VDP_COLOR_TABLE
        ora #$40
        sta VDP_REG
        vdp_delay_slow
        lda #<colors
        sta vdp_l
        lda #>colors
        sta vdp_h
        ldy #0
@ic_1:
        lda (vdp_l),y
        sta VDP_VRAM
        vdp_delay_slow
        lda vdp_l
        clc
        adc #1
        sta vdp_l
        lda #0
        adc vdp_h
        sta vdp_h
        cmp #>end_colors
        bne @ic_1
        lda vdp_l
        cmp #<end_colors
        bne @ic_1
        rts

; This function is designed to flush on the next vertical pulse from the VDP
_vdp_flush:
        lda VDP_REG
        and #$80
        beq _vdp_flush

        lda #<VDP_NAME_TABLE    ; set name table start address on vdp write register
        sta VDP_REG
        vdp_delay_fast
        lda #>VDP_NAME_TABLE
        ora #$40
        sta VDP_REG

        lda #<screen            ; point at start of screen ram
        sta vdp_l
        lda #>screen
        sta vdp_h

        ldy #0
@lp:
        lda (vdp_l),y
        sta VDP_VRAM
        vdp_delay_fast
        inc vdp_l
        bne @lp
        inc vdp_h
        lda vdp_h
        cmp #$09
        beq @exit
        jmp @lp
@exit:
        rts
        
;=============================================================================
;     DATA
;=============================================================================
str_prompt:
        .asciiz "> "
str_nl: .byte $0d,$0a,$00

vdp_graphics_1_inits:
reg_0: .byte $00                ; r0
reg_1: .byte $E0                ; r1 16kb ram + M1, interrupts disabled
reg_2: .byte $05                ; r2 name table at 0x1400
reg_3: .byte $80                ; r3 color start 0x2000
reg_4: .byte $01                ; r4 pattern generator start at 0x800
reg_5: .byte $20                ; r5 Sprite attriutes start at 0x1000
reg_6: .byte $00                ; r6 Sprite pattern table at 0x0000
reg_7: .byte $45                ; r7 Set background and forground color
vdp_end_graphics_1_inits:

patterns:
        .include "../common/res/font.asm"
end_patterns:

; in graphics 1 mode, these colors refer to the patterns in groups
; of 8.  Each byte covers 8 patterns.  so pattern 90 for example is covered by color $34
; in this table.  0x3 is the forground color (light green) and 0x4 is the background color
; (blue)
colors:
        .byte $e4,$e4,$e4,$e4,$e4,$e4,$e4,$e4   ; 00 - 3F
        .byte $e4,$e4,$e4,$e4,$e4,$e4,$e4,$e4   ; 40 - 7F
        .byte $e4,$e4,$e4,$e4,$e4,$e4,$e4,$e4   ; 80 - BF
        .byte $e4,$e4,$e4,$e4,$e4,$e4,$e4,$e4   ; C0 - FF
end_colors:
