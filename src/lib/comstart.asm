; comstart.asm: the entry of GR-DOS's C utilities that are .COM programs
;
; Open Watcom C compiles them for the small model (-ms), as it does the .EXE
; utilities, and wlink links them with `format dos com`. This module comes
; first: it puts _TEXT in DGROUP, so that code and data are one segment, as
; a .COM program needs, and the program's first byte, at 100h, is `start`.
; It is libc16's "program without the startup" (libc16's
; docs/spec/startup.md), so the program may use the libc16 members that
; need no cstart: intdos, int86, bdos, the string functions and so on.
;
; DOS starts a .COM program with CS = DS = ES = SS = the PSP, which is
; DGROUP, and SP at the top of its memory block, or of the 64 KB segment
; (FFFEh). The stack is left there. The entry zeroes _BSS (_edata to _end,
; which wlink defines), clears the direction flag and calls com_main, an
; int function of no arguments in the default register convention, then
; exits with its result as the errorlevel (INT 21h function 4Ch). The
; program may also exit itself.

        .8086

DGROUP  group   _TEXT, CONST, CONST2, _DATA, _BSS

_TEXT   segment word public 'CODE'
_TEXT   ends
CONST   segment word public 'DATA'
CONST   ends
CONST2  segment word public 'DATA'
CONST2  ends
_DATA   segment word public 'DATA'
_DATA   ends
_BSS    segment word public 'BSS'
_BSS    ends

        extrn   com_main_:near
        extrn   _edata:byte
        extrn   _end:byte

_TEXT   segment
        assume  cs:DGROUP, ds:DGROUP, es:DGROUP, ss:DGROUP
        org     100h

        public  start
start:
        cld
        mov     di, offset DGROUP:_edata
        mov     cx, offset DGROUP:_end
        sub     cx, di
        xor     al, al
        rep     stosb
        call    com_main_
        mov     ah, 4Ch
        int     21h
_TEXT   ends

        end     start
