      .include "zeropage.inc"

      .export _delay_ms
      .export _delay_sec

      .code

_delay_ms:
      sta tmp1
      txa
      pha
      tya
      pha
      ldx tmp1
      ldy #190
loop1:
      dey
      bne loop1

loop2:
      dex
      beq return
      nop
      ldy #198
loop3:
      dey
      bne loop3
      jmp loop2
return:
      pla
      tay
      pla
      tax
      lda tmp1
      rts


_delay_sec:
      lda #250
      jsr _delay_ms
      lda #250
      jsr _delay_ms
      lda #250
      jsr _delay_ms
      lda #250
      jsr _delay_ms
      rts