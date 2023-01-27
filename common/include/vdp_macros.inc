.macro vdp_delay_slow
        .repeat 16
        nop
        .endrepeat
.endmacro

.macro vdp_delay_fast
        .repeat 2
        nop
        .endrepeat
.endmacro