; GR-DOS C runtime (compat/crt): segread.
;
; void segread(struct SREGS *seg) stores ES, CS, SS and DS, in that order,
; to *seg.

        .8086

_TEXT   segment word public 'CODE'
        assume  cs:_TEXT

        public  _segread

_segread proc near
        push    bp
        mov     bp, sp
        push    bx
        mov     bx, [bp+4]
        mov     [bx], es
        mov     [bx+2], cs
        mov     [bx+4], ss
        mov     [bx+6], ds
        pop     bx
        pop     bp
        ret
_segread endp

_TEXT   ends
        end
