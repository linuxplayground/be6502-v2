; snake game
        .include "console.inc"
        .include "console_macros.inc"
        .include "zeropage.inc"
        .include "vdp.inc"
        .include "vdp_macros.inc"
        .include "math.inc"
        .include "audiolib.inc"
        .include "sysram.inc"

        .import __TMS_START__
VDP_VRAM                = __TMS_START__ + $00   ; TMS Mode 0
VDP_REG                 = __TMS_START__ + $01   ; TMS Mode 1
VDP_NAME_TABLE          = $1400
VDP_COLOR_TABLE         = $2000
;------------------------------------------------------------------------------
; Constants
;------------------------------------------------------------------------------
ZEROPAGE_START  = $E0
ZEROPAGE_END    = $FF

HIGH_MEM_START  = $2000
HIGH_MEM_END    = $6000

head_up         = $80
head_rt         = $83
head_dn         = $82
head_lt         = $85

apple           = $90

dir_up          = %00000001
dir_rt          = %00000010
dir_dn          = %00000100
dir_lt          = %00001000

collide_none    = %00000000     ; 0
collide_wall    = %00000001     ; 1
collide_tail    = %00000010     ; 2

medium_green    = $03
speed_up_intrvl = 10            ; speed up the game every 10 apples

;------------------------------------------------------------------------------
; Variables - Zeropage
;------------------------------------------------------------------------------
head_x          = $E0    ; 1 byte                E0
head_y          = $E1
body_ptr_head   = $E2
body_ptr_head_h = $E3
body_ptr_tail   = $E4
body_ptr_tail_h = $E5
seed            = $E6
direction       = $E7
collide_state   = $E8
more_segments   = $E9
head_char       = $EA
speed_up        = $EB
speed_dly       = $EC
bin2dec_tmp     = $ED
score           = $EE
score_h         = $EF

;------------------------------------------------------------------------------
; Variables - High mem
;------------------------------------------------------------------------------
body_buf        = HIGH_MEM_START + 0
body_buf_end    = HIGH_MEM_END      ; AS MUCH AS POSSIBLE

;------------------------------------------------------------------------------
; Game macros
;------------------------------------------------------------------------------
;------------------------------------------------------------------------------
; Print a string (addr) at location px, py
;------------------------------------------------------------------------------
.macro snake_print px, py, addr
        ldx #px
        ldy #py
        jsr _vdp_xy_to_ptr
        vdp_ptr_to_vram_write_addr
        lda #<addr
        sta str_ptr
        lda #>addr
        sta str_ptr + 1
        jsr local_print
.endmacro

        .code

;------------------------------------------------------------------------------
; Main entry point of game - initialize the game
;------------------------------------------------------------------------------
entry:

        jsr _psg_init
        lda #<snd_init
        ldx #>snd_init
        jsr _play_vgm_data

        ; switch to graphics mode
        vdp_con_g1_mode
        ; audio
        
        ; setup game colours
        jsr setup_colors
        lda #15                         ; start snake in middle of screen
        sta head_x
        lda #11
        sta head_y
        lda #4
        sta more_segments

        stz collide_state

        stz body_ptr_head
        stz body_ptr_tail
        lda #>body_buf
        sta body_ptr_head_h
        sta body_ptr_tail_h

        lda #head_rt
        sta head_char

        lda #5                          ; number of apples before game gets faster
        sta speed_up
        lda #$C0
        sta speed_dly                   ; time of delay between game ticks.

        stz score
        stz score_h

;------------------------------------------------------------------------------
; Start of game.  Generate random seed
;------------------------------------------------------------------------------
start:
        jsr _vdp_clear_screen
        snake_print 1, 6, str_controls_1
        snake_print 1, 7, str_controls_2
        snake_print 1, 8, str_controls_3
        snake_print 1, 12, str_welcome

        jsr gen_seed                    ; wait for player to hit a key to start

        lda #dir_rt
        sta direction

        jsr _vdp_clear_screen
        jsr new_apple

;------------------------------------------------------------------------------
; Main game loop
;------------------------------------------------------------------------------
game_loop:
        jsr read_keys
        bcs game_over
        jsr update_snake
        jsr check_collisions
        bcs game_over
        jsr draw_snake
        jsr delay
        jmp game_loop
;------------------------------------------------------------------------------
; Convert score to decimal, display gameover message and score. 
;------------------------------------------------------------------------------
game_over:
        lda #<snd_crash
        ldx #>snd_crash
        jsr _play_vgm_data
        snake_print 1, 10, str_game_over
        snake_print 1, 12, str_score_txt
        ldx #17
        ldy #12
        jsr _vdp_xy_to_ptr
        vdp_ptr_to_vram_write_addr
        lda score_h
        jsr bcd_out_l
        lda score
        jsr bcd_out
        snake_print 1, 23, str_game_over_instr
