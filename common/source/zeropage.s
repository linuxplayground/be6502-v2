        .exportzp usr_irq
        .exportzp con_r_idx
        .exportzp con_w_idx
        .exportzp kbd_flags
        .exportzp str_ptr
        .exportzp tmp1

        .zeropage        
usr_irq:                .res 2, 0  ; the jump vector for user IRQ routines initialized to 0x0000
con_r_idx:              .res 1, 0  ; console read index initialized to 0
con_w_idx:              .res 1, 0  ; console write index initialized to 0
kbd_flags:              .res 1, 0  ; keyboard flags for tracking state of shift keys
str_ptr:                .res 2, 0  ; string pointer
tmp1:                   .res 1, 0  ; used by delay routines in utils library