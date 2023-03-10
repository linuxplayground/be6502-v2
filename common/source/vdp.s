        .include "zeropage.inc"
        .include "sysram.inc"
        .include "vdp_macros.inc"
        .include "math.inc"

        .export _vdp_reset
        .export _vdp_home
        .export _vdp_clear_screen
        .export _vdp_get
        .export _vdp_put
        .export _vdp_set_write_address
        .export _vdp_set_read_address
        .export _vdp_xy_to_ptr
        .export _vdp_increment_pos_console
        .export _vdp_decrement_pos_console
        .export _vdp_console_out
        .export _vdp_console_newline
        .export _vdp_console_backspace
        .export _vdp_write_reg
        .export _vdp_disable_interrupts
        .export _vdp_enable_interrupts
        .export _vdp_irq

VDP_SPRITE_PATTERN_TABLE    = 0
VDP_PATTERN_TABLE           = $800
VDP_SPRITE_ATTRIBUTE_TABLE  = $1000
VDP_NAME_TABLE              = $1400
VDP_COLOR_TABLE             = $2000

VDP_TEXT_MODE_WIDTH         = 40
VDP_GRAPHICS_MODE_WIDTH     = 32
VDP_TEXT_MODE               = 0
VDP_G1_MODE                 = 1
VDP_G2_MODE                 = 2


        .import __TMS_START__
VDP_VRAM                = __TMS_START__ + $00   ; TMS Mode 0
VDP_REG                 = __TMS_START__ + $01   ; TMS Mode 1

        .code

; -----------------------------------------------------------------------------
; VDP Reset Routine
; -----------------------------------------------------------------------------
_vdp_reset:
        jsr vdp_clear_ram
        jsr vdp_init_registers                  ; defaults to text mode
        jsr vdp_init_patterns
        jsr vdp_init_colors
        stz vdp_x
        stz vdp_y
        stz vdp_vsync_ticks

        lda #VDP_TEXT_MODE_WIDTH
        sta vdp_con_width
        lda #VDP_TEXT_MODE
        sta vdp_con_mode
        rts

_vdp_home:
        stz vdp_x
        stz vdp_y
        vdp_vdp_xy_to_ptr
        vdp_set_write_address VDP_NAME_TABLE
        rts

; -----------------------------------------------------------------------------
; Fill screen with spaces.
; -----------------------------------------------------------------------------
_vdp_clear_screen:
        vdp_set_write_address VDP_NAME_TABLE
        ldx #4
        lda #' '
:       ldy #0
:       sta VDP_VRAM
        vdp_delay_slow
        iny
        bne :-
        dex
        bne :--
        jsr _vdp_home
        rts
; -----------------------------------------------------------------------------
; Get data from screen name table.
; A contains data at vdp_ptr
; -----------------------------------------------------------------------------
_vdp_get:
        lda VDP_VRAM
        vdp_delay_slow
        rts

; -----------------------------------------------------------------------------
; Write a byte to the VDP at address pointed to by vdp_ptr
; A contains the byte to write. vdp_ptr already points to location to write to
; -----------------------------------------------------------------------------
_vdp_put:
        sta VDP_VRAM
        vdp_delay_slow
        rts
; -----------------------------------------------------------------------------
; Set VDP Write address to address defined by A=lsb, X=msb
; -----------------------------------------------------------------------------
_vdp_set_write_address:
        sta VDP_REG
        vdp_delay_fast
        txa
        ora #$40
        sta VDP_REG
        vdp_delay_fast
        rts
; -----------------------------------------------------------------------------
; Set VDP Read address to address defined by A=lsb, X=msb
; -----------------------------------------------------------------------------
_vdp_set_read_address:
        sta VDP_REG
        vdp_delay_fast
        txa
        sta VDP_REG
        vdp_delay_fast
        rts

; -----------------------------------------------------------------------------
; VDP Write Register - A = Data, X = reg num
; -----------------------------------------------------------------------------
_vdp_write_reg:
        sta VDP_REG
        vdp_delay_slow
        txa
        ora #$80
        sta VDP_REG
        vdp_delay_slow
        rts

; -----------------------------------------------------------------------------
; Clear all of the memory in the VDP
; -----------------------------------------------------------------------------
vdp_clear_ram:
        lda #0
        sta VDP_REG
        ora #$40
        sta VDP_REG
        lda #$FF
        sta vdp_ptr
        lda #$3F
        sta vdp_ptr + 1
@clr_1:
        lda #$00
        sta VDP_VRAM
        vdp_delay_slow
        dec vdp_ptr
        lda vdp_ptr
        bne @clr_1
        dec vdp_ptr + 1
        lda vdp_ptr + 1
        bne @clr_1
        rts

