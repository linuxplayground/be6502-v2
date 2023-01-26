        .include "console.inc"
        
        ; console
        .export _syscall__con_in
        .export _syscall__con_out
        .export _syscall__con_print
        .export _syscall__con_nl
        .export _syscall__con_prompt
        
        .segment "SYSCALLS"
; console
_syscall__con_in:               .word _con_in
_syscall__con_out:              .word _con_out
_syscall__con_print:            .word _con_print
_syscall__con_nl:               .word _con_nl
_syscall__con_prompt:           .word _con_prompt
