        .include "audiolib.inc"
        .include "utils.inc"
        .include "zeropage.inc"

        .code

reset:
        jsr _psg_init
        lda #<snd_init
        ldx #>snd_init
        jsr _play_vgm_data

        lda #<snd_eat
        ldx #>snd_eat
        jsr _play_vgm_data

        lda #$05
        jsr delay_sec

        lda #<snd_lvl_up
        ldx #>snd_lvl_up
        jsr _play_vgm_data

        lda #$05
        jsr delay_sec

        lda #<snd_crash
        ldx #>snd_crash
        jsr _play_vgm_data
        
        rts
delay_ms:
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

delay_sec:
      lda #250
      jsr delay_ms
      lda #250
      jsr delay_ms
      lda #250
      jsr delay_ms
      lda #250
      jsr delay_ms
      rts

snd_init:
        .byte $a0, $07, $2E     ; mixer enable channel A (tone) and channel B (noise)
        .byte $66
snd_eat:
        .byte $a0, $08, $1f     ; channel A (tone) volume controlled by envelope
        .byte $a0, $0c, $04     ; envelope frequency, channel B
        .byte $a0, $0d, $00     ; envelope shape to \_
        .byte $a0, $00, $80     ; channel A (tone) fine frequency
        .byte $a0, $01, $00     ; channel A (tone) course frequency
        .byte $66
snd_crash:
        .byte $a0, $09, $1F     ; channel B (noise) volume controlled by envelope
        .byte $a0, $08, $00     ; channel A (tone) volume OFF
        .byte $a0, $0b, $a0     ; set envelope fine duration
        .byte $a0, $0c, $40     ; set envelope course duration
        .byte $a0, $0d, $00     ; set envelope shape to   \__ 
        .byte $a0, $06, $0f     ; Set noise duration
        .byte $66
snd_lvl_up:
        .byte $a0, $08, $0f     ; channel A full volume
        .byte $a0, $01, $00     ; channel A (tone) course frequency
        .byte $a0, $00, $FF     ; channel A (tone) fine frequency (lower pitch)
        .byte $61, $2d, $08     ; wait 
        .byte $a0, $00, $80     ; channel A (tone) fine frequency (higher pitch)
        .byte $61, $2d, $0f     ; wait 
        .byte $a0, $08, $00     ; channel A zero volume
        .byte $66