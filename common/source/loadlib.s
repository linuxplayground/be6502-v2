        .include "syscalls.inc"

        ; console
        .export _con_in
        .export _con_out
        .export _con_print
        .export _con_prompt
        .export _con_nl
        ; wozmon
        .export _prbyte
        ; vdp
        .export _vdp_reset
        .export _vdp_clear_screen
        .export _vdp_home
        .export _vdp_wait
        .export _vdp_flush
        .export _vdp_out
        .export _vdp_put
        .export _vdp_scroll

        .code

; console
_con_in:                        jmp (_syscall__con_in)
_con_out:                       jmp (_syscall__con_out)
_con_print:                     jmp (_syscall__con_print)
_con_prompt:                    jmp (_syscall__con_prompt)
_con_nl:                        jmp (_syscall__con_nl)
;wozmon
_prbyte:                        jmp (_syscall__prbyte)
;vdp
_vdp_reset:                     jmp (_syscall__vdp_reset)
_vdp_clear_screen:              jmp (_syscall__vdp_clear_screen)
_vdp_home:                      jmp (_syscall__vdp_home)
_vdp_wait:                      jmp (_syscall__vdp_wait)
_vdp_flush:                     jmp (_syscall__vdp_flush)
_vdp_out:                       jmp (_syscall__vdp_out)
_vdp_put:                       jmp (_syscall__vdp_put)
_vdp_scroll:                    jmp (_syscall__vdp_scroll)