        .include "console.inc"
        .include "console_macros.inc"
        .include "zeropage.inc"
        .include "sysram.inc"
        .include "vdp.inc"
        .include "vdp_macros.inc"
        .include "audiolib.inc"

        .import __TMS_START__
VDP_VRAM                = __TMS_START__ + $00   ; TMS Mode 0
VDP_REG                 = __TMS_START__ + $01   ; TMS Mode 1
VDP_NAME_TABLE          = $1400
VDP_COLOR_TABLE         = $2000

K_LEFT                  = $A1 ; $6B
K_RIGHT                 = $A2 ; $74
K_DOWN                  = $A4 ; $72
K_A                     = 'a' ; $1C
K_D                     = 'd' ; $23
K_SPACE                 = ' ' ; $29
K_RETURN                = $0D ; $5A   ; ENTER
K_ESCAPE                = $1b ; $76   ; ESCAPE
GET_INPUT_DELAY         = $FE

scr_ptr                 = $E0   ; 2 bytes
scr_ptr2                = $E2   ; 2 bytes
score                   = $E4
score_h                 = $E5

vidram = $300
.macro print px, py, addr
        lda #px
        sta block_x_position
        lda #py
        sta block_y_position
        jsr set_vidram_position
        lda #<addr
        sta str_ptr
        lda #>addr
        sta str_ptr + 1
        jsr local_print
.endmacro

        .code
new_game:
        jsr _psg_init
        lda #<snd_init
        ldx #>snd_init
        jsr _play_vgm_data

        jsr _vdp_reset
        vdp_con_g1_mode
        jsr setup_colors
        vdp_set_text_color $0e, $0b
        jsr clear_vidram
        jsr draw_map
        print 20, 1, str_next
        ; print 20, 9, str_level
        print 20, 14, str_score
        ; print 20, 19, str_lives
        print 8, 10, str_start
        jsr paint_vidram

        lda #GET_INPUT_DELAY
        sta input_delay
        lda #30
        sta fall_delay

        lda fall_delay
        sta delay_counter
        sta fall_speed
        
        stz score
        stz score_h
        stz score_multiplier

startgame_loop:
        inc seed
        jsr _con_in
        bcc startgame_loop
        print 8, 10, str_clear_start
        ; test
        jsr get_random
        sta next_block_id
        jsr new_block

game_loop:
        lda pause_flag
        beq :++
:       jsr _con_in
        bcc :-
        lda pause_flag
        eor #%00000001
        sta pause_flag
:       jsr _con_in                     ; check for input
        bcc @fall                       ; no input - fall the block
        sta pressed_key                 ; save pressed key
@key_pressed:
        jsr get_key_inputs              ; process key inputs
        cmp #$ff                        ; did the user press escape?
        beq @exit                       ; yes => exit
        jmp @reset_input_delay          ; jump to reset input delay
@fall:
        dec delay_counter               ; slow the game down
        bne @paint                      ; not zero - paint
        jsr fall                        ; delay loop is zero - so fall block
        beq @reset_delay_counter        ; did we hit the bottom?
        jsr check_lines                 ; bottom hit - check if we made a line
        lda lines_made                  ; did we make a line?
        beq @new_block
        jsr update_score                ; increment score by lines made
        ; we need to delete the made line.
        jsr remove_lines                ; clear out any made lines then fall through
@new_block:
        jsr new_block                   ; did not make a line
        bne @exit
@reset_delay_counter:
        lda fall_speed                  ; reset delay loop counter
        sta delay_counter               ; store
        bra @paint                      ; paint
@reset_input_delay:
        lda GET_INPUT_DELAY             ; input delay can be reset now
        sta input_delay
@paint:
        jsr paint_vidram                ; paint the shadow ram to the screen
        jmp game_loop                   ; loop
@exit:
        jmp exit                        ; exit game.
exit:
        lda #<snd_crash
        ldx #>snd_crash
        jsr _play_vgm_data
        print 9, 10, str_game_over
        jsr paint_vidram
:       jsr _con_in
        bcc :-
        cmp #$20
        bne :+
        jmp new_game
:       cmp #$1b
        bne :-
        rts

