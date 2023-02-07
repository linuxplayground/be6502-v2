        .include "via.inc"
        .include "zeropage.inc"
        .include "sysram.inc"
        .include "utils.inc"
        .include "wozmon.inc"
        .include "init.inc"

        .export _kbd_init
        .export _kbd_isr

; keyboard flags and bits
KBDON        = %00001000
KBDOFF       = %11110111

KBD_R_FLAG   = %00000001
KBD_S_FLAG   = %00000010
KBD_C_FLAG   = %00000100
KBD_CL_FLAG  = %00001000

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
        lda #$00                ; via is input
        sta VIA_DDRA
        lda VIA_PORTA
        pha
        lda #$FF                ; via is output
        sta VIA_DDRA
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
        cmp #$58                ; CAPSLOCK
        beq @capslock_up
        jmp @exit

@capslock_up:
        lda kbd_flags
        eor #(KBD_CL_FLAG)
        sta kbd_flags
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

@filter:
        cmp #$E0
        beq @exit
        cmp #$E1                ; this is the only key that starts with E1
        beq @break
        cmp #$58                ; we don't care if capslock is being pressed, only released.
        beq @exit

        tax
        lda kbd_flags
        and #(KBD_CL_FLAG)
        bne @shifted_key
        and #(KBD_S_FLAG)       ; check if shif it currently down
        bne @shifted_key

        lda keymap_l,x          ; fetch ascii from keymap lowercase
        jmp @push_key
@shifted_key:
        lda keymap_u,x          ; fetch ascii from keymap uppercase
        ; fall through
@push_key:
        ldx con_w_idx           ; use the write pointer to save the ascii
        sta con_buf,x           ; char into the buffer
        inc con_w_idx
        jmp @exit
@break:
        jsr _wozmon             ; if we hit the pause key - go straight into wozmon
        plp
        jmp menu                ; hard reset

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
        rts

; Function keys are ASCII $81 to $8C (F1 - F12)
; ALT = $90
; SHIFT (L + R) = $91
; CTRL (L + R) = $92
; CAPS LOCK = $93
; END = $94
; HOME = $95
; INSERT = $96
; PRINTSCR = $97
; PAGE DOWN = $98
; PAGE UP = $99
; SCROLL LOCK = $9A

; LEFT = $A1
; RIGHT = $A2
; UP = $A3
; DOWN = $A4

; PAUSE = IMMEDIATE ON E1 SCAN CODE

