        .exportzp usr_irq
        .exportzp con_r_idx
        .exportzp con_w_idx
        .exportzp kbd_flags
        .exportzp str_ptr
        .exportzp tmp1
        .exportzp crc
        .exportzp crch
        .exportzp ptr
        .exportzp ptrh
        .exportzp blkno
        .exportzp retry
        .exportzp retry2
        .exportzp bflag
        .exportzp XAML
        .exportzp XAMH
        .exportzp STL
        .exportzp STH
        .exportzp L  
        .exportzp H
        .exportzp YSAV
        .exportzp MODE
        .exportzp MSGL
        .exportzp MSGH
        .exportzp vdp_ptr
        .exportzp vdp_cur
        .exportzp vdp_con_mode
        .exportzp vdp_con_width

        .zeropage        
usr_irq:                .res 2, 0  ; the jump vector for user IRQ routines initialized to 0x0000
con_r_idx:              .res 1, 0  ; console read index initialized to 0
con_w_idx:              .res 1, 0  ; console write index initialized to 0
kbd_flags:              .res 1, 0  ; keyboard flags for tracking state of shift keys
str_ptr:                .res 2, 0  ; string pointer
tmp1:                   .res 1, 0  ; used by delay routines in utils library
crc:                    .res 1     ; xmodem
crch:                   .res 1     ; xmodem
ptr:                    .res 1     ; xmodem
ptrh:                   .res 1     ; xmodem
blkno:                  .res 1     ; xmodem
retry:                  .res 1     ; xmodem
retry2:                 .res 1     ; xmodem
bflag:                  .res 1     ; xmodem
XAML:                   .res 1     ; wozmon
XAMH:                   .res 1     ; wozmon
STL:                    .res 1     ; wozmon
STH:                    .res 1     ; wozmon
L:                      .res 1     ; wozmon
H:                      .res 1     ; wozmon
YSAV:                   .res 1     ; wozmon
MODE:                   .res 1     ; wozmon
MSGL:                   .res 1     ; wozmon
MSGH:                   .res 1     ; wozmon
vdp_ptr:                .res 2     ; vdp
vdp_cur:                .res 2     ; vdp
vdp_con_mode:           .res 1     ; vdp
vdp_con_width:          .res 1     ; vdp