; -----------------------------------------------------------------------------
; Set vdp_ptr for a given text position
; Preserves A
; Borks X, Y
; -----------------------------------------------------------------------------
; Inputs:
;   X: X position (0 - 31)
;   Y: Y position (0 - 23)
; -----------------------------------------------------------------------------
_vdp_xy_to_ptr:
        pha
        lda #<VDP_NAME_TABLE
        sta vdp_ptr
        lda #>VDP_NAME_TABLE
        sta vdp_ptr + 1
        
        ; this can be better. rotate and save, perhaps
        lda vdp_con_mode
        beq @text_mode
        ; applies to g1 and g2 mode
        tya
        div8
        clc
        adc vdp_ptr + 1
        sta vdp_ptr + 1
        tya
        and #$07
        mul32
        sta vdp_ptr
        txa
        ora vdp_ptr
        sta vdp_ptr
        bra @return
@text_mode:
        cpy #0
        beq @add_x
        clc
        lda vdp_ptr
        adc #VDP_TEXT_MODE_WIDTH
        sta vdp_ptr
        bcc @dec_y
        inc vdp_ptr + 1
@dec_y:
        dey
        bne @text_mode
@add_x:
        clc
        txa
        adc vdp_ptr
        sta vdp_ptr
        bcc @return
        inc vdp_ptr + 1
@return:
        pla
        rts


; -----------------------------------------------------------------------------
; Increment console position
; -----------------------------------------------------------------------------
_vdp_increment_pos_console:
        inc vdp_x
        lda vdp_x
        cmp vdp_con_width
        bne :+
        stz vdp_x
        inc vdp_y
        lda vdp_y
        cmp #24
        bne :+
        jmp _vdp_scroll_line
:       rts

; -----------------------------------------------------------------------------
; Decrement console position
; -----------------------------------------------------------------------------
_vdp_decrement_pos_console:
        dec vdp_x
        bpl :++
        lda vdp_con_width
        sta vdp_x
        dec vdp_x
        lda #0
        cmp vdp_y
        bne :+
        sta vdp_x
        rts        
:       dec vdp_y
:       rts

; -----------------------------------------------------------------------------
; Print a character to the screen
; -----------------------------------------------------------------------------
; Inputs:
;  'A': Character to output to console
; -----------------------------------------------------------------------------
_vdp_console_out:
        stx vdp_reg_x
        sty vdp_reg_y
        cmp #$0d
        beq @new_line
        cmp #$0a
        beq @end_console_out
        cmp #$08
        beq @backspace
        pha
        vdp_vdp_xy_to_ptr
        vdp_ptr_to_vram_write_addr
        pla
        jsr _vdp_put
        jsr _vdp_increment_pos_console
@end_console_out:
        ldy vdp_reg_y
        ldx vdp_reg_x
        rts 
@new_line:
        jsr _vdp_console_newline
        jmp @end_console_out
@backspace:
        jsr _vdp_console_backspace
        jmp @end_console_out

; -----------------------------------------------------------------------------
; Output a newline to the console (scrolls if on last line)
; -----------------------------------------------------------------------------
_vdp_console_newline:
        stz vdp_x
        inc vdp_y
        lda vdp_y
        cmp #24
        bne :+
        jsr _vdp_scroll_line
        lda #23
        sta vdp_y
:       vdp_vdp_xy_to_ptr
        rts

; -----------------------------------------------------------------------------
; Backspace
; -----------------------------------------------------------------------------
_vdp_console_backspace:
        jsr _vdp_decrement_pos_console
        vdp_vdp_xy_to_ptr
        vdp_ptr_to_vram_write_addr
        lda #' '
        jsr _vdp_put
        rts
; -----------------------------------------------------------------------------
; Scrolls text up by one line.
; -----------------------------------------------------------------------------
_vdp_scroll_line:
        lda #0
        sta scroll_write
        lda #1
        sta scroll_read
@next_row:
        jsr scroll_buffer_in
        jsr scroll_buffer_out
        inc scroll_read
        inc scroll_write
        lda scroll_read
        cmp #25
        bne @next_row
        rts

scroll_buffer_in:
        lda scroll_read
        sta vdp_y
        stz vdp_x
        vdp_vdp_xy_to_ptr
        vdp_ptr_to_vram_read_addr
        ldy #0
:       jsr _vdp_get
        sta linebuf,y
        iny
        cpy vdp_con_width
        bne :-
        rts

