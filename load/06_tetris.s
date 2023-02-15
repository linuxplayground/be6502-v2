;------------------------------------------------------------------------------
; Tetris - heavily inspired by 
; https://devdef.blogspot.com/2015/02/tetris-in-6502-assembler-part-1.html
; This port is for the BE6502-V2 board and supports the TMS9918a VDP as well as
; the AY-3-8910 PSG.  The main logic of the game is mostly similar although,
; I am still working through some of the level up logic.
;------------------------------------------------------------------------------

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

K_LEFT                  = $A1
K_RIGHT                 = $A2
K_DOWN                  = $A4
K_A                     = 'a'
K_D                     = 'd'
K_SPACE                 = ' '
K_RETURN                = $0D
K_ESCAPE                = $1B
GET_INPUT_DELAY         = $FE

scr_ptr                 = $E0   ; 2 bytes
scr_ptr2                = $E2   ; 2 bytes
score                   = $E4
score_h                 = $E5

vidram                  = screen        ; defined in sysram.inc - vidram is
                                        ; shadow memory which is then flushed
                                        ; to the display at the end of each
                                        ; game loop

;------------------------------------------------------------------------------
; Print text defined at `addr` at position `px`,`py` to vidram
;------------------------------------------------------------------------------
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
;------------------------------------------------------------------------------
; Game entry point.  Reinit everything.
;------------------------------------------------------------------------------
new_game:
        jsr _psg_init                   ; init AY-3-8910 Audio device and setup
        lda #<snd_init                  ; mixers by playing the vgm data.
        ldx #>snd_init                  ; see audiolib.s in includes/sources.
        jsr _play_vgm_data

        jsr _vdp_reset                  ; set up the VDP into graphics 1 mode.
        vdp_con_g1_mode                 ; see vdp.s in includes/sources.

        jsr setup_colors                ; local colors for the game
        vdp_set_text_color $0e, $b0     ; setup yellow border.

        jsr clear_vidram                ; clear shadow display memory
        jsr draw_map                    ; draw the map
        print 20, 1, str_next           ; write text to the map
        ; print 20, 9, str_level
        print 20, 14, str_score
        ; print 20, 19, str_lives
        print 8, 10, str_start          ; write the start game text
        jsr paint_vidram                ; flush the shadow ram to the display

        lda #GET_INPUT_DELAY            ; at 2Mhz a delay is needed to avoid
        sta input_delay                 ; too rapidly accepting inputs

        lda #30                         ; only allow a block to fall every 30 game
        sta fall_delay                  ; loops.  This is adjusted to increase
                                        ; game speed / difficulty
        sta delay_counter               ; init fall speed and delay counter.
        sta fall_speed                  ; fall_speed is temporarily reduced when
                                        ; player drops a block

        stz score                       ; init the score
        stz score_h
                                        ; XXX - TODO: Refactor into Levels
        stz score_multiplier            ; variable to track when to increase the
                                        ; speed.
;------------------------------------------------------------------------------
; Start game loop - set up random seed and wait for player to start game
;------------------------------------------------------------------------------
startgame_loop:                         ; when the game is started, we need to
        inc seed                        ; set a seed.  This spin-loop updates the
        jsr _con_in                     ; seed until the player presses a key.
        bcc startgame_loop
        print 8, 10, str_clear_start    ; overwrite the start game text with
                                        ; spaces
        jsr get_random                  ; fetch a random number between 0 and 6
        sta next_block_id               ; save as next block
        jsr new_block                   ; call new_block routine to apply next
                                        ; block and create new new next block

;------------------------------------------------------------------------------
; Main game loop.  Check for inputs, fall block, check for collisions etc.
;------------------------------------------------------------------------------
game_loop:                              ; main game loop
        lda pause_flag                  ; check if we are in pause mode and
        beq :++                         ; stay in loop until a user presses a
:       jsr _con_in                     ; key.
        bcc :-
        lda pause_flag                  ; flip pause flag
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
        lda lines_made                  ; did we make at least one line?
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

;------------------------------------------------------------------------------
; Game over routine.  Plays gameover sound, waits for player input to play
; again or exit to monitor.
;------------------------------------------------------------------------------
exit:
        lda #<snd_crash                 ; play the crash sound effect.
        ldx #>snd_crash
        jsr _play_vgm_data
        print 9, 10, str_game_over      ; display game over message
        jsr paint_vidram                ; flush the display

