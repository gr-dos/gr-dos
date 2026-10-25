; GR-DOS C runtime (compat/crt): strlen.
;
; size_t strlen(const char *s) returns the number of bytes before s's NUL.
; Small model: s is an offset in DS.

        .8086

_TEXT   segment word public 'CODE'
        assume  cs:_TEXT

        public  _strlen

_strlen proc near
        push    bp
        mov     bp, sp
        push    cx
        push    di
        push    es
        push    ds
        pop     es
        mov     di, [bp+4]
        xor     al, al
        mov     cx, 0FFFFh
        cld
        repne   scasb                   ; CX = -(length + 2)
        mov     ax, cx
        not     ax
        dec     ax
        pop     es
        pop     di
        pop     cx
        pop     bp
        ret
_strlen endp

_TEXT   ends
        end
