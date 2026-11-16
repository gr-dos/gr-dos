; GRVER's false-positive test program (make test-grver, issue #46). Built
; with Open Watcom wasm and wlink, as the country test's NLSINFO.COM is.
;
;   FAKEID MODE
;
; hooks INT 21h AX=3347h, the GR-DOS identification call, runs A:\GRVER.EXE
; with no parameters, unhooks, and exits with GRVER's exit status. Every
; other call goes to DOS. MODE is one letter:
;
;   U  returns at once: every register unchanged (a DOS that ignores it)
;   D  carry set and AX=0001h, as DR DOS does for an unknown subfunction
;   S  AX=4752h, the signature, and nothing else changed
;   C  the same answer to every call: right for GRVER's first nonce only
;   M  minor version 100, out of 0 to 99
;   R  API revision 0
;   G  a valid answer for GR-DOS 2.99 (the two-digit minor)
;
; An unknown mode, or a failed EXEC, exits with status 9.

        .8086
        .model  tiny
        .code
        org     100h

start:
        mov     si, 81h                 ; the command tail
skip:
        lodsb
        cmp     al, ' '
        je      skip
        and     al, 0DFh                ; upper case
        mov     di, offset modes
        mov     cx, nmodes
        push    cs
        pop     es
        repne   scasb
        jne     fail
        mov     mode, al

        mov     sp, offset stack_top    ; free the memory past the program
        mov     bx, offset stack_top + 15
        mov     cl, 4
        shr     bx, cl                  ; paragraphs
        mov     ah, 4Ah
        int     21h
        jc      fail

        mov     ax, 3521h               ; hook INT 21h
        int     21h
        mov     word ptr old21, bx
        mov     word ptr old21+2, es
        mov     dx, offset new21
        mov     ax, 2521h
        int     21h

        mov     param_tail+2, cs        ; run GRVER
        mov     param_fcb1+2, cs
        mov     param_fcb2+2, cs
        push    cs
        pop     es
        mov     bx, offset params
        mov     dx, offset grver
        mov     ax, 4B00h
        int     21h
        mov     bx, cs                  ; EXEC keeps only CS and IP
        mov     ss, bx
        mov     sp, offset stack_top
        mov     ds, bx
        pushf

        push    ds                      ; unhook
        lds     dx, old21
        mov     ax, 2521h
        int     21h
        pop     ds

        popf
        jc      fail
        mov     ah, 4Dh                 ; GRVER's exit status, in AL
        int     21h
        mov     ah, 4Ch
        int     21h

fail:
        mov     ax, 4C09h
        int     21h

; The INT 21h hook.
new21:
        cmp     ax, 3347h
        je      fake
        jmp     dword ptr cs:old21
fake:
        cmp     byte ptr cs:mode, 'U'
        je      done
        cmp     byte ptr cs:mode, 'D'
        jne     not_d
        mov     ax, 1
        push    bp
        mov     bp, sp
        or      word ptr [bp+6], 1      ; the caller's carry flag
        pop     bp
        iret
not_d:
        mov     ax, 4752h
        cmp     byte ptr cs:mode, 'S'
        je      done
        mov     bx, 0004h               ; 0.04
        mov     cx, 1
        cmp     byte ptr cs:mode, 'C'
        jne     not_c
        mov     dx, 0A5C3h              ; GRVER's first nonce, complemented
        iret
not_c:
        not     dx
        cmp     byte ptr cs:mode, 'M'
        jne     not_m
        mov     bl, 100
        iret
not_m:
        cmp     byte ptr cs:mode, 'R'
        jne     not_r
        xor     cx, cx
        iret
not_r:
        mov     bx, 0263h               ; G: 2.99
done:
        iret

modes           db      'UDSCMRG'
nmodes          equ     $ - modes
mode            db      0
old21           dd      0
grver           db      'A:\GRVER.EXE', 0
empty_tail      db      0, 13
fcb             db      0, 11 dup (' '), 25 dup (0)
params          dw      0               ; the environment: FAKEID's
param_tail      dw      offset empty_tail, 0
param_fcb1      dw      offset fcb, 0
param_fcb2      dw      offset fcb, 0

                db      256 dup (0)
stack_top       label   byte

        end     start
