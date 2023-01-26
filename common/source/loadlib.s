        .include "syscalls.inc"

        ; console
        .export _con_in
        .export _con_out
        .export _con_print
        .export _con_prompt
        .export _con_nl
        
        .code

; console
_con_in:                        jmp (_syscall__con_in)
_con_out:                       jmp (_syscall__con_out)
_con_print:                     jmp (_syscall__con_print)
_con_prompt:                    jmp (_syscall__con_prompt)
_con_nl:                        jmp (_syscall__con_nl)