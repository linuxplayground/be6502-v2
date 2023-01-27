        .export con_buf
        .export Rbuff
        .export screen
        .export scrollbuf

        .segment "BSS"
con_buf:        .res $0100      ; console 200 - 2ff
Rbuff:          .res $0300      ; xmodem  300 - 5ff
screen:         .res $0300      ; vdp g-1 600 - 8ff
scrollbuf:      .res $20        ; vdp single line scroll buffer 900-920
