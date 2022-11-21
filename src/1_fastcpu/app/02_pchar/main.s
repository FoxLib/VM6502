; ----------------------------------------------------------------------
DI          := $00
SI          := $02
; ----------------------------------------------------------------------
.org        $8000
.include    "../macro.asm"
.segment    "CODE"

            sei
            lda     #0
            jsr     CLS

            movw    <DI, #($2000+32*11+9)
            ldax    #HELLO
            jsr     PSTR
L1:         jmp     L1

; ОЧИСТКА ЭКРАНА ОТ скверны
; ----------------------------------------------------------------------

CLS:        movws   <DI, #$2000         ; Экран тут
            ldx     #3
            ldy     #0
@L0:        sta     (DI),y
            iny
            bne     @L0
            inc     <(DI+1)
            dex
            bne     @L0
            rts

; ПРОЦЕДУРА ВЫВОДА НА ЭКРАН СТРИНГОВ длиной не более 255
; ----------------------------------------------------------------------

PSTR:       stax <SI
            ldy #$00
@L0:        lda (SI),y
            beq @L1
            sta (DI),y
            iny
            bne @L0
@L1:        rts         ; LOOONG!!

; ----------------------------------------------------------------------
HELLO:      .asciiz     "Hello, world!"
.segment    "BSS"


