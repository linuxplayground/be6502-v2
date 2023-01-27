        .include "console.inc"
        .include "wozmon.inc"
        .include "vdp.inc"

        ; console
        .export _syscall__con_in
        .export _syscall__con_out
        .export _syscall__con_print
        .export _syscall__con_nl
        .export _syscall__con_prompt
        ; wozmon
        .export _syscall__prbyte
        ; vdp
        .export _syscall__vdp_reset
        .export _syscall__vdp_clear_screen
        .export _syscall__vdp_home
        .export _syscall__vdp_wait
        .export _syscall__vdp_flush
        .export _syscall__vdp_out
        .export _syscall__vdp_put
        .export _syscall__vdp_scroll

        .segment "SYSCALLS"
; console
_syscall__con_in:               .word _con_in
_syscall__con_out:              .word _con_out
_syscall__con_print:            .word _con_print
_syscall__con_nl:               .word _con_nl
_syscall__con_prompt:           .word _con_prompt
;wozmon
_syscall__prbyte:               .word _prbyte
;vdp
_syscall__vdp_reset:            .word _vdp_reset
_syscall__vdp_clear_screen:     .word _vdp_clear_screen
_syscall__vdp_home:             .word _vdp_home
_syscall__vdp_wait:             .word _vdp_wait
_syscall__vdp_flush:            .word _vdp_flush
_syscall__vdp_out:              .word _vdp_out
_syscall__vdp_put:              .word _vdp_put
_syscall__vdp_scroll:           .word _vdp_scroll