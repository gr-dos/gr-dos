; GR-DOS C runtime (compat/crt): bdos.
;
; int bdos(int fn, unsigned dx, unsigned al) calls INT 21h with AH = fn,
; DX = dx and AL = al, and returns AX.

        .8086

_TEXT   segment word public 'CODE'
        assume  cs:_TEXT

        public  _bdos

_bdos   proc near
        push    bp
        mov     bp, sp
        push    bx
        push    cx
        push    si
        push    di
        push    ds
        push    es
        mov     ah, byte ptr [bp+4]
        mov     dx, [bp+6]
        mov     al, byte ptr [bp+8]
        int     21h
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     cx
        pop     bx
        pop     bp
        ret
_bdos   endp

_TEXT   ends
        end
