; GR-DOS C runtime (compat/crt): strcmp.
;
; int strcmp(const char *a, const char *b) returns 0 if the strings are the
; same, and otherwise -1 or 1 as the first byte that differs, unsigned, is
; less in a or in b. Small model: both are offsets in DS.

        .8086

_TEXT   segment word public 'CODE'
        assume  cs:_TEXT

        public  _strcmp

_strcmp proc near
        push    bp
        mov     bp, sp
        push    si
        push    di
        mov     si, [bp+4]
        mov     di, [bp+6]
        cld
next:
        lodsb
        mov     ah, [di]
        inc     di
        cmp     al, ah
        jne     differ
        or      al, al
        jnz     next
        xor     ax, ax
        jmp     short done
differ:
        sbb     ax, ax                  ; -1 if a's byte is below b's, else 0
        or      ax, 1
done:
        pop     di
        pop     si
        pop     bp
        ret
_strcmp endp

_TEXT   ends
        end
