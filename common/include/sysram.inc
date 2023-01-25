        .import __SYSRAM_START__

kbd_buf = __SYSRAM_START__      ; $100
con_buf = kbd_buf + $100        ; $100
; next = kbd_bud + $100