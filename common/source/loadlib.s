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
        .export _vdp_home
        .export _vdp_clear_screen
        .export _vdp_get
        .export _vdp_put
        .export _vdp_set_write_address
        .export _vdp_set_read_address
        .export _vdp_xy_to_ptr
        .export _vdp_increment_pos_console
        .export _vdp_decrement_pos_console
        .export _vdp_console_out
        .export _vdp_console_newline
        .export _vdp_console_backspace

        ; memory
        .export con_buf         ; console
        .export Rbuff           ; xmodem
        .export screen          ; display memory
        .export wozmon_buf      ; wozmon input buffer
        .export vdp_x           ; vdp console x
        .export vdp_y           ; vdp console y
        .export linebuf         ; vdp scroll line buffer
        .export scroll_read     ; vdp scroll read line num
        .export scroll_write    ; vdp scroll write line num
        .export vdp_reg_x       ; vdp temp storage for reg x
        .export vdp_reg_y       ; vdp temp storage for reg y

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
_vdp_home:                      jmp (_syscall__vdp_home)
_vdp_clear_screen:              jmp (_syscall__vdp_clear_screen)
_vdp_get:                       jmp (_syscall__vdp_get)
_vdp_put:                       jmp (_syscall__vdp_put)
_vdp_set_write_address:         jmp (_syscall__vdp_set_write_address)
_vdp_set_read_address:          jmp (_syscall__vdp_set_read_address)
_vdp_xy_to_ptr:                 jmp (_syscall__vdp_xy_to_ptr)
_vdp_increment_pos_console:     jmp (_syscall__vdp_increment_pos_console)
_vdp_decrement_pos_console:     jmp (_syscall__vdp_decrement_pos_console)
_vdp_console_out:               jmp (_syscall__vdp_console_out)
_vdp_console_newline:           jmp (_syscall__vdp_console_newline)
_vdp_console_backspace:         jmp (_syscall__vdp_console_backspace)

; memory
con_buf:                        .word _system_con_buf
Rbuff:                          .word _system_Rbuff
screen:                         .word _system_screen
wozmon_buf:                     .word _system_wozmon_buf
vdp_x:                          .word _system_vdp_x
vdp_y:                          .word _system_vdp_y
linebuf:                        .word _system_linebuf
scroll_read:                    .word _system_scroll_read
scroll_write:                   .word _system_scroll_write
vdp_reg_x:                      .word _system_vdp_reg_x
vdp_reg_y:                      .word _system_vdp_reg_y