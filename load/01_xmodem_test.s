        .include "console.inc"
        .include "console_macros.inc"
        .include "zeropage.inc"
        .include "wozmon.inc"

        .code
reset:
        mac_con_print str_hello
        jsr _con_nl
        jsr _con_prompt
wait_for_input:
        jsr _con_in
        bcc wait_for_input
        cmp #$1b                ; ESC
        beq exit
        cmp #$0d                ; LF
        beq new_line
        cmp #$0d                ; CR
        beq new_line
        sec
        cmp #$7F
        bcs special             ; we had to borrow so A is 80 or more 
        jsr _con_out
        jmp wait_for_input
exit:
        rts
new_line:
        jsr _con_nl
        jmp wait_for_input
special:
        jsr _prbyte
        jsr _con_nl
        jmp wait_for_input

        .rodata
str_hello:      .asciiz "Hello, from loadable."
str_up:         .asciiz " UP "
str_down:       .asciiz " DOWN "
str_left:       .asciiz " LEFT "
str_right:      .asciiz " RIGHT "