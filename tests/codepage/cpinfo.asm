; GR-DOS code page test program (issue #24). Built with Open Watcom wasm
; and wlink, independently of the DOS source tree, as the smoke test's
; HELLO.COM is.
;
; Prints what CON says its code page is, and what the screen's font is,
; one line each:
;
;   CON CODEPAGE 850
;   FONT 9B 00 00 00 00 00 7C CE DE F6 E6 C6 7C 00 00 00 00
;   FONT D5 00 00 00 00 00 38 18 18 18 18 18 3C 00 00 00 00
;
; The code page is generic IOCTL 440Ch, category 3 (CON), function 6Ah
; (query selected), on CON opened by name, as standard output may be AUX
; (CTTY): DISPLAY.SYS answers it. A failed call prints CON CODEPAGE ERROR
; and the error code, in decimal; without DISPLAY.SYS it is 1 (invalid
; function).
;
; The font lines are the first 16 bytes of characters 9Bh and D5h in
; plane 2 of EGA or VGA memory, where the text mode's font is: 9Bh is the
; cent sign in code page 437 and o with a stroke in 850; D5h is a box
; drawing character in 437 and 865 and the dotless i in 850. They show
; which font the hardware has, not what DOS was told. The planes are read
; with the sequencer and graphics controller set as for a font load (the
; EGA's registers cannot be read back), then set back to text mode's
; values, colour or monochrome by the miscellaneous output register.

        .8086
        .model  tiny
        .code
        org     100h

start:
        mov     ax, 3D02h               ; open CON, read and write
        mov     dx, offset s_con
        int     21h
        jc      cp_error
        mov     bx, ax
        mov     ax, 440Ch               ; generic IOCTL for a character device
        mov     cx, 036Ah               ; CON, query selected code page
        mov     dx, offset cpbuf
        int     21h
        pushf
        push    ax
        mov     ah, 3Eh                 ; close it
        int     21h
        pop     ax
        popf
        jc      cp_error
        mov     dx, offset s_codepage
        call    puts
        mov     ax, cpbuf_id
        call    putdec
        call    newline
        jmp     font

cp_error:
        push    ax
        mov     dx, offset s_codepage
        call    puts
        mov     dx, offset s_error
        call    puts
        pop     ax
        call    putdec
        call    newline

font:
        mov     al, 9Bh
        call    glyph
        mov     al, 0D5h
        call    glyph

        mov     ax, 4C00h
        int     21h

; Prints "FONT cc" and the 16 bytes of character AL from plane 2.
glyph:
        push    ax
        mov     dx, offset s_font
        call    puts
        pop     ax
        push    ax
        call    puthex
        pop     ax
        xor     ah, ah
        mov     cl, 5                   ; 32 bytes a character
        shl     ax, cl
        mov     si, ax

        cli
        mov     dx, 3C4h                ; sequencer
        mov     ax, 0402h               ; map mask: plane 2
        out     dx, ax
        mov     ax, 0704h               ; memory mode: sequential, extended
        out     dx, ax
        mov     dx, 3CEh                ; graphics controller
        mov     ax, 0204h               ; read map: plane 2
        out     dx, ax
        mov     ax, 0005h               ; mode: read mode 0, write mode 0
        out     dx, ax
        mov     ax, 0406h               ; miscellaneous: A000h, 64 KB, no odd/even
        out     dx, ax

        push    ds
        mov     ax, 0A000h
        mov     ds, ax
        mov     di, offset glyphbuf
        mov     cx, 16
copy:   lodsb
        mov     cs:[di], al
        inc     di
        loop    copy
        pop     ds

        mov     dx, 3C4h
        mov     ax, 0302h               ; map mask: planes 0 and 1
        out     dx, ax
        mov     ax, 0304h               ; memory mode: odd/even, extended
        out     dx, ax
        mov     dx, 3CEh
        mov     ax, 0004h               ; read map: plane 0
        out     dx, ax
        mov     ax, 1005h               ; mode: odd/even
        out     dx, ax
        mov     ah, 0Eh                 ; miscellaneous: B800h, odd/even
        mov     dx, 3CCh                ; colour (I/O at 3Dxh) or monochrome
        in      al, dx
        test    al, 1
        jnz     colour
        mov     ah, 0Ah                 ; B000h
colour: mov     dx, 3CEh
        mov     al, 06h
        out     dx, ax
        sti

        mov     si, offset glyphbuf
        mov     cx, 16
show:   push    cx
        mov     dl, ' '
        call    putc
        lodsb
        call    puthex
        pop     cx
        loop    show
        jmp     newline

; Prints the $-terminated string at DX.
puts:
        mov     ah, 09h
        int     21h
        ret

; Prints the character in DL.
putc:
        mov     ah, 02h
        int     21h
        ret

newline:
        mov     dl, 13
        call    putc
        mov     dl, 10
        jmp     putc

; Prints AX in decimal.
putdec:
        xor     cx, cx
        mov     bx, 10
divide: xor     dx, dx
        div     bx
        push    dx
        inc     cx
        or      ax, ax
        jnz     divide
digits: pop     dx
        add     dl, '0'
        push    cx
        call    putc
        pop     cx
        loop    digits
        ret

; Prints AL as two hex digits.
puthex:
        push    ax
        mov     cl, 4
        shr     al, cl
        call    nibble
        pop     ax
        and     al, 0Fh
nibble:
        mov     dl, al
        add     dl, '0'
        cmp     dl, '9'
        jbe     nib_out
        add     dl, 'A' - '9' - 1
nib_out:
        jmp     putc

s_con           db      'CON', 0
s_codepage      db      'CON CODEPAGE $'
s_error         db      'ERROR $'
s_font          db      'FONT $'
cpbuf           dw      2               ; length of the data that follows
cpbuf_id        dw      0
glyphbuf        db      16 dup (0)

        end     start
