; GR-DOS C runtime (compat/crt): the startup code of MEM.EXE, a small-model
; C program. It is linked first, so its segments give the order of the
; program's: the code, then DGROUP's initialised data, uninitialised data
; and stack, which are last and so take no space in the .EXE file.
;
; DOS starts an .EXE with DS and ES at its PSP, and gives it all the memory
; it can. The startup code
;
; - sets DS, SS and ES to DGROUP, and SP to the top of the stack;
; - clears the uninitialised data, which C needs to start as zero;
; - stores the PSP's segment in _psp;
; - shrinks the program's memory to what it uses, to the top of the stack
;   (INT 21h function 4Ah), which MEM then reports as its own; and
; - calls main, which Open Watcom C always compiles with its register
;   convention (main_: argc in AX, argv in DX), with no arguments: argc 0,
;   argv { NULL }. MEM does not use them.
;
; When main returns, the program ends with the AL it returned (INT 21h
; function 4Ch). MEM's main is void, so its return code is undefined, as
; it was with Microsoft C.

        .8086

STACK_SIZE equ 800h

_TEXT   segment word public 'CODE'
_TEXT   ends
_DATA   segment word public 'DATA'
_DATA   ends
CONST   segment word public 'CONST'
CONST   ends
_BSS    segment word public 'BSS'
bss_start label byte
__psp   dw      ?
__argc  dw      ?
argv    dw      ?                       ; argv[0], NULL
_BSS    ends
STACK   segment para stack 'STACK'
stack_start label byte
        db      STACK_SIZE dup (?)
stack_top label byte
STACK   ends

DGROUP  group   _DATA, CONST, _BSS, STACK

        public  __psp, __argc, _cstart_
        extrn   main_:near

_TEXT   segment
        assume  cs:_TEXT, ds:DGROUP

_cstart_ proc near
        mov     bx, es                  ; the PSP
        mov     dx, DGROUP
        mov     ds, dx
        cli
        mov     ss, dx
        mov     sp, offset DGROUP:stack_top
        sti

        mov     es, dx
        mov     di, offset DGROUP:bss_start
        mov     cx, offset DGROUP:stack_start
        sub     cx, di
        xor     al, al
        cld
        rep     stosb
        mov     __psp, bx

        ; Paragraphs from the PSP to the top of the stack, rounded up.
        mov     ax, offset DGROUP:stack_top
        add     ax, 15
        rcr     ax, 1                   ; the carry is the 17th bit
        mov     cl, 3
        shr     ax, cl
        add     ax, dx
        sub     ax, bx
        mov     es, bx
        mov     bx, ax
        mov     ah, 4Ah
        int     21h

        mov     es, dx
        xor     ax, ax
        mov     dx, offset DGROUP:argv
        call    main_
        mov     ah, 4Ch
        int     21h
_cstart_ endp

_TEXT   ends
        end     _cstart_
