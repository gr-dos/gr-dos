; GR-DOS C runtime (compat/crt): strcat.
;
; char *strcat(char *dst, const char *src) copies src, with its NUL, to the
; end of dst and returns dst. Small model: both are offsets in DS.

        .8086

_TEXT   segment word public 'CODE'
        assume  cs:_TEXT

        public  _strcat

_strcat proc near
        push    bp
        mov     bp, sp
        push    cx
        push    si
        push    di
        push    es
        push    ds
        pop     es
        mov     di, [bp+4]
        xor     al, al
        mov     cx, 0FFFFh
        cld
        repne   scasb                   ; past dst's NUL
        dec     di
        mov     si, [bp+6]
next:
        lodsb
        stosb
        or      al, al
        jnz     next
        mov     ax, [bp+4]
        pop     es
        pop     di
        pop     si
        pop     cx
        pop     bp
        ret
_strcat endp

_TEXT   ends
        end
