        .include "via.inc"
        .include "zeropage.inc"
        .include "sysram.inc"
        .include "utils.inc"

        .export _kbd_init
        .export _kbd_isr

; keyboard flags and bits
KBDON        = %00001000
KBDOFF       = %11110111

KBD_R_FLAG   = %00000001
KBD_S_FLAG   = %00000010
KBD_C_FLAG   = %00000100

; keyboard macros
.macro next_code_up
        lda #(KBDON)
        ora VIA_PORTB
        sta VIA_PORTB
.endmacro
.macro next_code_down
        lda #(KBDOFF)
        and VIA_PORTB
        sta VIA_PORTB
.endmacro
.macro readkey
        next_code_up
        lda #1
        jsr _delay_ms
        lda VIA_PORTA
        pha
        next_code_down
        pla
.endmacro

        .code
_kbd_init:
        ; set port A as input (for keyboard reading)
        lda #$00
        sta VIA_PORTA
        lda #$00
        sta VIA_DDRA
        ; set up VIA Interrupts for keyboard (CA1 rising edge)
        lda #$82
        sta VIA_IER
        lda #$00
        sta VIA_PCR
        ; set up pin for kbd next code
        lda VIA_DDRB
        ora #KBDON
        sta VIA_DDRB

        stz kbd_flags
        rts

; keyboard handler ISR
_kbd_isr:
        pha
        phx

        lda kbd_flags
        and #(KBD_R_FLAG)       ; check if we are releasing a key
        beq @read_key           ; otherwise read the key

        lda kbd_flags           ; flip the releasing bit
        eor #(KBD_R_FLAG)
        sta kbd_flags
        readkey                 ; read the value that's being released
        cmp #$12                ; left shift up
        beq @shift_up
        cmp #$59                ; right shift up
        beq @shift_up

        jmp @exit

@shift_up:
        lda kbd_flags
        eor #(KBD_S_FLAG)       ; flip the shift bit
        sta kbd_flags
        jmp @exit
@read_key:
        readkey
        cmp #$f0                ; if releasing a key
        beq @key_release
        cmp #$12                ; left shift
        beq @shift_down
        cmp #$59                ; right shift
        beq @shift_down

        tax
        lda kbd_flags
        and #(KBD_S_FLAG)       ; check if shif it currently down
        bne @shifted_key

        lda keymap_l,x          ; fetch ascii from keymap lowercase
        jmp @push_key
@shifted_key:
        lda keymap_u,x          ; fetch ascii from keymap uppercase
        ; fall through
@push_key:
        ldx con_w_idx           ; use the write pointer to save the ascii
        sta con_buf,x        ; char into the buffer
        inc con_w_idx
        jmp @exit
@shift_down:
        lda kbd_flags
        ora #(KBD_S_FLAG)
        sta kbd_flags
        jmp @exit
@key_release:
        lda kbd_flags
        ora #(KBD_R_FLAG)
        sta kbd_flags
@exit:
        plx
        pla
        rts

keymap_l:
    .byte "?????",$81,$82,$8c,"?",$8a,"??? `?" ; 00-0F
    .byte "?????q1???zsaw2?" ; 10-1F
    .byte "?cxde43?? vftr5?" ; 20-2F
    .byte "?nbhgy6???mju78?" ; 30-3F
    .byte "?,kio09??./l;p-?" ; 40-4F
    .byte "??'?[=????",$0d,"]?\??" ; 50-5F
    .byte "??????",$08,"??1?47???" ; 60-6F
    .byte "0.2568",$1b,"?",$8b,"+3-*9??" ; 70-7F
    .byte "????????????????" ; 80-8F
    .byte "????????????????" ; 90-9F
    .byte "????????????????" ; A0-AF
    .byte "????????????????" ; B0-BF
    .byte "????????????????" ; C0-CF
    .byte "????????????????" ; D0-DF
    .byte "????????????????" ; E0-EF
    .byte "????????????????" ; F0-FF
keymap_u:
    .byte "????????????? ~?" ; 00-0F
    .byte "?????Q!???ZSAW@?" ; 10-1F
    .byte "?CXDE#$?? VFTR%?" ; 20-2F
    .byte "?NBHGY^???MJU&*?" ; 30-3F
    .byte "?<KIO)(??>?L:P_?" ; 40-4F
    .byte "??",$22,"?{+?????}?|??" ; 50-5F
    .byte "?????????1?47???" ; 60-6F
    .byte "0.2568",$80,"??+3-*9??" ; 70-7F
    .byte "????????????????" ; 80-8F
    .byte "????????????????" ; 90-9F
    .byte "????????????????" ; A0-AF
    .byte "????????????????" ; B0-BF
    .byte "????????????????" ; C0-CF
    .byte "????????????????" ; D0-DF
    .byte "????????????????" ; E0-EF
    .byte "????????????????" ; F0-FF