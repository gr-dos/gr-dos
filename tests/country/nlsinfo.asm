; GR-DOS country test program (issue #23). Built with Open Watcom wasm and
; wlink, independently of the DOS source tree, as the smoke test's
; HELLO.COM is.
;
; Prints what DOS reports of the country CONFIG.SYS's COUNTRY= chose, one
; line each:
;
;   COUNTRY 049 DATE 1 TIME 1 CURRENCY "DM" FORMAT 3 DIGITS 2
;   SEPARATORS THOUSANDS "." DECIMAL "," DATE "." TIME ":" LIST ";"
;   CODEPAGE ACTIVE 437 SYSTEM 437
;   UPCASE 84 8E
;
; from INT 21h function 38h (country information), function 6601h (global
; code page) and function 6520h (capitalize a character: here 84h, "a"
; with a diaeresis in code page 437). A failed call prints ERROR and the
; error code instead. The numbers are decimal but UPCASE's, which are hex.

        .8086
        .model  tiny
        .code
        org     100h

start:
        mov     ax, 3800h               ; get the current country's information
        mov     dx, offset info
        int     21h
        jnc     have_info
        call    error
        jmp     codepage
have_info:
        mov     dx, offset s_country
        call    puts
        mov     ax, bx                  ; BX: the country code
        mov     cl, 3
        call    putdec
        mov     dx, offset s_date
        call    puts
        mov     ax, info_date
        mov     cl, 1
        call    putdec
        mov     dx, offset s_time
        call    puts
        mov     al, info_timefmt
        xor     ah, ah
        mov     cl, 1
        call    putdec
        mov     dx, offset s_currency
        call    puts
        mov     si, offset info_currency
        call    putq
        mov     dx, offset s_format
        call    puts
        mov     al, info_curfmt
        xor     ah, ah
        mov     cl, 1
        call    putdec
        mov     dx, offset s_digits
        call    puts
        mov     al, info_digits
        xor     ah, ah
        mov     cl, 1
        call    putdec
        call    newline

        mov     dx, offset s_thousands
        call    puts
        mov     si, offset info_thousands
        call    putq
        mov     dx, offset s_decimal
        call    puts
        mov     si, offset info_decimal
        call    putq
        mov     dx, offset s_datesep
        call    puts
        mov     si, offset info_datesep
        call    putq
        mov     dx, offset s_timesep
        call    puts
        mov     si, offset info_timesep
        call    putq
        mov     dx, offset s_list
        call    puts
        mov     si, offset info_list
        call    putq
        call    newline

codepage:
        mov     ax, 6601h               ; get the global code page
        int     21h
        jnc     have_cp
        call    error
        jmp     upcase
have_cp:
        push    dx                      ; DX: the system code page
        mov     dx, offset s_codepage
        call    puts
        mov     ax, bx                  ; BX: the active code page
        mov     cl, 1
        call    putdec
        mov     dx, offset s_system
        call    puts
        pop     ax
        mov     cl, 1
        call    putdec
        call    newline

upcase:
        mov     ax, 6520h               ; capitalize the character in DL
        mov     dl, 84h
        int     21h
        jnc     have_upcase
        call    error
        jmp     done
have_upcase:
        push    dx
        mov     dx, offset s_upcase
        call    puts
        pop     dx
        mov     al, dl
        call    puthex
        call    newline

done:
        mov     ax, 4C00h
        int     21h

; Prints "ERROR n" for the error code in AX.
error:
        push    ax
        mov     dx, offset s_error
        call    puts
        pop     ax
        mov     cl, 1
        call    putdec
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

; Prints AX in decimal, with at least CL digits.
putdec:
        xor     ch, ch
        mov     bx, 10
        xor     di, di                  ; digits pushed
putdec_digit:
        xor     dx, dx
        div     bx
        push    dx
        inc     di
        or      ax, ax
        jnz     putdec_digit
putdec_pad:
        cmp     di, cx
        jae     putdec_out
        xor     dx, dx
        push    dx
        inc     di
        jmp     putdec_pad
putdec_out:
        pop     dx
        add     dl, '0'
        call    putc
        dec     di
        jnz     putdec_out
        ret

; Prints AL as two hex digits.
puthex:
        push    ax
        mov     cl, 4
        shr     al, cl
        call    puthex_digit
        pop     ax
        and     al, 0Fh
puthex_digit:
        add     al, '0'
        cmp     al, '9'
        jbe     puthex_out
        add     al, 'A' - '9' - 1
puthex_out:
        mov     dl, al
        jmp     putc

; Prints the NUL-terminated string at SI in double quotes.
putq:
        mov     dl, '"'
        call    putc
putq_char:
        lodsb
        or      al, al
        jz      putq_end
        mov     dl, al
        call    putc
        jmp     putq_char
putq_end:
        mov     dl, '"'
        jmp     putc

s_country       db      'COUNTRY $'
s_date          db      ' DATE $'
s_time          db      ' TIME $'
s_currency      db      ' CURRENCY $'
s_format        db      ' FORMAT $'
s_digits        db      ' DIGITS $'
s_thousands     db      'SEPARATORS THOUSANDS $'
s_decimal       db      ' DECIMAL $'
s_datesep       db      ' DATE $'
s_timesep       db      ' TIME $'
s_list          db      ' LIST $'
s_codepage      db      'CODEPAGE ACTIVE $'
s_system        db      ' SYSTEM $'
s_upcase        db      'UPCASE 84 $'
s_error         db      'ERROR $'

; The 34 bytes of function 38h's country information, and a NUL after
; each field, for putq.
info            label   byte
info_date       dw      0
info_currency   db      5 dup (0)
info_thousands  db      2 dup (0)
info_decimal    db      2 dup (0)
info_datesep    db      2 dup (0)
info_timesep    db      2 dup (0)
info_curfmt     db      0
info_digits     db      0
info_timefmt    db      0
info_casemap    dd      0
info_list       db      2 dup (0)
info_reserved   db      10 dup (0)

        end     start