; update score and bcdout
; A contains the amount to increase score by
update_score:
        sed
        clc
        adc score
        sta score
        lda #0
        adc score_h
        sta score_h
        cld

        ldx #21
        ldy #15
        stx block_x_position
        sty block_y_position
        jsr set_vidram_position
        lda score_h
        jsr bcd_out_l
        lda score
        jsr bcd_out
        inc score_multiplier
        lda score_multiplier
        cmp #5
        bne :+
        lda #<snd_lvl_up
        ldx #>snd_lvl_up
        jsr _play_vgm_data
        stz score_multiplier
        lda fall_delay
        beq :+                  ; don't decrement fall delay below 0
        dec fall_delay          ; increase speed by 1 every 5 lines.
        rts

:       lda #<snd_eat
        ldx #>snd_eat
        jsr _play_vgm_data
        rts

;------------------------------------------------------------------------------
; Print 1 byte BCD value
;------------------------------------------------------------------------------
bcd_out:
        ldy #0
        pha
        .repeat 4
        lsr
        .endrepeat
        ora #'0'
        sta (scr_ptr),y
        pla
bcd_out_l:
        ldy #1
        and #$0f
        ora #'0'
        sta (scr_ptr),y
        rts

;------------------------------------------------------------------------------
; Generate a random number
; Result in A
;------------------------------------------------------------------------------
prng:
        lda seed
        beq @doEor
        asl
        bcc @noEor
@doEor:
        eor #$1d
@noEor:
        sta seed
        rts

; selects a new block and places it at the top of the screen
new_block:
        lda fall_delay
        sta delay_counter
        sta fall_speed
        ldx #21
        ldy #3
        stx block_x_position
        sty block_y_position
        lda next_block_id
        pha
        jsr select_block
        jsr erase_block
        jsr get_random
        sta next_block_id
        lda next_block_id
        jsr select_block
        jsr print_block

        ldx #10
        ldy #1
        stx block_x_position
        sty block_y_position
        pla
        sta current_block_id
        jsr select_block
        jsr check_space
        bne :+
        jsr print_block
        lda #0
        rts
:       jsr print_block
        lda #1
        rts

get_random:
        jsr prng
        and #$07                ; keep only bottom 3 bits (7)
        cmp #$07                ; is it 7, yes then try again.
        bne :+
        jmp get_random
:       rts

get_key_inputs:
        lda pressed_key
        bne :+          ; a key is held down.
        jmp @no_key
:       cmp #K_RETURN
        bne :+
        lda pause_flag
        eor #%00000001
        sta pause_flag
        jmp @return
:       cmp #K_LEFT
        bne :++
        jsr erase_block
        dec block_x_position
        jsr check_space
        beq :+
        inc block_x_position
:       jmp @return

:       cmp #K_RIGHT
        bne :++
        jsr erase_block
        inc block_x_position
        jsr check_space
        beq :+
        dec block_x_position
:       jmp @return

:       cmp #K_A
        bne :++
        jsr erase_block
        lda #$01
        jsr animate_block
        jsr check_space
        beq :+
        lda #$00
        jsr animate_block
:       jmp @return

:       cmp #K_D
        bne :++
        jsr erase_block
        lda #$00
        jsr animate_block
        jsr check_space
        beq :+
        lda #$01
        jsr animate_block
:       jmp @return

:       cmp #K_DOWN
        bne :++
        jsr erase_block
        inc block_y_position
        jsr check_space
        beq :+
        dec block_y_position
:       jmp @return

:       cmp #K_SPACE
        bne :+
        lda #1
        sta fall_speed
        jmp @return

:       cmp #K_ESCAPE
        bne @return
        lda #$FF
        rts
@return:
        jsr print_block
@no_key:
        rts

; update the falling block
fall:
        jsr erase_block
        inc block_y_position
        jsr check_space
        beq @return
        dec block_y_position
        jsr print_block
        lda #1
        rts
@return:
        jsr print_block
        lda #0
        rts

; check if a line is filled
; called after fall returns a 1
; before new block
check_lines:
        stz lines_made
        lda #$01                ; the current row is one below the top.
        sta current_row
        ldx #7
        ldy #1
        stx block_x_position
        sty block_y_position
        jsr set_vidram_position
        ldx #0
