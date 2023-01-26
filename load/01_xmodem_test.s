        .include "console.inc"
        .include "console_macros.inc"
        .include "zeropage.inc"

        .code
reset:
        mac_con_print str_hello
        jsr _con_nl
        jsr _con_prompt
wait_for_input:
        jsr _con_in
        bcc wait_for_input
        jsr _con_out
        cmp #$1b                ; ESC
        beq exit
        cmp #$0d                ; CR
        beq new_line
        jmp wait_for_input
exit:
        rts
new_line:
        lda #$0a
        jsr _con_out
        jmp wait_for_input

        .rodata
str_hello:      .asciiz "Hello, from loadable."