:       jsr _con_in                     ; wait for user to press space to play
        bcc :-                          ; again or escap to quick back to
        cmp #$20                        ; monitor.
        bne :+
        jmp new_game
:       cmp #$1b
        bne :-
        rts

;------------------------------------------------------------------------------
; TODO: Refactor scoring and level up into proper levels.
; Updates the score in BCD mode, displays the updated score.
; Currently checks if ready to level up.
; INPUT: A - value to add to score.
;------------------------------------------------------------------------------
update_score:
        sed                             ; Use BCD mode to track the score.
        clc                             ; max score is 99
        adc score
        sta score
        lda #0
        adc score_h
        sta score_h
        cld

        ldx #21                         ; position the screen memory pointer
        ldy #15
        stx block_x_position
        sty block_y_position
        jsr set_vidram_position
        lda score_h
        jsr bcd_out_l                   ; write two digits of score to screen.
        lda score
        jsr bcd_out
        inc score_multiplier            ; increment to multiple of 5
        lda score_multiplier
        cmp #5                          ; if multiple of 5 then speed up game
        bne :+                          ; XXX - TODO - none of this is the right

        lda #<snd_lvl_up                ; play level up sound effect.
        ldx #>snd_lvl_up
        jsr _play_vgm_data

        stz score_multiplier            ; reset level up counter.
        lda fall_delay
        beq :+                          ; don't decrement fall delay below 0
        dec fall_delay                  ; increase speed by 1 every 5 lines.
        rts

:       lda #<snd_eat                   ; not a level up - so just play regular
        ldx #>snd_eat                   ; complete line sound effect.
        jsr _play_vgm_data
        rts

;------------------------------------------------------------------------------
; Print 1 byte BCD value
; INPUT: A the BCD Value to print.
;------------------------------------------------------------------------------
bcd_out:
        ldy #0
        pha
        .repeat 4
        lsr
        .endrepeat
        ora #'0'
        sta (scr_ptr),y                 ; prints to shadow dispaly memory
        pla
bcd_out_l:
        ldy #1
        and #$0f
        ora #'0'
        sta (scr_ptr),y
        rts

;------------------------------------------------------------------------------
; Generate a random number
; INPUT: seed - contains the seed generated at the stat game loop.
; Result in A and seed for next time.
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

;------------------------------------------------------------------------------
; Take next_block and display it at top of play area.
; set up new next_block
;------------------------------------------------------------------------------
new_block:
        lda fall_delay                  ; reset fall delay - player could have
        sta delay_counter               ; dropped a block so need to make it slow
        sta fall_speed                  ; again.

        ldx #21                         ; prepare to erase existing next_block
        ldy #3
        stx block_x_position
        sty block_y_position
        lda next_block_id
        pha                             ; save existing next block ID
        jsr select_block                ; erase the next_block
        jsr erase_block

        jsr get_random                  ; get new next_block
        sta next_block_id               ; store new next_block

        jsr select_block                ; print new next_block
        jsr print_block

        ldx #10                         ; prepare to display new falling block
        ldy #1                          ; (old next_block)
        stx block_x_position
        sty block_y_position
        pla                             ; restore the old next_block
        sta current_block_id
        jsr select_block                ; check if space to position new falling
        jsr check_space                 ; block
        bne :+
        jsr print_block                 ; there is space, print it.
        lda #0
        rts                             ; return with 0 in A to indicate all OK
:       jsr print_block                 ; no space - print block anyway
        lda #1                          ; return with 1 in A to indicate no space
        rts                             ; which will result in game over condition.

;------------------------------------------------------------------------------
; use the prng routine to get a random number between 0 and 7
; OUTPUT: A conains number
;------------------------------------------------------------------------------
get_random:
        jsr prng
        and #$07                        ; keep only bottom 3 bits (7)
        cmp #$07                        ; is it 7, yes then try again.
        bne :+
        jmp get_random
:       rts

;------------------------------------------------------------------------------
; Check key pressed and action accordingly.
; INPUT: pressed_key
; OUTPUT: A contains $FF if user pressed ESCAPE
;------------------------------------------------------------------------------
get_key_inputs:
        lda pressed_key

        cmp #K_RETURN                   ; Handle PAUSE
        bne :+
        lda pause_flag
        eor #%00000001
        sta pause_flag
        jmp @return

:       cmp #K_LEFT                     ; Handle move left
        bne :++
        jsr erase_block                 ; clear block
        dec block_x_position            ; move the block left
        jsr check_space                 ; check space in new location
        beq :+                          ; was there space?
        inc block_x_position            ; no - move block back
