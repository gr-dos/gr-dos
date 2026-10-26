; GR-DOS C runtime (compat/crt): close.
;
; int close(int handle) closes the handle with INT 21h function 3Eh, and
; returns 0, or -1 if DOS fails.

        .8086

_TEXT   segment word public 'CODE'
        assume  cs:_TEXT

        public  _close

_close  proc near
        push    bp
        mov     bp, sp
        push    bx
        mov     bx, [bp+4]
        mov     ah, 3Eh
        int     21h
        sbb     ax, ax                  ; -1 on carry, else 0
        pop     bx
        pop     bp
        ret
_close  endp

_TEXT   ends
        end
