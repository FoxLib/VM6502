; Загрузка в AX
; ------------------------------------------------------------------------------
.macro  ldax    arg
    ; Если есть # вначале, то выбирается Immediate
    .if (.match (.left (1, {arg}), #))
        lda     #<(.right(.tcount({arg})-1, {arg}))
        ldx     #>(.right(.tcount({arg})-1, {arg}))
    .else
    ; Иначе либо ZP, либо ABS режим
        lda     arg
        ldx     1+(arg)
    .endif
.endmacro

; ------------------------------------------------------------------------------
.macro  stax    arg
    sta     arg
    stx     1+(arg)
.endmacro

; Перемещение 16bit из src -> dst
; ------------------------------------------------------------------------------
.macro  movw   dst, src
    .if (.match (.left (1, {src}), #))
        lda     #<(.right(.tcount({src})-1, {src}))
        sta     dst
        lda     #>(.right(.tcount({src})-1, {src}))
        sta     1+(dst)
    .else
        lda     src
        sta     dst
        lda     1+(src)
        sta     1+(dst)
    .endif
.endmacro