keymap_l:
        ;   ASCII       SCAN CODE
        .byte $00       ; 00 
        .byte $89       ; 01 F9
        .byte $00       ; 02
        .byte $85       ; 03 F5
        .byte $83       ; 04 F3
        .byte $81       ; 05 F1
        .byte $82       ; 06 F2
        .byte $8C       ; 07 F12
        .byte $00       ; 08
        .byte $8A       ; 09 F10
        .byte $88       ; 0A F8
        .byte $86       ; 0B F6
        .byte $84       ; 0C F4
        .byte $09       ; 0D TAB
        .byte "`"       ; 0E BACKTICK
        .byte $00       ; 0F

        .byte $00       ; 10
        .byte $90       ; 11 LEFT ALT / E0 + RIGHT ALT
        .byte $91       ; 12 LEFT SHIFT
        .byte $00       ; 13
        .byte $92       ; 14 LEFT CONTROL / E0 + RIGHT CONTROL
        .byte "q"       ; 15 Q
        .byte "1"       ; 16 1
        .byte $00       ; 17 
        .byte $00       ; 18
        .byte $00       ; 19
        .byte "z"       ; 1A Z
        .byte "s"       ; 1B S
        .byte "a"       ; 1C A
        .byte "w"       ; 1D W
        .byte "2"       ; 1E 2
        .byte $00       ; 1F 

        .byte $00       ; 20
        .byte "c"       ; 21 C
        .byte "x"       ; 22 X
        .byte "d"       ; 23 D
        .byte "e"       ; 24 E
        .byte "4"       ; 25 4
        .byte "3"       ; 26 3
        .byte $00       ; 27 
        .byte $00       ; 28
        .byte " "       ; 29 SPACE
        .byte "v"       ; 2A V
        .byte "f"       ; 2B F
        .byte "t"       ; 2C T
        .byte "r"       ; 2D R
        .byte "5"       ; 2E 5
        .byte $00       ; 2F 

        .byte $00       ; 30 
        .byte "n"       ; 31 N
        .byte "b"       ; 32 B
        .byte "h"       ; 33 H
        .byte "g"       ; 34 G
        .byte "y"       ; 35 Y
        .byte "6"       ; 36 6
        .byte $00       ; 37 
        .byte $00       ; 38
        .byte $00       ; 39
        .byte "m"       ; 3A M
        .byte "j"       ; 3B J
        .byte "u"       ; 3C U
        .byte "7"       ; 3D 7
        .byte "8"       ; 3E 8
        .byte $00       ; 3F 

        .byte $00       ; 40
        .byte ","       ; 41 ,
        .byte "k"       ; 42 K
        .byte "i"       ; 43 I
        .byte "o"       ; 44 O
        .byte "0"       ; 45 0
        .byte "9"       ; 46 9
        .byte $00       ; 47 
        .byte $00       ; 48
        .byte "."       ; 49 .
        .byte "/"       ; 4A /
        .byte "l"       ; 4B L
        .byte ";"       ; 4C ;
        .byte "p"       ; 4D P
        .byte "-"       ; 4E -
        .byte $00       ; 4F 

        .byte $00       ; 50
        .byte $00       ; 51
        .byte "'"       ; 52 '
        .byte $00       ; 53 
        .byte "["       ; 54 [
        .byte "="       ; 55 =
        .byte $00       ; 56 
        .byte $00       ; 57
        .byte $93       ; 58 CAPS LOCK
        .byte $92       ; 59 RIGHT SHIFT
        .byte $0D       ; 5A ENTER
        .byte "]"       ; 5B ]
        .byte $00       ; 5C 
        .byte $5C       ; 5D \
        .byte $00       ; 5E 
        .byte $00       ; 5F

        .byte $00       ; 60
        .byte $00       ; 61
        .byte $00       ; 62
        .byte $00       ; 63
        .byte $00       ; 64
        .byte $00       ; 65
        .byte $08       ; 66 BACK SPACE
        .byte $00       ; 67 
        .byte $00       ; 68
        .byte $94       ; 69 KEYPAD 1 / EO + END
        .byte $00       ; 6A 
        .byte $A1       ; 6B KEYPAD 4 / E0 + CURSOR LEFT
        .byte $95       ; 6C KEYPAD 7 / E0 + HOME
        .byte $00       ; 6D 
        .byte $00       ; 6E
        .byte $00       ; 6F
        
        .byte $96       ; 70 KEYPAD 0 / E0 + INSERT
        .byte $7F       ; 71 KEYPAD . / E0 + DELETE
        .byte $A4       ; 72 KEYPAD 2 / E0 + CURSOR DOWN
        .byte $00       ; 73 KEYPAD 5
        .byte $A2       ; 74 KEYPAD 6 / E0 + CURSOR RIGHT
        .byte $A3       ; 75 KEYPAD 8 / E0 + CURSOR UP
        .byte $1B       ; 76 ESCAPE
        .byte $00       ; 77 NUMLOCK 
        .byte $8B       ; 78 F11
        .byte $00       ; 79 KEYPAD +
        .byte $98       ; 7A PAGE DOWN /E0 + PAGE DOWN
        .byte $00       ; 7B KEYPAD -
        .byte $97       ; 7C PRINT SCREEN
        .byte $99       ; 7D KEYPAD 9 / E0 + PAGE UP
        .byte $9A       ; 7E SCROLL LOCK
        .byte $00       ; 7F

        .byte $00       ; 80
        .byte $00       ; 81
        .byte $00       ; 82
        .byte $87       ; 83 F7
        .byte $00       ; 84
        .byte $00       ; 85
        .byte $00       ; 86
        .byte $00       ; 87
        .byte $00       ; 88
        .byte $00       ; 89
        .byte $00       ; 8A
        .byte $00       ; 8B
        .byte $00       ; 8C 
        .byte $00       ; 8D
        .byte $00       ; 8E
        .byte $00       ; 8F

