        .include "console.inc"
        .include "console_macros.inc"
        .include "zeropage.inc"
        .include "sysram.inc"
        .include "vdp.inc"
        .include "vdp_macros.inc"

        .import __TMS_START__
VDP_VRAM                = __TMS_START__ + $00   ; TMS Mode 0
VDP_REG                 = __TMS_START__ + $01   ; TMS Mode 1
VDP_NAME_TABLE          = $1400

K_LEFT                  = $A1
K_RIGHT                 = $A2
K_DOWN                  = $A4
K_A                     = 'a'
K_D                     = 'd'
K_SPACE                 = ' '
K_RESET                 = $0D   ; ENTER
K_ESCAPE                = $1b   ; ESCAPE

INPUT_DELAY             = 10

scr_ptr = $e0
cur_block = $e2

vidram = $6000

        .code

        jsr _vdp_reset
        vdp_con_g1_mode
        jsr clear_vidram
        
        ; test
        lda #10
        sta block_x_position
        lda #05
        sta block_y_position
        jsr set_vidram_position
        lda #$0
        jsr select_block
        jsr print_block
game_loop:
        jsr set_vidram_position
        jsr erase_block
        jsr get_key_inputs
        bcs exit
        jsr set_vidram_position
        jsr print_block
        jsr paint_vidram
        jmp game_loop
exit:
        rts

; blocks while waiting for keypress
; ascii of pressed key returned in A
wait_for_key:
        jsr _con_in
        bcc wait_for_key
        rts

get_key_inputs:
        lda #0
        jsr _con_in
        bcc @return
        cmp #K_SPACE
        bne :+
        lda pause_flag
        eor #%00000001
        sta pause_flag
        bra @return
:       cmp #K_LEFT
        bne :+
        dec block_x_position
        bra @return
:       cmp #K_RIGHT
        bne :+
        inc block_x_position
        bra @return
:       cmp #K_A
        bne :+
        lda #$01
        jsr animate_block
        bra @return
:       cmp #K_D
        bne :+
        lda #$00
        jsr animate_block
        bra @return
:       cmp #K_DOWN
        bne :+
        inc block_y_position
        bra @return
:       cmp #K_RESET
        bne :+
        lda current_block_id
        inc a
        jsr select_block
        bra @return
:       cmp #K_ESCAPE
        bne @return
        sec
        rts
@return:
        clc
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
        vdp_delay_slow
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
        lda #$20
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
; data
block_x_position:       .byte 0
block_y_position:       .byte 0
current_block_id:       .byte 0
current_frame:          .byte 0
first_frame:            .byte 0
last_frame:             .byte 0
delay_counter:          .byte 0
pause_flag:             .byte 0

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
        .byte "    "
        .byte " @@ "
        .byte " @@ "
        .byte "    "
b1f0:           ; long 0        =1
        .byte "    "
        .byte "@@@@"
        .byte "    "
        .byte "    "
b1f1:           ; long 1        =2
        .byte "  @ "
        .byte "  @ "
        .byte "  @ "
        .byte "  @ "
b2f0:           ; S 0           =3
        .byte "    "
        .byte "  @@"
        .byte " @@ "
        .byte "    "
b2f1:           ; S 1           =4
        .byte " @  "
        .byte " @@ "
        .byte "  @ "
        .byte "    "
b3f0:           ; Z 0           =5
        .byte "@@  "
        .byte " @@ "
        .byte "    "
        .byte "    "
b3f1:           ; Z 1m          =6
        .byte "  @ "
        .byte " @@ "
        .byte " @  "
        .byte "    "
b4f0:           ; L 0           =7
        .byte " @  "
        .byte " @  "
        .byte " @@ "
        .byte "    "
b4f1:           ; L 1           =8
        .byte "    "
        .byte "@@@ "
        .byte "@   "
        .byte "    "
b4f2:           ; L 2           =9
        .byte " @@ "
        .byte "  @ "
        .byte "  @ "
        .byte "    "
b4f3:           ; L 3           =10
        .byte "  @ "
        .byte "@@@ "
        .byte "    "
        .byte "    "
b5f0:           ; J 0           =11
        .byte "  @ "
        .byte "  @ "
        .byte " @@ "
        .byte "    "
b5f1:           ; J 1           =12
        .byte "    "
        .byte "@   "
        .byte "@@@ "
        .byte "    "
b5f2:           ; J 2           =13
        .byte " @@ "
        .byte " @  "
        .byte " @  "
        .byte "    "
b5f3:           ; J 3           =14
        .byte "    "
        .byte "@@@ "
        .byte "  @ "
        .byte "    "
b6f0:           ; T 0           =15
        .byte " @@@"
        .byte "  @ "
        .byte "    "
        .byte "    "
b6f1:           ; T 1           =16
        .byte "   @"
        .byte "  @@"
        .byte "   @"
        .byte "    "
b6f2:           ; T 2           =17
        .byte "    "
        .byte "  @ "
        .byte " @@@"
        .byte "    "
b6f3:           ; T 3           =18
        .byte " @  "
        .byte " @@ "
        .byte " @  "
        .byte "    "