@read_start:
        ldy #0
@read_loop:
        lda (scr_ptr),y
        cmp #$20
        beq @next_row
        iny
        cpy #12
        bne @read_loop
        ; whole row checked and no spaces, we made a line
        ldy lines_made
        lda current_row
        sta line_row_numbers, y
        ; do we want to save to a buffer so we can flash it?
        ; not for now, but maybe later.
        inc lines_made
        lda lines_made
        cmp #4
        beq @read_done
@next_row:
        inc current_row
        lda current_row
        cmp #23
        beq @read_done
        jsr down_row
        jmp @read_start
@read_done:
        lda lines_made
        rts

; remove lines made from play area and then move all lines down
remove_lines:
        lda #$00
        sta current_line_index
set_pointers:
        ldx current_line_index
        lda line_row_numbers,x
        tay
        jsr set_line_pointers
        jsr move_line_data
        inc current_line_index
        lda current_line_index
        cmp lines_made
        bne set_pointers
        rts

; sets screen memory pointers to made line and the line above it
; so that data can be moved.
; set y to the row to point to before calling this.
set_line_pointers:
        ldx #7
        dey             ; go up one row
        stx block_x_position
        sty block_y_position
        jsr set_vidram_position
        lda scr_ptr
        sta scr_ptr2
        lda scr_ptr + 1
        sta scr_ptr2 + 1
        jsr down_row
        rts

; move data down
move_line_data:
        ldy current_line_index
        lda line_row_numbers,y
        tax
@start_loop:
        ldy #0
@loop:
        lda (scr_ptr2),y
        sta (scr_ptr),y
        iny
        cpy #12
        bne @loop
        dex
        beq @done_moving
        txa
        tay
        pha
        jsr set_line_pointers
        pla
        tax
        jmp @start_loop
@done_moving:
        ldx #7
        ldy #1
        stx block_x_position
        sty block_y_position
        jsr set_vidram_position
        ldy #0
        lda #$20
@clear_line_loop:
        sta (scr_ptr),y
        iny
        cpy #12
        bne @clear_line_loop
@exit:
        rts

; set A register with block ID before calling
select_block:
        sta current_block_id
        tax
        lda block_frame_start,x
        sta current_frame
        sta first_frame
        lda block_frame_end,x
        sta last_frame
        rts

; animate block.  A can be 0 for clockwise, and 1 for counterclockwise
; ensure select block has been called prior to calling this
animate_block:
        cmp #1
        beq do_backward
do_forward:
        lda current_frame
        cmp last_frame
        beq :+
        inc current_frame
        rts
:       lda first_frame
        sta current_frame
        rts
do_backward:
        lda current_frame
        cmp first_frame
        beq :+
        dec current_frame
        rts
:       lda last_frame
        sta current_frame
        rts

; translate x and y locations to vidram shadow
; remember to call vdp_ptr_to_vram_write_addr
set_vidram_position:
        lda #>vidram
        sta scr_ptr + 1
        lda #<vidram
        sta scr_ptr

        ldy block_y_position
        cpy #0
        beq ydone
yloop:
        clc
        adc #32
        bcc :+
        inc scr_ptr + 1
:       dey
        cpy #$00
        bne yloop
ydone:
        ldx block_x_position
        cpx #$00
        beq xdone
        clc
        adc block_x_position
        bcc xdone
        inc scr_ptr + 1
xdone:
        sta scr_ptr
        rts

; prints a block on the vidram
; vidram position must have been set
; x register contains the block ID
print_block:
        jsr set_vidram_position
        ldx current_frame
        lda block_array_lo,x
        sta print_loop + 1
        lda block_array_hi,x
        sta print_loop + 2

        ldx #$00
        ldy #$00
print_loop:
        lda $1010,x
        cmp #$20
        beq :+
        sta (scr_ptr),y
:       inx
        cpx #16
        bne :+
        rts
:       iny
        cpy #$04
        bne print_loop
        jsr down_row
        ldy #$00
        jmp print_loop