keymap_u:
        ;   ASCII       SCAN CODE
        .byte $00       ; 00 
        .byte $89       ; 01 F9
        .byte $00       ; 02
        .byte $85       ; 03 F5
        .byte $83       ; 04 F3
        .byte $81       ; 05 F1
        .byte $82       ; 06 F2
        .byte $8C       ; 07 F12
        .byte $00       ; 08
        .byte $8A       ; 09 F10
        .byte $88       ; 0A F8
        .byte $86       ; 0B F6
        .byte $84       ; 0C F4
        .byte $09       ; 0D TAB
        .byte "~"       ; 0E BACKTICK
        .byte $00       ; 0F

        .byte $00       ; 10
        .byte $90       ; 11 LEFT ALT / E0 + RIGHT ALT
        .byte $91       ; 12 LEFT SHIFT
        .byte $00       ; 13
        .byte $92       ; 14 LEFT CONTROL / E0 + RIGHT CONTROL
        .byte "Q"       ; 15 Q
        .byte "!"       ; 16 1
        .byte $00       ; 17 
        .byte $00       ; 18
        .byte $00       ; 19
        .byte "Z"       ; 1A Z
        .byte "S"       ; 1B S
        .byte "A"       ; 1C A
        .byte "W"       ; 1D W
        .byte "@"       ; 1E 2
        .byte $00       ; 1F 

        .byte $00       ; 20
        .byte "C"       ; 21 C
        .byte "X"       ; 22 X
        .byte "D"       ; 23 D
        .byte "E"       ; 24 E
        .byte "$"       ; 25 4
        .byte "#"       ; 26 3
        .byte $00       ; 27 
        .byte $00       ; 28
        .byte " "       ; 29 SPACE
        .byte "V"       ; 2A V
        .byte "F"       ; 2B F
        .byte "T"       ; 2C T
        .byte "R"       ; 2D R
        .byte "%"       ; 2E 5
        .byte $00       ; 2F 

        .byte $00       ; 30 
        .byte "N"       ; 31 N
        .byte "B"       ; 32 B
        .byte "H"       ; 33 H
        .byte "G"       ; 34 G
        .byte "Y"       ; 35 Y
        .byte "^"       ; 36 6
        .byte $00       ; 37 
        .byte $00       ; 38
        .byte $00       ; 39
        .byte "M"       ; 3A M
        .byte "J"       ; 3B J
        .byte "U"       ; 3C U
        .byte "&"       ; 3D 7
        .byte "*"       ; 3E 8
        .byte $00       ; 3F 

        .byte $00       ; 40
        .byte "<"       ; 41 ,
        .byte "K"       ; 42 K
        .byte "I"       ; 43 I
        .byte "O"       ; 44 O
        .byte ")"       ; 45 0
        .byte "("       ; 46 9
        .byte $00       ; 47 
        .byte $00       ; 48
        .byte ">"       ; 49 .
        .byte "?"       ; 4A /
        .byte "L"       ; 4B L
        .byte ":"       ; 4C ;
        .byte "P"       ; 4D P
        .byte "_"       ; 4E -
        .byte $00       ; 4F 

        .byte $00       ; 50
        .byte $00       ; 51
        .byte $22       ; 52 ' (")
        .byte $00       ; 53 
        .byte "{"       ; 54 [
        .byte "+"       ; 55 =
        .byte $00       ; 56 
        .byte $00       ; 57
        .byte $93       ; 58 CAPS LOCK
        .byte $92       ; 59 RIGHT SHIFT
        .byte $0D       ; 5A ENTER
        .byte "}"       ; 5B ]
        .byte $00       ; 5C 
        .byte "|"       ; 5D \
        .byte $00       ; 5E 
        .byte $00       ; 5F

        .byte $00       ; 60
        .byte $00       ; 61
        .byte $00       ; 62
        .byte $00       ; 63
        .byte $00       ; 64
        .byte $00       ; 65
        .byte $08       ; 66 BACK SPACE
        .byte $00       ; 67 
        .byte $00       ; 68
        .byte $94       ; 69 KEYPAD 1 / EO + END
        .byte $00       ; 6A 
        .byte $A1       ; 6B KEYPAD 4 / E0 + CURSOR LEFT
        .byte $95       ; 6C KEYPAD 7 / E0 + HOME
        .byte $00       ; 6D 
        .byte $00       ; 6E
        .byte $00       ; 6F
        
        .byte $96       ; 70 KEYPAD 0 / E0 + INSERT
        .byte $7F       ; 71 KEYPAD . / E0 + DELETE
        .byte $A4       ; 72 KEYPAD 2 / E0 + CURSOR DOWN
        .byte $00       ; 73 KEYPAD 5
        .byte $A2       ; 74 KEYPAD 6 / E0 + CURSOR RIGHT
        .byte $A3       ; 75 KEYPAD 8 / E0 + CURSOR UP
        .byte $1B       ; 76 ESCAPE
        .byte $00       ; 77 NUMLOCK 
        .byte $8B       ; 78 F11
        .byte $00       ; 79 KEYPAD +
        .byte $98       ; 7A PAGE DOWN / E0 + PAGE DOWN
        .byte $00       ; 7B KEYPAD -
        .byte $97       ; 7C PRINT SCREEN
        .byte $99       ; 7D KEYPAD 9 / E0 + PAGE UP
        .byte $9A       ; 7E SCROLL LOCK
        .byte $00       ; 7F

        .byte $00       ; 80
        .byte $00       ; 81
        .byte $00       ; 82
        .byte $87       ; 83 F7
        .byte $00       ; 84
        .byte $00       ; 85
        .byte $00       ; 86
        .byte $00       ; 87
        .byte $00       ; 88
        .byte $00       ; 89
        .byte $00       ; 8A
        .byte $00       ; 8B
        .byte $00       ; 8C 
        .byte $00       ; 8D
        .byte $00       ; 8E
        .byte $00       ; 8F