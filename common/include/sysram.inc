        .import con_buf         ; console
        .import Rbuff           ; xmodem
        .import screen          ; display memory
        .import wozmon_buf      ; wozmon input buffer
        .import scrollbuf       ; vdp single line scroll buffer 900-920
        .import vdp_x           ; vdp console x
        .import vdp_y           ; vdp console y
        .import linebuf         ; vdp scroll line buffer
        .import scroll_read     ; vdp scroll read line num
        .import scroll_write    ; vdp scroll write line num
        .import vdp_reg_x       ; vdp temp storage for reg x
        .import vdp_reg_y       ; vdp temp storage for reg y