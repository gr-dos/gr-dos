; GR-DOS C runtime (compat/crt): filelength.
;
; long filelength(int handle) returns the size of the open file, or -1L if
; DOS fails. The size is the file pointer after moving it to the end (INT
; 21h function 42h); the pointer is then moved back to where it was.

        .8086

_TEXT   segment word public 'CODE'
        assume  cs:_TEXT

        public  _filelength

_filelength proc near
        push    bp
        mov     bp, sp
        push    bx
        push    cx
        push    si
        push    di
        mov     bx, [bp+4]
        mov     ax, 4201h               ; where the pointer is: DX:AX
        xor     cx, cx
        xor     dx, dx
        int     21h
        jc      fail
        mov     si, ax
        mov     di, dx
        mov     ax, 4202h               ; the end: DX:AX is the size
        xor     cx, cx
        xor     dx, dx
        int     21h
        jc      fail
        push    dx
        push    ax
        mov     ax, 4200h               ; back to CX:DX from the start
        mov     cx, di
        mov     dx, si
        int     21h
        pop     ax
        pop     dx
        jnc     done
fail:
        mov     ax, -1
        cwd
done:
        pop     di
        pop     si
        pop     cx
        pop     bx
        pop     bp
        ret
_filelength endp

_TEXT   ends
        end