; prints a block on the vidram
; vidram position must have been set
; x register contains the block ID
erase_block:
        jsr set_vidram_position
        ldx current_frame
        lda block_array_lo,x
        sta erase_loop + 1
        lda block_array_hi,x
        sta erase_loop + 2

        ldx #$00
        ldy #$00
erase_loop:
        lda $1010,x
        cmp #$20
        beq :+
        lda #$20                ; space
        sta (scr_ptr),y
:       inx
        cpx #16
        bne :+
        rts
:       iny
        cpy #$04
        bne erase_loop
        jsr down_row
        ldy #$00
        jmp erase_loop

; checks each cell in the new location
; returns with carry set if new location
; is occupied
; carry clear if new location is free
check_space:
        jsr set_vidram_position
        ldx current_frame
        lda block_array_lo,x
        sta check_space_loop + 1
        lda block_array_hi,x
        sta check_space_loop + 2

        ldx #$00
        ldy #$00
check_space_loop:
        lda $1010,x
        cmp #$20
        beq :+
        lda (scr_ptr),y
        cmp #$20
        beq :+
        lda #$01
        rts
:       inx
        cpx #16
        bne :+
        lda #$00
        rts
:       iny
        cpy #$04
        bne check_space_loop
        jsr down_row
        ldy #$00
        jmp check_space_loop

; adjust scr_ptr to point to row exactly below it
down_row:
        lda scr_ptr
        clc
        adc #32
        bcc :+
        inc scr_ptr + 1
:       sta scr_ptr
        rts

; paint vidram
paint_vidram:
@do:
        lda #<VDP_NAME_TABLE
        sta vdp_ptr
        lda #>VDP_NAME_TABLE
        sta vdp_ptr + 1
        vdp_ptr_to_vram_write_addr

        lda #<vidram
        sta vdp_ptr
        lda #>vidram
        sta vdp_ptr + 1

        ldx #3
@page:
        ldy #0
@loop:
        lda (vdp_ptr),y
        sta VDP_VRAM
        vdp_delay_fast
        iny
        bne @loop
        inc vdp_ptr + 1
        dex
        bne @page
        rts

clear_vidram:
        lda #<vidram
        sta vdp_ptr
        lda #>vidram
        sta vdp_ptr + 1
        lda #$00
        ldx #3
@page:
        ldy #0
@loop:
        sta (vdp_ptr),y
        iny
        bne @loop
        inc vdp_ptr + 1
        dex
        bne @page
        rts

; draw map
draw_map:
        lda #<vidram
        sta vdp_ptr
        lda #>vidram
        sta vdp_ptr + 1
        clc
        lda vdp_ptr
        adc #$6
        sta vdp_ptr

        lda #<map
        sta scr_ptr
        lda #>map
        sta scr_ptr + 1
        ldx #00
@loop:
        lda (scr_ptr)
        beq @return
        sta (vdp_ptr)
        inc scr_ptr
        bne :+
        inc scr_ptr + 1
:       inc vdp_ptr
        bne :+
        inc scr_ptr + 1
:       inx
        cpx #21
        beq :+
        jmp @loop
:       ldx #0
        clc
        lda vdp_ptr
        adc #11
        sta vdp_ptr
        bcc :+
        inc vdp_ptr + 1
:       jmp @loop
@return:
        rts

setup_colors:
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

;------------------------------------------------------------------------------
; Print null terminated string pointed to by str_ptr
;------------------------------------------------------------------------------
local_print:
        ldy #0
@loop:
        lda (str_ptr),y
        beq @return
        sta (scr_ptr),y
        iny
        jmp @loop
@return:
        rts

; data
block_x_position:       .byte 0
block_y_position:       .byte 0
current_block_id:       .byte 0
current_frame:          .byte 0
first_frame:            .byte 0
last_frame:             .byte 0
delay_counter:          .byte 0
fall_speed:             .byte 0
fall_delay:             .byte 0
pause_flag:             .byte 0
seed:                   .byte $c3
input_delay:            .byte 0
pressed_key:            .byte 0
next_block_id:          .byte 0
lines_made:             .byte 0
current_row:            .byte 0
line_row_numbers:       .byte 0,0,0,0
current_line_index:     .byte 0
score_multiplier:       .byte 0

        .rodata
