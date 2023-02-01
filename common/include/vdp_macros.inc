.macro vdp_delay_slow
        .repeat 32
        nop
        .endrepeat
.endmacro

.macro vdp_delay_fast
        .repeat 4
        nop
        .endrepeat
.endmacro

.macro vdp_set_write_address addr
        lda #<addr
        ldx #>addr
        jsr _vdp_set_write_address
.endmacro

.macro vdp_ptr_to_vram_write_addr
        lda vdp_ptr
        ldx vdp_ptr + 1
        jsr _vdp_set_write_address
.endmacro

.macro vdp_ptr_to_vram_read_addr
        lda vdp_ptr
        ldx vdp_ptr + 1
        jsr _vdp_set_read_address
.endmacro

.macro vdp_vdp_xy_to_ptr
        ldx vdp_x
        ldy vdp_y
        jsr _vdp_xy_to_ptr
.endmacro
