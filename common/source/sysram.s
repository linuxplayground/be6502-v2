        .export con_buf
        .export Rbuff

        .segment "BSS"
con_buf:        .res $0100      ; console
Rbuff:          .res $0300      ; xmodem