block_frame_start:
        .byte 0, 1, 3, 5, 7, 11, 15
block_frame_end:
        .byte 0, 2, 4, 6, 10, 14, 18

block_array_lo:
        .byte <b0f0
        .byte <b1f0,<b1f1
        .byte <b2f0,<b2f1
        .byte <b3f0,<b3f1
        .byte <b4f0,<b4f1,<b4f2,<b4f3
        .byte <b5f0,<b5f1,<b5f2,<b5f3
        .byte <b6f0,<b6f1,<b6f2,<b6f3
block_array_hi:
        .byte >b0f0
        .byte >b1f0,>b1f1
        .byte >b2f0,>b2f1
        .byte >b3f0,>b3f1
        .byte >b4f0,>b4f1,>b4f2,>b4f3
        .byte >b5f0,>b5f1,>b5f2,>b5f3
        .byte >b6f0,>b6f1,>b6f2,>b6f3

b0f0:           ; block         =0
        .byte $20,$20,$20,$20
        .byte $20,$91,$91,$20
        .byte $20,$91,$91,$20
        .byte $20,$20,$20,$20
b1f0:           ; long 0        =1
        .byte $20,$20,$20,$20
        .byte $91,$91,$91,$91
        .byte $20,$20,$20,$20
        .byte $20,$20,$20,$20
b1f1:           ; long 1        =2
        .byte $20,$20,$91,$20
        .byte $20,$20,$91,$20
        .byte $20,$20,$91,$20
        .byte $20,$20,$91,$20
b2f0:           ; S 0           =3
        .byte $20,$20,$20,$20
        .byte $20,$20,$91,$91
        .byte $20,$91,$91,$20
        .byte $20,$20,$20,$20
b2f1:           ; S 1           =4
        .byte $20,$91,$20,$20
        .byte $20,$91,$91,$20
        .byte $20,$20,$91,$20
        .byte $20,$20,$20,$20
b3f0:           ; Z 0           =5
        .byte $91,$91,$20,$20
        .byte $20,$91,$91,$20
        .byte $20,$20,$20,$20
        .byte $20,$20,$20,$20
b3f1:           ; Z 1m          =6
        .byte $20,$20,$91,$20
        .byte $20,$91,$91,$20
        .byte $20,$91,$20,$20
        .byte $20,$20,$20,$20
b4f0:           ; L 0           =7
        .byte $20,$91,$20,$20
        .byte $20,$91,$20,$20
        .byte $20,$91,$91,$20
        .byte $20,$20,$20,$20
b4f1:           ; L 1           =8
        .byte $20,$20,$20,$20
        .byte $91,$91,$91,$20
        .byte $91,$20,$20,$20
        .byte $20,$20,$20,$20
b4f2:           ; L 2           =9
        .byte $20,$91,$91,$20
        .byte $20,$20,$91,$20
        .byte $20,$20,$91,$20
        .byte $20,$20,$20,$20
b4f3:           ; L 3           =10
        .byte $20,$20,$91,$20
        .byte $91,$91,$91,$20
        .byte $20,$20,$20,$20
        .byte $20,$20,$20,$20
b5f0:           ; J 0           =11
        .byte $20,$20,$91,$20
        .byte $20,$20,$91,$20
        .byte $20,$91,$91,$20
        .byte $20,$20,$20,$20
b5f1:           ; J 1           =12
        .byte $20,$20,$20,$20
        .byte $91,$20,$20,$20
        .byte $91,$91,$91,$20
        .byte $20,$20,$20,$20
b5f2:           ; J 2           =13
        .byte $20,$91,$91,$20
        .byte $20,$91,$20,$20
        .byte $20,$91,$20,$20
        .byte $20,$20,$20,$20
b5f3:           ; J 3           =14
        .byte $20,$20,$20,$20
        .byte $91,$91,$91,$20
        .byte $20,$20,$91,$20
        .byte $20,$20,$20,$20
b6f0:           ; T 0           =15
        .byte $20,$91,$91,$91
        .byte $20,$20,$91,$20
        .byte $20,$20,$20,$20
        .byte $20,$20,$20,$20