:       jmp @return                     ; yes - carry on.

:       cmp #K_RIGHT                    ; Handle move right
        bne :++
        jsr erase_block                 ; clear block
        inc block_x_position            ; move block right
        jsr check_space                 ; check space in new location
        beq :+                          ; was there space?
        dec block_x_position            ; no - move block back
:       jmp @return                     ; yes - carry on.

:       cmp #K_A                        ; Handle rotate CCW
        bne :++
        jsr erase_block                 ; erase block
        lda #$01                        ; rotate the block
        jsr animate_block
        jsr check_space                 ; is there space for rotated block?
        beq :+                          ; was there space?
        lda #$00                        ; no - rotte block back
        jsr animate_block
:       jmp @return                     ; yes - carry on.

:       cmp #K_D                        ; Handle rotate CW
        bne :++
        jsr erase_block                 ; clear block
        lda #$00                        ; rotate the block
        jsr animate_block
        jsr check_space                 ; is there space for rotate block?
        beq :+
        lda #$01                        ; no - rotate block back
        jsr animate_block
:       jmp @return                     ; yes - carry on.

:       cmp #K_DOWN                     ; Handle move down
        bne :++
        jsr erase_block                 ; clear block
        inc block_y_position            ; move block down 1 row
        jsr check_space                 ; is there space in new location
        beq :+
        dec block_y_position            ; no  - move it up again.
:       jmp @return                     ; yes - carry on

:       cmp #K_SPACE                    ; handle drop block.
        bne :+
        lda #1                          ; increase the fall speed to very fast
        sta fall_speed 
        jmp @return

:       cmp #K_ESCAPE                   ; handle quit
        bne @return
        lda #$FF
        rts
@return:
        jsr print_block                 ; now that new block position is set,
@no_key:                                ; place it in shadow ram.
        rts

;------------------------------------------------------------------------------
; Fall the block by one row.
; OUTPUT: A = 0, no collision, A=1, collided!
;------------------------------------------------------------------------------
fall:
        jsr erase_block                 ; clear block
        inc block_y_position            ; move it down one row 
        jsr check_space                 ; check for space in new position
        beq @return                     ; sapce exists - jump to return
        dec block_y_position            ; no space, move back
        jsr print_block                 ; print block in old space
        lda #1                          ; A = 1 when block collided.
        rts
@return:
        jsr print_block                 ; print block in new space
        lda #0                          ; A = 0 when no collision.
        rts

;------------------------------------------------------------------------------
; Check for filled lines.  Call if the `fall` routine returned a 1 in the ACCUM.
; and before calling `new_block`
; XXX - TODO: Integrate level handling into this routine.
;------------------------------------------------------------------------------
check_lines:
        stz lines_made                  ; reset count of made lines.
        lda #$01                        ; the current row is one below the top.
        sta current_row                 ; start checking for complete lines at
        ldx #7                          ; row 1 (below the top border)
        ldy #1
        stx block_x_position            ; set screen pointer to top left cnr of
        sty block_y_position            ; play field
        jsr set_vidram_position         

@read_start:                            ; loop through the cells in a row and
        ldy #0                          ; check for spaces.
@read_loop:
        lda (scr_ptr),y                 ; read char at scr_ptr, y
        cmp #$20                        ; is it a space?
        beq @next_row                   ; yes - go to next row down.
        iny                             ; inc column
        cpy #12                         ; have we checked 12 columns 
        bne @read_loop                  ; no - keep going
        
        ldy lines_made                  ; we have checked all 12 cells in the row
        lda current_row                 ; and no spaces were found.  Save the row number
        sta line_row_numbers, y         ; intp the line_row_numbers array.

        inc lines_made                  ; increment count of completed lines.
        lda lines_made                  ; have we completed 4 lines?
        cmp #4
        beq @read_done                  ; yes - we are done checking.
@next_row:
        inc current_row                 ; move current row down.
        lda current_row
        cmp #23                         ; have we checked all the way to the bottom
        beq @read_done                  ; yes - we are done.
        jsr down_row                    ; no - move the screen pointer to the next row 
        jmp @read_start                 ; back to read start.
@read_done:
        lda lines_made                  ; return the number of lines made.
        rts

;------------------------------------------------------------------------------
; starting at the first made line from the top, move all lines above it into
; that row.  Keep doing for all lines made.
;------------------------------------------------------------------------------
remove_lines:
        lda #$00                        ; reset current line index
        sta current_line_index
