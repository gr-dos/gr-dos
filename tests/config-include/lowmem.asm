; A master boot record for the INCLUDEFILE= tests' low memory scenario
; (scripts/config-include-test, issue #49). Built with Open Watcom wasm and
; wlink as a .COM; scripts/config-include-test puts its bytes in place of
; the boot code of a disk image's master boot record (bytes 0 to 1BDh),
; and its memory size, in KB, at offset 2.
;
; It sets the BIOS's conventional memory size (40:13h, which INT 12h
; returns) to that, as on a machine with less memory, then does what an
; MS-DOS master boot record does: moves itself to 0:0600h, loads the
; active partition's boot sector to 0:7C00h, and jumps to it with DL the
; drive.

        .8086
        .model  tiny
        .code
        org     100h

start:
        jmp     short begin
kb      dw      256                     ; the memory size, in KB
begin:
        cli
        xor     ax, ax
        mov     ss, ax
        mov     sp, 7C00h
        mov     ds, ax
        mov     es, ax
        sti
        mov     bx, 7C00h + (kb - start)
        mov     ax, [bx]
        mov     word ptr ds:[413h], ax
        mov     si, 7C00h               ; to 0:0600h
        mov     di, 0600h
        mov     cx, 256
        cld
        rep     movsw
        db      0EAh                    ; jmp 0:0600h + (moved - start)
        dw      0600h + (moved - start), 0
moved:
        mov     si, 0600h + 1BEh        ; the partition table
        mov     cx, 4
find:
        cmp     byte ptr [si], 80h
        je      found
        add     si, 16
        loop    find
        int     18h                     ; no active partition
found:
        mov     dh, [si + 1]            ; its first head, cylinder, sector
        mov     cx, [si + 2]
        mov     dl, 80h
        mov     bx, 7C00h
        mov     ax, 0201h
        int     13h
        jc      failed
        db      0EAh                    ; jmp 0:7C00h
        dw      7C00h, 0
failed:
        int     18h

        end     start
