; snake game
        .include "console.inc"
        .include "console_macros.inc"
        .include "zeropage.inc"
        .include "vdp.inc"
        .include "vdp_macros.inc"
        .include "math.inc"
        .include "sysram.inc"

        .import __TMS_START__
VDP_VRAM                = __TMS_START__ + $00   ; TMS Mode 0
VDP_REG                 = __TMS_START__ + $01   ; TMS Mode 1
VDP_NAME_TABLE          = $1400
;------------------------------------------------------------------------------
; Constants
;------------------------------------------------------------------------------
ZEROPAGE_START  = $E0
ZEROPAGE_END    = $FF

HIGH_MEM_START  = $4000
HIGH_MEM_END    = $5000

head_char       = '@'

dir_up          = %00000001
dir_rt          = %00000010
dir_dn          = %00000100
dir_lt          = %00001000

collide_none    = %00000000     ; 0
collide_wall    = %00000001     ; 1
collide_tail    = %00000010     ; 2
collide_apple   = %00000100     ; 4

;------------------------------------------------------------------------------
; Variables - Zeropage
;------------------------------------------------------------------------------
head_x          = ZEROPAGE_START + 0    ; 1 byte                E0
head_y          = head_x + 1            ; 1 byte                E1
body_ptr_head   = head_y + 1            ; 2 bytes               E2
body_ptr_head_h = body_ptr_head + 1     ;                       E3
body_ptr_tail   = body_ptr_head_h + 1   ; 2 bytes               E4
body_ptr_tail_h = body_ptr_tail + 1     ;                       E5
length          = body_ptr_tail_h + 1   ; 2 bytes               E6
length_h        = length + 1            ;                       E7
seed            = length_h + 1          ; 1 byte                E8
direction       = seed + 1              ; 1 byte                E9
collide_state   = direction + 1         ; 1 byte                EA
more_segments   = collide_state + 1     ; 1 byte                EB

;------------------------------------------------------------------------------
; Variables - High mem
;------------------------------------------------------------------------------
body_buf        = HIGH_MEM_START + 0
body_buf_end    = HIGH_MEM_START + $600 ; total size of screen area x 2

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
        lda #15                         ; start snake in middle of screen
        sta head_x
        lda #11
        sta head_y
        lda #20
        sta length
        sta more_segments
        
        stz collide_state

        stz body_ptr_head
        stz body_ptr_tail
        lda #$14
        sta body_ptr_head_h
        sta body_ptr_head_h
        sta body_ptr_tail_h

;------------------------------------------------------------------------------
; Start of game.  Generate random seed
;------------------------------------------------------------------------------
start:
        jsr _vdp_clear_screen
        snake_print 6, 10, str_welcome

        jsr gen_seed                    ; wait for player to hit a key to start

        lda #dir_rt
        sta direction

        jsr _vdp_clear_screen
;------------------------------------------------------------------------------
; Main game loop
;------------------------------------------------------------------------------
game_loop:
        jsr read_keys
        bcs @exit
        jsr update_snake
        jsr check_collisions
        bcs @exit
        jsr draw_snake
        jsr delay
        jmp game_loop
@exit:
        jmp exit_game

;------------------------------------------------------------------------------
; Checks user input buffer for a keypress.  Looks to see which direction going
; sets new direction if not illegal move. (can not reverse in snake)
;------------------------------------------------------------------------------
read_keys:
        jsr _con_in
        bcc @return
        cmp #$1b                        ; ESC
        bne :+
        sec
        rts
:       cmp #$A1                        ; LEFT
        bne :+
        lda direction
        cmp #dir_rt
        beq @return                     ; illegal move
        lda #dir_lt
        sta direction
:       cmp #$A2                        ; RIGHT
        bne :+
        lda direction
        cmp #dir_lt
        beq @return                     ; illegal move
        lda #dir_rt
        sta direction
        jmp @return
:       cmp #$A3                        ; UP
        bne :+
        lda direction
        cmp #dir_dn
        beq @return                     ; illegal move
        lda #dir_up
        sta direction
        jmp @return
:       cmp #$A4                        ; DOWN
        bne @return
        lda direction
        cmp #dir_up
        beq @return                     ; illegal move
        lda #dir_dn
        sta direction
        ; fall through
@return:
        clc
        rts

;------------------------------------------------------------------------------
; Calculates new location of snake head based on new direction of snake
;------------------------------------------------------------------------------
update_snake:
        lda direction
        cmp #dir_up
        bne :+
        snake_print     0, 0, str_up
        dec head_y
        bra @return
:       cmp #dir_rt
        bne :+
        inc head_x
        snake_print     0, 0, str_rt
        bra @return
:       cmp #dir_dn
        bne :+
        inc head_y
        snake_print     0, 0, str_dn
        bra @return
:       cmp #dir_lt
        bne @return
        dec head_x
        snake_print     0, 0, str_lt

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

        ; check tail collision
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
        cmp #head_char
        beq @tail_collide
        ; fall through
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
@return:
        sec
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
        lda #$00
        sta VDP_VRAM
        vdp_delay_slow

        ; move tail pointer over by two
        inc body_ptr_tail
        inc body_ptr_tail
        lda body_ptr_tail
        bne @draw_head
        inc body_ptr_tail_h
        bra @draw_head
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
        lda #head_char
        sta VDP_VRAM
        vdp_delay_slow                  ; actually draw the head

        ; move head pointer over by two
        inc body_ptr_head
        inc body_ptr_head
        bne @return
        inc body_ptr_head_h
@return:
        rts

;------------------------------------------------------------------------------
; Return to monitor
;------------------------------------------------------------------------------
exit_game:
        rts
;------------------------------------------------------------------------------
; Delay game between frames
;------------------------------------------------------------------------------
delay:
        ldy #$80
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

        .rodata
str_welcome:    .asciiz "Press KEY to start"
str_up:         .asciiz "UP"
str_dn:         .asciiz "DN"
str_lt:         .asciiz "LT"
str_rt:         .asciiz "RT"
