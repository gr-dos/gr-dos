; GR-DOS C runtime (compat/crt): kbhit.
;
; int kbhit(void) returns nonzero if a character is waiting at the standard
; input, by INT 21h function 0Bh, which also checks for Ctrl-Break.

        .8086

_TEXT   segment word public 'CODE'
        assume  cs:_TEXT

        public  _kbhit

_kbhit  proc near
        mov     ah, 0Bh
        int     21h                     ; AL = 0FFh if a character is waiting, else 0
        cbw
        ret
_kbhit  endp

_TEXT   ends
        end