scroll_buffer_out:
        lda scroll_write
        sta vdp_y
        stz vdp_x
        vdp_vdp_xy_to_ptr
        vdp_ptr_to_vram_write_addr
        ldy #0
:       lda linebuf,y
        jsr _vdp_put
        iny
        cpy vdp_con_width
        bne :-
        rts

; -----------------------------------------------------------------------------
; Disable Interrupts
; -----------------------------------------------------------------------------
_vdp_disable_interrupts:
        ldx #$01
        lda vdp_con_mode
        cmp #VDP_TEXT_MODE
        beq :+
        lda #$C0
        jsr _vdp_write_reg
        rts
:       lda #$D0
        jsr _vdp_write_reg
        rts

; -----------------------------------------------------------------------------
; Enable Interrupts
; -----------------------------------------------------------------------------
_vdp_enable_interrupts:
        ldx #$01
        lda vdp_con_mode
        cmp #VDP_TEXT_MODE
        beq :+
        lda #$C0
        jsr _vdp_write_reg
        rts
:       lda #$F0
        jsr _vdp_write_reg
        rts

; -----------------------------------------------------------------------------
; Set up Graphics Mode 1 - see init defaults at the end of this file.
; -----------------------------------------------------------------------------
vdp_init_registers:
        ldx #$00
:       lda vdp_inits,x
        sta VDP_REG
        vdp_delay_slow
        txa
        ora #$80
        sta VDP_REG
        vdp_delay_slow
        inx
        cpx #8
        bne :-
        rts

; -----------------------------------------------------------------------------
; Initialise the pattern table. (font)
; -----------------------------------------------------------------------------
vdp_init_patterns:
        vdp_set_write_address VDP_PATTERN_TABLE

        lda #<patterns
        sta vdp_ptr
        lda #>patterns
        sta vdp_ptr + 1
        ldy #0
:
        lda (vdp_ptr),y
        sta VDP_VRAM
        lda vdp_ptr
        clc
        adc #1
        sta vdp_ptr
        lda #0
        adc vdp_ptr + 1
        sta vdp_ptr + 1
        cmp #>end_patterns
        bne :-
        lda vdp_ptr
        cmp #<end_patterns
        bne :-
        rts

; -----------------------------------------------------------------------------
; Initialise the color table.
; -----------------------------------------------------------------------------
vdp_init_colors:
        vdp_set_write_address VDP_COLOR_TABLE

        lda #<colors
        sta vdp_ptr
        lda #>colors
        sta vdp_ptr + 1
        ldy #0
:       lda (vdp_ptr),y
        sta VDP_VRAM
        vdp_delay_slow
        lda vdp_ptr
        clc
        adc #1
        sta vdp_ptr
        lda #0
        adc vdp_ptr + 1
        sta vdp_ptr + 1
        cmp #>end_colors
        bne :-
        lda vdp_ptr
        cmp #<end_colors
        bne :-
        rts

;=============================================================================
; Handle VSYNC trigger
;=============================================================================
_vdp_irq:
        inc vdp_vsync_ticks
        lda vdp_vsync_ticks
        cmp #60
        bne :+
        stz vdp_vsync_ticks
:       lda vdp_con_mode
        cmp #VDP_TEXT_MODE
        bne :+
        jsr vdp_do_cursor
:       rts

;=============================================================================
; blink the cursor in text mode only.
;=============================================================================
vdp_do_cursor:
        lda vdp_vsync_ticks
        beq @do_cursor
        cmp #30
        beq @do_cursor
        bra @return
@do_cursor:
        vdp_vdp_xy_to_ptr
        vdp_ptr_to_vram_write_addr
        lda vdp_vsync_ticks
        beq @underline
        lda #' '
        sta VDP_VRAM
        bra @return
@underline:
        lda #'_'
        sta VDP_VRAM
        ;fall through
@return:
        vdp_delay_slow
        rts
;=============================================================================
;     DATA
;=============================================================================
str_prompt:
        .asciiz "> "
str_nl: .byte $0d,$0a,$00

vdp_inits:
reg_0: .byte $00                ; r0
reg_1: .byte $F0                ; r1 16kb ram + M1, interrupts enabled, text mode
reg_2: .byte $05                ; r2 name table at 0x1400
reg_3: .byte $80                ; r3 color start 0x2000
reg_4: .byte $01                ; r4 pattern generator start at 0x800
reg_5: .byte $20                ; r5 Sprite attriutes start at 0x1000
reg_6: .byte $00                ; r6 Sprite pattern table at 0x0000
reg_7: .byte $6E                ; r7 Set forground and background color (dark red on white)
vdp_inits_end:

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
