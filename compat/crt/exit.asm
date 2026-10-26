; GR-DOS C runtime (compat/crt): exit.
;
; void exit(int status) ends the program with INT 21h function 4Ch, with
; the low byte of status as its return code. There is nothing to flush or
; to call at exit.

        .8086

_TEXT   segment word public 'CODE'
        assume  cs:_TEXT

        public  _exit

_exit   proc near
        push    bp
        mov     bp, sp
        mov     al, byte ptr [bp+4]
        mov     ah, 4Ch
        int     21h
_exit   endp

_TEXT   ends
        end