b6f1:           ; T 1           =16
        .byte $20,$20,$20,$91
        .byte $20,$20,$91,$91
        .byte $20,$20,$20,$91
        .byte $20,$20,$20,$20
b6f2:           ; T 2           =17
        .byte $20,$20,$20,$20
        .byte $20,$20,$91,$20
        .byte $20,$91,$91,$91
        .byte $20,$20,$20,$20
b6f3:           ; T 3           =18
        .byte $20,$91,$20,$20
        .byte $20,$91,$91,$20
        .byte $20,$91,$20,$20
        .byte $20,$20,$20,$20

map:    ; 21 x 24
        ;       6   7   8   9  10  11  12  13  14  15  16  17  18  19  20  21  22  23  24  25  26
        .byte $87,$84,$84,$84,$84,$84,$84,$84,$84,$84,$84,$84,$84,$8d,$84,$84,$84,$84,$84,$84,$88 ;  0
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ;  1
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ;  2
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ;  3
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ;  4
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ;  5
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ;  6
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ;  7
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$8c,$84,$84,$84,$84,$84,$84,$8b ;  8
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ;  9
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ; 10
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ; 11
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ; 12
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$8c,$84,$84,$84,$84,$84,$84,$8b ; 13
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ; 14
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ; 15
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ; 16
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ; 17
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$8c,$84,$84,$84,$84,$84,$84,$8b ; 18
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ; 19
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ; 20
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ; 21
        .byte $81,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$20,$81,$20,$20,$20,$20,$20,$20,$81 ; 22
        .byte $86,$84,$84,$84,$84,$84,$84,$84,$84,$84,$84,$84,$84,$8e,$84,$84,$84,$84,$84,$84,$89 ; 23
        .byte $00
map_end:

colors:
        .byte $fb,$f1,$f1,$f1,$f1,$f1,$f1,$f1   ; 00 - 3F
        .byte $f1,$f1,$f1,$f1,$f1,$f1,$f1,$f1   ; 40 - 7F
        .byte $f1,$f1,$31,$f4,$f4,$f4,$f4,$f4   ; 80 - BF
        .byte $f6,$f4,$f4,$f4,$f4,$f4,$f4,$f4   ; C0 - FF
end_colors:
str_next:
        .asciiz "NEXT"
str_level:
        .asciiz "LEVEL"
str_score:
        .asciiz "SCORE"
str_lives:
        .asciiz "LIVES"
str_game_over:
        .asciiz "GAME OVER!"
str_start:
        .asciiz "PRESS SPACE"
str_clear_start:
        .asciiz "           "

snd_init:
        .byte $a0, $07, $2E     ; mixer enable channel A (tone) and channel B (noise)
        .byte $66
snd_eat:
        .byte $a0, $08, $1f     ; channel A (tone) volume controlled by envelope
        .byte $a0, $0c, $04     ; envelope frequency, channel B
        .byte $a0, $0d, $00     ; envelope shape to \_
        .byte $a0, $00, $80     ; channel A (tone) fine frequency
        .byte $a0, $01, $00     ; channel A (tone) course frequency
        .byte $66
snd_crash:
        .byte $a0, $09, $1F     ; channel B (noise) volume controlled by envelope
        .byte $a0, $08, $00     ; channel A (tone) volume OFF
        .byte $a0, $0b, $a0     ; set envelope fine duration
        .byte $a0, $0c, $40     ; set envelope course duration
        .byte $a0, $0d, $00     ; set envelope shape to   \__ 
        .byte $a0, $06, $0f     ; Set noise duration
        .byte $66
snd_lvl_up:
        .byte $a0, $08, $0f     ; channel A full volume
        .byte $a0, $01, $00     ; channel A (tone) course frequency
        .byte $a0, $00, $FF     ; channel A (tone) fine frequency (lower pitch)
        .byte $61, $2d, $08     ; wait 
        .byte $a0, $00, $80     ; channel A (tone) fine frequency (higher pitch)
        .byte $61, $2d, $0f     ; wait 
        .byte $a0, $08, $00     ; channel A zero volume
        .byte $66