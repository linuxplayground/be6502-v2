        .include "vdp_macros.inc"
        .include "sysram.inc"
        .include "zeropage.inc"

        .export _vdp_reset
        .export _vdp_clear_screen
        .export _vdp_home
        .export _vdp_wait
        .export _vdp_flush
        .export _vdp_out
        .export _vdp_put
        .export _vdp_scroll


VDP_SPRITE_PATTERN_TABLE    = 0
VDP_PATTERN_TABLE           = $800
VDP_SPRITE_ATTRIBUTE_TABLE  = $1000
VDP_NAME_TABLE              = $1400
VDP_COLOR_TABLE             = $2000

        .import __TMS_START__
VDP_VRAM                = __TMS_START__ + $00   ; TMS Mode 0
VDP_REG                 = __TMS_START__ + $01   ; TMS Mode 1

        .code

;=============================================================================
;     VDP FUNCTIONS
;=============================================================================
_vdp_out:
        pha
        phx
        phy
        cmp #$0d
        beq @cr
        cmp #$0a
        beq @return
        cmp #$08
        beq @bs

        jsr _vdp_calc_cursor_addr
        jsr _vdp_put
        inc vdp_x
        lda vdp_x
        cmp #32
        bne @return
        stz vdp_x
        inc vdp_y
        lda vdp_y
        cmp #24
        bne @return
        jsr _vdp_scroll
        lda #23
        sta vdp_y
        stz vdp_x
        jmp @return
@cr:
        inc vdp_y
        lda vdp_y
        cmp #24
        bne :+
        jsr _vdp_scroll
        lda #23
        sta vdp_y
:       stz vdp_x
        jmp @return

@bs:
        lda vdp_x
        beq @return
        dec vdp_x
        jsr _vdp_calc_cursor_addr
        lda #' '
        jsr _vdp_put


@return:
        ply
        plx
        pla
        rts

_vdp_home:
        stz vdp_x
        stz vdp_y
        jsr _vdp_calc_cursor_addr
        rts

_vdp_put:
        sta (vdp_cur_l)
        rts
@flush:
        jsr _vdp_wait
        jsr _vdp_flush
        rts

; sets the vdp_cur_l pointer to a value based on y x 32 + x
; inputs: x register and y register.
_vdp_calc_cursor_addr:
        pha
        phx
        phy
        lda #<screen
        sta vdp_cur_l
        lda #>screen
        sta vdp_cur_h
@mul32:
        lda vdp_cur_l
        ldx vdp_x
        ldy vdp_y
@mul_32_lp:
        cpy #$00
        beq @mul_32_add_x
        clc
        adc #32
        sta vdp_cur_l
        bcc @mul_32_continue
        inc vdp_cur_h
@mul_32_continue:
        dey
        bne @mul_32_lp
@mul_32_add_x:
        clc
        txa
        adc vdp_cur_l
        sta vdp_cur_l
        bcc @mul_32_done
        inc vdp_cur_h
@mul_32_done:
        ply
        plx
        pla
        rts

; scroll up one line.
_vdp_scroll:
        lda #0
        sta scroll_write
        lda #1
        sta scroll_read
@lp:
        jsr scroll_buffer_in
        jsr scroll_buffer_out
        inc scroll_read
        inc scroll_write
        lda scroll_read
        cmp #24
        bne @lp
        jsr scroll_insert_empty_line
        lda #32
        sta vdp_y
        stz vdp_x
        jsr _vdp_calc_cursor_addr
        rts

scroll_insert_empty_line:
        lda #23
        sta vdp_y
        stz vdp_x
        jsr _vdp_calc_cursor_addr
        lda #' '
        ldy #0
@lp:
        sta (vdp_cur_l),y
        iny
        cpy #32
        bne @lp
        rts

scroll_buffer_in:
        lda scroll_read
        sta vdp_y
        stz vdp_x
        jsr _vdp_calc_cursor_addr

        ldy #0
@lp:
        lda (vdp_cur_l),y
        sta linebuf,y
        iny
        cpy #32
        bne @lp
        rts

scroll_buffer_out:
        lda scroll_write
        sta vdp_y
        stz vdp_x
        jsr _vdp_calc_cursor_addr

        ldy #0
@lp:
        lda linebuf,y
        sta (vdp_cur_l),y
        iny
        cpy #32
        bne @lp
        rts

_vdp_reset:
        jsr vdp_clear_ram
        jsr vdp_set_graphics_1_mode
        jsr vdp_init_patterns
        jsr vdp_init_colors

        lda #<screen
        sta vdp_cur_l
        lda #>screen
        sta vdp_cur_h

        stz vdp_x
        stz vdp_y
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

_vdp_wait:
        vdp_delay_slow
        lda VDP_REG
        and #$80
        beq _vdp_wait
        rts

; This function is designed to flush on the next vertical pulse from the VDP
_vdp_flush:
        lda #<VDP_NAME_TABLE    ; set name table start address on vdp write register
        sta VDP_REG
        lda #>VDP_NAME_TABLE
        ora #$40
        sta VDP_REG

        lda #<screen            ; point at start of screen ram
        sta vdp_l
        lda #>screen
        sta vdp_h
        ldx #3
@lp1:
        ldy #0
@lp2:
        lda (vdp_l),y
        sta VDP_VRAM
        nop
        iny
        bne @lp2
        inc vdp_h
        dex
        bne @lp1
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
reg_1: .byte $E0                ; r1 16kb ram + M1, interrupts enabled
reg_2: .byte $05                ; r2 name table at 0x1400
reg_3: .byte $80                ; r3 color start 0x2000
reg_4: .byte $01                ; r4 pattern generator start at 0x800
reg_5: .byte $20                ; r5 Sprite attriutes start at 0x1000
reg_6: .byte $00                ; r6 Sprite pattern table at 0x0000
reg_7: .byte $45                ; r7 Set background and forground color
vdp_end_graphics_1_inits:

patterns:
        .include "../res/font.asm"
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
