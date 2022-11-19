
        .org        $8000

PTR0    := $00

.segment  "CODE"

        sei

; -- Графический режим
;        lda #1
;        sta $202
;@M:     jmp @M

        lda #250
        jsr FILL

@L:     lda $201
        sta $2000
        lda $200
        sta $2001
        jmp @L

; ----------------------------------------------------------------------

FILL:   pha
        lda #$00
        sta PTR0
        lda #$20
        sta PTR0+1

        ; TEXT
        ldx #$08
        ldy #$00
        pla
@L1:    sta (PTR0),Y
        iny
        bne @L1
        inc PTR0+1
        dex
        bne @L1

        ; COLOR
        lda #$07
        ldx #$08
        ldy #$00
@L2:    sta (PTR0),Y
        iny
        bne @L2
        inc PTR0+1
        dex
        bne @L2
        rts

        .org    $204
.byte   $01

        .org    $2000

        ; Рисовать прямоугольник цветом 14
.byte   $01, 50,0,  25,0,  250,0, 125,0,  7
.byte   $01, 52,0,  27,0,  248,0,  41,0,  3
.byte   $02, 54,0,  27,0,  $F0,$38,  8,16,  15
.byte   $02, 62,0,  27,0,  $00,$3E,  8,16,  15
.byte   $02, 70,0,  27,0,  $80,$3A,  8,16,  15
.byte   $02, 78,0,  27,0,  $20,$3A,  8,16,  15
.byte   $FF