set_pointers:
        ldx current_line_index          ; find the made line indexed by x 
        lda line_row_numbers,x
        tay                             ; that's now Y for set_line_pointers.
        jsr set_line_pointers           ; set up the line pointers used to copy
        jsr move_line_data              ; data - call the row copy routine. 
        inc current_line_index          ; increment the index 
        lda current_line_index          ; is our index the same as lines made?
        cmp lines_made                  ;
        bne set_pointers                ; no - do the next line made.
        rts                             ; return.

;------------------------------------------------------------------------------
; Sets up two pointers.  row and row - 1.  These are used to copy data from
; row - 1 into row.
; INPUT: Y Must be set before starting.  this is going to be the row that was
; made and will be overwritten by the row above it.
;------------------------------------------------------------------------------
set_line_pointers:
        ldx #7                          ; 7 is the left of the play field
        dey                             ; go up one row
        stx block_x_position            ; set up pointer.
        sty block_y_position
        jsr set_vidram_position
        lda scr_ptr                     ; copy pointer to ptr 2
        sta scr_ptr2
        lda scr_ptr + 1
        sta scr_ptr2 + 1
        jsr down_row                    ; down row - this resets ptr to original
        rts                             ; location.

;------------------------------------------------------------------------------
; Copy the data from ptr 2 to ptr 1 for a row.  Keep doing for all rows above 
;------------------------------------------------------------------------------
move_line_data:
        ldy current_line_index          ; use the current line index to find 
        lda line_row_numbers,y          ; the row to work on from the array.
        tax                             ; save the row in X
@start_loop:
        ldy #0                          ; reset column number
@loop:
        lda (scr_ptr2),y                ; copy from row above to row below at
        sta (scr_ptr),y                 ; column Y 
        iny
        cpy #12                         ; have we done 12 columns 
        bne @loop                       ; no - keep going
        dex                             ; decrement the row - this is how we
        beq @done_moving                ; do all rows above. if we get to 0. we 
                                        ; are done.
        txa                             ; use the new row number to figure out
        tay                             ; the new pointers. 
        pha                             ; save row number 
        jsr set_line_pointers           ; set new pointers. 
        pla                             ; restore row number and save to x 
        tax
        jmp @start_loop                 ; do the whole thing again.
@done_moving: 
        ldx #7                          ; reset vidram position for empty line.
        ldy #1
        stx block_x_position
        sty block_y_position
        jsr set_vidram_position
        ldy #0                          ; do 12 sapces at top row.
        lda #$20
@clear_line_loop:
        sta (scr_ptr),y
        iny
        cpy #12
        bne @clear_line_loop
@exit:
        rts

;------------------------------------------------------------------------------
; Select block to display - configure first and last frames.  References the
; block_frame_start and block_frame_end arrays.
; INPUT : A contains block ID to set up.
;------------------------------------------------------------------------------
select_block:
        sta current_block_id            
        tax
        lda block_frame_start,x         ; set the first frame of the block
        sta current_frame
        sta first_frame
        lda block_frame_end,x           ; set the last frame of the block
        sta last_frame
        rts

;------------------------------------------------------------------------------
; Set the current frame for a block based on direction indicated by A.  Loops
; from end to start or start to end depending on direction.
; INPUT : A=0, clockwise B=1, counter clockwise
;------------------------------------------------------------------------------
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

;------------------------------------------------------------------------------
; Translate the block_x_position and block_y_position values into an address
; in vidram.
; INPUT: block_x_position, block_y_position
; OUTPUT: scr_ptr - pointer to address in vidram.
;------------------------------------------------------------------------------
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

;------------------------------------------------------------------------------
; Print the current frame to vidram at position pointed to by scr_ptr.
; scr_ptr is set by defining values for block_x_position and block_y_position
; then calling set_vidram_position.
; This routine ignores unset cells in the frame to avoid overwriting other blocks
; on the dispaly.
;------------------------------------------------------------------------------
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
        jsr down_row            ; move scr_ptr to row directly below
        ldy #$00
        jmp print_loop

;------------------------------------------------------------------------------
; Prints spaces for each set cell in the current frame to vidram at position 
; pointed to by scr_ptr. scr_ptr is set by defining values for block_x_position 
; and block_y_position then calling set_vidram_position.
; This routine ignores unset cells in the frame to avoid overwriting other blocks
; on the dispaly.
;------------------------------------------------------------------------------
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
        lda #$20                ; print a space to overwrite set cells.
        sta (scr_ptr),y