@wait_for_key:
        jsr _con_in
        bcc @wait_for_key
        cmp #' '
        beq @restart
        cmp #$1b
        beq @exit_game
        jmp @wait_for_key
@restart:
        jmp entry
@exit_game:
        jmp exit_game
;------------------------------------------------------------------------------
; Checks user input buffer for a keypress.  Looks to see which direction going
; sets new direction if not illegal move. (can not reverse in snake)
;------------------------------------------------------------------------------
read_keys:
        jsr _con_in
        bcc @return
        cmp #$1b                        ; ESC
        bne @k_left
        sec
        rts
@k_left:
        cmp #$A1                        ; LEFT
        bne @k_right
        lda direction
        cmp #dir_lt
        bne :+
        jmp turn_down
:       cmp #dir_rt
        bne :+
        jmp turn_up
:       cmp #dir_up
        bne :+
        jmp turn_left
:       jmp turn_right
@k_right:
        cmp #$A2                        ; RIGHT KEY
        bne @return
        lda direction
        cmp #dir_lt
        bne :+
        jmp turn_up
:       cmp #dir_rt
        bne :+
        jmp turn_down
:       cmp #dir_up
        bne :+
        jmp turn_right
:       jmp turn_left
@return:
        clc
        rts
turn_up:
        lda #dir_up
        sta direction
        lda #head_up
        sta head_char
        clc
        rts
turn_down:
        lda #dir_dn
        sta direction
        lda #head_dn
        sta head_char
        clc
        rts
turn_left:
        lda #dir_lt
        sta direction
        lda #head_lt
        sta head_char
        clc
        rts
turn_right:
        lda #dir_rt
        sta direction
        lda #head_rt
        sta head_char
        clc
        rts

;------------------------------------------------------------------------------
; Calculates new location of snake head based on new direction of snake
;------------------------------------------------------------------------------
update_snake:
        lda direction
        cmp #dir_up
        bne @rt
        ; snake_print     0, 0, str_up
        dec head_y
        bra @return
@rt:    cmp #dir_rt
        bne @dn
        inc head_x
        ; snake_print     0, 0, str_rt
        bra @return
@dn:    cmp #dir_dn
        bne @lt
        inc head_y
        ; snake_print     0, 0, str_dn
        bra @return
@lt:    cmp #dir_lt
        bne @return
        dec head_x
        ; snake_print     0, 0, str_lt

@return:
        ; convert x,y location of head to VRAM Address and save to body_buffer
        ; at body_ptr_head
        ldy #1
        lda #>VDP_NAME_TABLE
        sta (body_ptr_head),y
        lda head_y
        div8
        clc
        adc (body_ptr_head),y
        sta (body_ptr_head),y
        lda head_y
        and #$07
        mul32
        ldy #0
        sta (body_ptr_head),y
        lda head_x
        ora (body_ptr_head),y
        sta (body_ptr_head),y

        rts

;------------------------------------------------------------------------------
; Checks if snake has collided with Wall, Apple or Tail
;------------------------------------------------------------------------------
check_collisions:
        ; check wall collision
        lda head_y
        cmp #$ff
        bmi @wall_collision
        cmp #24
        beq @wall_collision
        lda head_x
        cmp #$ff
        beq @wall_collision
        cmp #32
        beq @wall_collision

        ; check tail or apple collision
        ldy #0
        lda (body_ptr_head),y
        sta vdp_ptr
        iny
        lda (body_ptr_head),y
        sta vdp_ptr + 1
        vdp_ptr_to_vram_read_addr
        lda VDP_VRAM
        vdp_delay_slow
        cmp #' '
        beq @no_collide
        cmp #apple
        beq @apple_collide
        bra @tail_collide               ; we must have hit the tail.
@no_collide:
        lda #collide_none
        sta collide_state
        clc
        rts
@wall_collision:
        lda #collide_wall
        sta collide_state
        bra @return
@tail_collide:
        lda #collide_tail
        sta collide_state
        bra @return
@apple_collide:
        jmp eat_apple
@return:
        sec
        rts
;------------------------------------------------------------------------------
; Increments score, checks if game needs to run faster, generates new apple
;------------------------------------------------------------------------------
eat_apple:
        lda #<snd_eat
        ldx #>snd_eat
        jsr _play_vgm_data
        sed
        clc
        lda #1
        adc score
        sta score
        bcc :+
        lda #0
        adc score_h
        sta score_h
:       cld

        dec speed_up
        bne :+
        lda #speed_up_intrvl
        sta speed_up
        sec
        lda speed_dly
        beq :+                          ; if we ever get so fast, that we
        sbc #$10                        ; roll around the maxint, we just
        sta speed_dly                   ; quit speeding up.
        lda #<snd_lvl_up
        ldx #>snd_lvl_up
        jsr _play_vgm_data
:       jsr new_apple
        lda #2
        sta more_segments
        clc                             ; returns to game loop - need to clc.
        rts
