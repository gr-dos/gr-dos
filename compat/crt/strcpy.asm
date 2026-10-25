; GR-DOS C runtime (compat/crt): strcpy.
;
; char *strcpy(char *dst, const char *src) copies src, with its NUL, to
; dst and returns dst. Small model: both are offsets in DS.

        .8086

_TEXT   segment word public 'CODE'
        assume  cs:_TEXT

        public  _strcpy

_strcpy proc near
        push    bp
        mov     bp, sp
        push    si
        push    di
        push    es
        push    ds
        pop     es
        mov     di, [bp+4]
        mov     si, [bp+6]
        cld
next:
        lodsb
        stosb
        or      al, al
        jnz     next
        mov     ax, [bp+4]
        pop     es
        pop     di
        pop     si
        pop     bp
        ret
_strcpy endp

_TEXT   ends
        end
