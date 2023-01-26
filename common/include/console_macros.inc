.macro mac_con_print addr
        lda #<addr
        sta str_ptr
        lda #>addr
        sta str_ptr + 1
        jsr _con_print
.endmacro