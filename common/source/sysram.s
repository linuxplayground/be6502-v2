        .export con_buf
        .export Rbuff
        .export screen
        .export vdp_x
        .export vdp_y
        .export linebuf
        .export scroll_read
        .export scroll_write
        .export wozmon_buf
        .export vdp_reg_x
        .export vdp_reg_y
        .export vdp_con_mode
        .export vdp_con_width
        

        .segment "BSS"
con_buf:        .res $0100      ; console
Rbuff:          .res $0300      ; xmodem
screen:         .res $0300      ; vdp g-1
wozmon_buf:     .res $000F      ; wozmon input buffer
vdp_x:          .res 1          ; vdp console x
vdp_y:          .res 1          ; vdp console y
linebuf:        .res $28        ; vdp scroll line buffer
scroll_read:    .res 1          ; vdp scroll read line num
scroll_write:   .res 1          ; vdp scroll write line num
vdp_reg_x:      .res 1          ; vdp temp storage for x reg
vdp_reg_y:      .res 1          ; vdp temp storage for y reg
vdp_con_mode:   .res 1          ; vdp console mode - 0 = text, 1 = graphics 1, 2 = graphics 2
vdp_con_width:  .res 1          ; vdp width of currently selected console