:       inx
        cpx #16
        bne :+
        rts
:       iny
        cpy #$04
        bne erase_loop
        jsr down_row            ; move scr_ptr to row directly below.
        ldy #$00
        jmp erase_loop

;------------------------------------------------------------------------------
; checks existing cells for a frame at current position for any characters.
; if any non empty cells are found, the routine returns with A=1.  Else if
; location is empty, it returns with A=0
; OUTPUT: A=0 - space is free, A=1 - space is not free.
;------------------------------------------------------------------------------
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

;------------------------------------------------------------------------------
; update scr_ptr to point to memory location at row directly below current.
;------------------------------------------------------------------------------
down_row:
        lda scr_ptr
        clc
        adc #32
        bcc :+
        inc scr_ptr + 1
:       sta scr_ptr
        rts

;------------------------------------------------------------------------------
; Copy entire contents of vidram into the VDP nametable.  This routine is called
; whenever the screen needs to be updated.  Usually at the end of the gameloop
; or when some asyncrhonous event has happened, like at start of game or end
; of game to display messages that have been staged into vidram.
; XXX - TODO: Investigate if this can be synced with VDP Sync interrupt.
;               so far that's proven buggy.  Perhaps because 2mhz is too slow?
;------------------------------------------------------------------------------
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
        vdp_delay_fast                  ; might be a bit risky.
        iny
        bne @loop
        inc vdp_ptr + 1
        dex
        bne @page
        rts

;------------------------------------------------------------------------------
; Clear all cells in vidram with a 00.
;------------------------------------------------------------------------------
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

;------------------------------------------------------------------------------
; write the map data to vidram.  Positions the map at x=6.  Map is 22 chars
; wide.
;------------------------------------------------------------------------------
draw_map:
        lda #<vidram
        sta vdp_ptr
        lda #>vidram
        sta vdp_ptr + 1
        clc
        lda vdp_ptr
        adc #$6                        ; shift map over by 6
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
        cpx #21                         ; when reach end of row, reset and move 
        beq :+                          ; down to start of next row.
        jmp @loop
:       ldx #0
        clc
        lda vdp_ptr
        adc #11                         ; (21 + 11) % 32 = 0 - IE, next row in vidram
        sta vdp_ptr
        bcc :+
        inc vdp_ptr + 1
:       jmp @loop
@return:
        rts

;------------------------------------------------------------------------------
; in graphics 1 mode the VDP assigns a single colour to 8 characters in the 
; name table.  The color table at the end of this script, defines the colors
; for the map border, text and falling blocks.
;------------------------------------------------------------------------------
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

;------------------------------------------------------------------------------
; Game variables in high memory
;------------------------------------------------------------------------------
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

;------------------------------------------------------------------------------
; Static game data.
;------------------------------------------------------------------------------
        .rodata
; each block defines a number of frames.  These two arrays define the start
; and end frames for each block.
block_frame_start:
        .byte 0, 1, 3, 5, 7, 11, 15
block_frame_end:
        .byte 0, 2, 4, 6, 10, 14, 18

; the low and high bytes of the memory addresses for each frame are defined
; in this lookup table.  For example: If we need to show frame 0 of block 4,
; we look at the 4th index in block_frame_start and get 7.  We then use this 
; as an inded into block_aray_lo and block_array_hi to get the low and high bytes
; of the start of the 16 byte block.  for index 5 this is <b4f0 and >b4f0.
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

; 4x4 blocks. $20 is a space, $91 is the character for the block.  Look in
; common/res/font.asm for the actual pattern.
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

; MAP data.  These characters are all defined in common/res/font.asm.
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

; color definitions for each group of 8 characters in the VDP Name table.
colors:
        .byte $fb,$f1,$f1,$f1,$f1,$f1,$f1,$f1   ; 00 - 3F
        .byte $f1,$f1,$f1,$f1,$f1,$f1,$f1,$f1   ; 40 - 7F
        .byte $f1,$f1,$31,$f4,$f4,$f4,$f4,$f4   ; 80 - BF
        .byte $f6,$f4,$f4,$f4,$f4,$f4,$f4,$f4   ; C0 - FF
end_colors:

; static strings.
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

; PSG Sound chip control bytes in VGM format.  The kernel includes a VGM player
; library that will send the bytes in sequence to the PSG until the end of stream
; byte ($66) is reached.  We use this to both set up the chip as well as play
; sound effects.

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