        .export con_buf
        .export Rbuff
        .export screen
        .export vdp_x
        .export vdp_y
        .export linebuf
        .export scroll_read
        .export scroll_write
        .export wozmon_buf
        

        .segment "BSS"
con_buf:        .res $0100      ; console
Rbuff:          .res $0300      ; xmodem
screen:         .res $0300      ; vdp g-1
wozmon_buf:     .res $000F      ; wozmon input buffer
scrollbuf:      .res $20        ; vdp single line scroll buffer
vdp_x:          .res 1          ; vdp console x
vdp_y:          .res 1          ; vdp console y
linebuf:        .res $20        ; vdp scroll line buffer
scroll_read:    .res 1          ; vdp scroll read line num
scroll_write:   .res 1          ; vdp scroll write line num