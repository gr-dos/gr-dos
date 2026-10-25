; GR-DOS C runtime (compat/crt): intdos, intdosx, int86 and int86x.
;
; The Microsoft C interface: the registers are loaded from *in (union REGS:
; ax, bx, cx, dx, si, di, cflag) and, for intdosx and int86x, DS and ES from
; *seg (struct SREGS: es, cs, ss, ds); the interrupt is called; the registers
; are stored to *out, with cflag 1 if the carry flag was set and 0 if not,
; and DS and ES to *seg. The result is the AX the interrupt returned. The
; caller's BX, CX, SI, DI, BP, DS and ES are kept.

        .8086

_TEXT   segment word public 'CODE'
        assume  cs:_TEXT

        public  _intdos, _intdosx, _int86, _int86x

; int intdos(union REGS *in, union REGS *out)
_intdos proc near
        push    bp
        mov     bp, sp
        xor     ax, ax
        push    ax                      ; no SREGS
        push    word ptr [bp+6]
        push    word ptr [bp+4]
        mov     al, 21h
        push    ax
        call    _int86x
        mov     sp, bp
        pop     bp
        ret
_intdos endp

; int intdosx(union REGS *in, union REGS *out, struct SREGS *seg)
_intdosx proc near
        push    bp
        mov     bp, sp
        push    word ptr [bp+8]
        push    word ptr [bp+6]
        push    word ptr [bp+4]
        mov     ax, 21h
        push    ax
        call    _int86x
        mov     sp, bp
        pop     bp
        ret
_intdosx endp

; int int86(int intno, union REGS *in, union REGS *out)
_int86  proc near
        push    bp
        mov     bp, sp
        xor     ax, ax
        push    ax                      ; no SREGS
        push    word ptr [bp+8]
        push    word ptr [bp+6]
        push    word ptr [bp+4]
        call    _int86x
        mov     sp, bp
        pop     bp
        ret
_int86  endp

; int int86x(int intno, union REGS *in, union REGS *out, struct SREGS *seg)
;
; seg may also be 0 (for intdos and int86): the interrupt is then called
; with the caller's DS and ES, and they are not stored.
;
; The interrupt is called as INT does it, through its vector, with the
; flags pushed and interrupts disabled, so that any vector number can be
; used without code that changes itself.
_int86x proc near
        push    bp
        mov     bp, sp
        push    bx                      ; [bp-2]
        push    cx                      ; [bp-4]
        push    si                      ; [bp-6]
        push    di                      ; [bp-8]
        push    ds                      ; [bp-10]
        push    es                      ; [bp-12]

        xor     ax, ax                  ; the vector, to [bp-16]
        mov     es, ax
        mov     bl, byte ptr [bp+4]
        xor     bh, bh
        shl     bx, 1
        shl     bx, 1
        push    word ptr es:[bx+2]      ; [bp-14] segment
        push    word ptr es:[bx]        ; [bp-16] offset

        mov     bx, [bp+10]             ; DS and ES for the interrupt
        or      bx, bx
        jz      callers
        push    word ptr [bx+6]
        push    word ptr [bx]
        jmp     short load
callers:
        push    ds
        push    word ptr [bp-12]
load:
        mov     bx, [bp+6]
        mov     ax, [bx]
        mov     cx, [bx+4]
        mov     dx, [bx+6]
        mov     si, [bx+8]
        mov     di, [bx+10]
        mov     bx, [bx+2]
        pop     es
        pop     ds

        pushf
        cli
        call    dword ptr [bp-16]

        ; The interrupt may not keep BP, but SP is as it was: [bp-16].
        pushf                           ; [bp-18]
        push    ds                      ; [bp-20]
        push    bx                      ; [bp-22]
        mov     bp, sp
        add     bp, 22
        mov     ds, [bp-10]

        mov     bx, [bp+8]
        mov     [bx], ax
        pop     word ptr [bx+2]
        mov     [bx+4], cx
        mov     [bx+6], dx
        mov     [bx+8], si
        mov     [bx+10], di
        pop     cx                      ; DS
        pop     dx                      ; flags
        and     dx, 1                   ; CF
        mov     [bx+12], dx

        mov     si, [bp+10]
        or      si, si
        jz      done
        mov     [si], es
        mov     [si+6], cx
done:
        lea     sp, [bp-12]
        pop     es
        pop     ds
        pop     di
        pop     si
        pop     cx
        pop     bx
        pop     bp
        ret
_int86x endp

_TEXT   ends
        end