;------------------------------------------------------------------------------
; Draws the snake head and body
;------------------------------------------------------------------------------
draw_snake:
        lda more_segments
        bne @dec_more_segments
        ; delete the tail
        ldy #0
        lda (body_ptr_tail),y
        sta vdp_ptr
        iny
        lda (body_ptr_tail),y
        sta vdp_ptr + 1
        vdp_ptr_to_vram_write_addr
        lda #' '
        sta VDP_VRAM
        vdp_delay_slow

        ; move tail pointer over by two
        inc body_ptr_tail
        inc body_ptr_tail
        lda body_ptr_tail
        bne @draw_head
        inc body_ptr_tail_h
        lda body_ptr_tail_h
        cmp #>body_buf_end
        bcc @draw_head
        lda #>body_buf_end
        sta body_ptr_tail_h
@dec_more_segments:
        dec more_segments
@draw_head:
        ; draw the head
        ldy #0
        lda (body_ptr_head),y
        sta vdp_ptr
        iny
        lda (body_ptr_head),y
        sta vdp_ptr + 1
        vdp_ptr_to_vram_write_addr
        lda head_char
        sta VDP_VRAM
        vdp_delay_slow                  ; actually draw the head

        ; move head pointer over by two
        inc body_ptr_head
        inc body_ptr_head
        bne @return
        inc body_ptr_head_h
        lda body_ptr_head_h
        cmp #>body_buf_end
        bcc @return
        lda #>body_buf_end
        sta body_ptr_head_h
@return:
        rts

;------------------------------------------------------------------------------
; Return to monitor
;------------------------------------------------------------------------------
exit_game:
        jsr _vdp_reset
        rts

;------------------------------------------------------------------------------
; Delay game between frames
;------------------------------------------------------------------------------
delay:
        ldy speed_dly
@loop1:
        ldx #0
@loop2:
        dex
        bne @loop2
        dey
        bne @loop1
        rts
;------------------------------------------------------------------------------
; Waits for a keypress and increments seed while waiting.
; Pressed key returned in A
;------------------------------------------------------------------------------
gen_seed:
        inc seed
        jsr _con_in
        bcc gen_seed
        rts
;------------------------------------------------------------------------------
; generates a new apple on the screen
; if screen location is already occupied, try again until empty space is found
;------------------------------------------------------------------------------
new_apple:
@get_rand_x:
        jsr prng
        and #$1f
        clc
        cmp #30
        bcs @get_rand_x
        cmp #1
        bcc @get_rand_x
        tax
@get_rand_y:
        jsr prng
        and #$17
        clc
        cmp #22
        bcs @get_rand_y
        cmp #1
        bcc @get_rand_y
        tay
        jsr _vdp_xy_to_ptr
        vdp_ptr_to_vram_read_addr
        lda VDP_VRAM
        vdp_delay_slow
        cmp #' '
        bne @get_rand_x
        vdp_ptr_to_vram_write_addr
        lda #apple
        sta VDP_VRAM
        vdp_delay_slow
        rts

;------------------------------------------------------------------------------
; Print null terminated string pointed to by str_ptr
;------------------------------------------------------------------------------
local_print:
        ldy #0
@loop:
        lda (str_ptr),y
        beq @return
        jsr _vdp_put
        iny
        jmp @loop
@return:
        rts

;------------------------------------------------------------------------------
; Print 1 byte BCD value
;------------------------------------------------------------------------------
bcd_out:
        pha
        .repeat 4
        lsr
        .endrepeat
        ora #'0'
        sta VDP_VRAM
        pla
bcd_out_l:
        and #$0f
        ora #'0'
        sta VDP_VRAM
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
; -----------------------------------------------------------------------------
; Initialise the color table.
; -----------------------------------------------------------------------------
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

colors:
        .byte $f4,$71,$71,$71,$71,$71,$71,$71   ; 00 - 3F
        .byte $71,$71,$71,$71,$71,$71,$71,$71   ; 40 - 7F
        .byte $f1,$f1,$31,$f4,$f4,$f4,$f4,$f4   ; 80 - BF
        .byte $f6,$f4,$f4,$f4,$f4,$f4,$f4,$f4   ; C0 - FF
end_colors:

; ay sound bytes, vgm format
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

str_welcome:    .asciiz "    PRESS ANY KEY TO START     "
str_controls_1: .asciiz " USE LEFT AND RIGHT ARROW KEYS "
str_controls_2: .asciiz " TO STEER SNAKE LEFT AND RIGHT "
str_controls_3: .asciiz "RELATIVE TO DIRECTION OF TRAVEL"

str_game_over:  .asciiz "          GAME OVER            "
str_game_over_instr: 
                .asciiz "SPACE = RESTART,  ESCAPE = QUIT"
str_score_txt:  .asciiz "          SCORE:"
