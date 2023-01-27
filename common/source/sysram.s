        .export con_buf
        .export Rbuff
        .export screen
        .export vdp_x
        .export vdp_y
        .export linebuf
        .export scroll_read
        .export scroll_write

        .segment "BSS"
con_buf:        .res $0100      ; console 200 - 2ff
Rbuff:          .res $0300      ; xmodem  300 - 5ff
screen:         .res $0300      ; vdp g-1 600 - 8ff
scrollbuf:      .res $20        ; vdp single line scroll buffer 900-920
vdp_x:          .res 1          ; vdp console x
vdp_y:          .res 1          ; vdp console y
linebuf:        .res $20        ; vdp scroll line buffer
scroll_read:    .res 1          ; vdp scroll read line num
scroll_write:   .res 1          ; vdp scroll write line num