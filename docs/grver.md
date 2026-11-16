# GR-DOS identification call and GRVER (issue #46)

Programs see MS-DOS 4.00 from `INT 21h` `AH=30h`, as on MS-DOS, and
that stays so. GR-DOS's own release version (`VERSION`, for example 0.04)
comes from a separate call, `INT 21h` `AX=3347h`. `C:\DOS\GRVER.EXE` reports
it:

```
C:\>GRVER
GR-DOS 0.04
```

On any other DOS, GRVER says `GR-DOS kernel not detected.` This is the
proof of concept of [01-int21h-poc.md](01-int21h-poc.md).

## The call

| | Register | Value |
|---|---|---|
| **In** | `AX` | `3347h`: function 33h, subfunction 47h (`G`) |
| | `BX` | `4752h` (`GR`): the request signature |
| | `DX` | any value: a nonce, chosen by the caller |
| **Out, GR-DOS** | `AX` | `4752h` (`GR`): the answer signature |
| | `BH` | the major version, 0 to 255 |
| | `BL` | the minor version, 0 to 99 (0.04 is `BH=0`, `BL=4`) |
| | `CL` | the API revision: 1 |
| | `CH` | reserved: 0 in revision 1 |
| | `DX` | the nonce complemented (`NOT DX`) |

- **Preserved:** every other register (`SI`, `DI`, `BP`, `SP` and the segment
  registers). The flags come back as the caller had them: the call is
  answered in the dispatcher's fast path, which ends in `IRET`, so it
  never sets or clears the carry flag. Test `AX`, not `CF`.
- **Safe:** it reads and writes no memory, takes no DOS lock, and can be made
  from any program at any time, as the other subfunctions of function 33h
  can (they are the ones the dispatcher answers before it switches stacks).
- **Anything else** (`AX=3347h` with another `BX`, or `AL` from 06h to FFh
  but 47h) is an invalid subfunction, `AL=FFh`, as on MS-DOS 4.00.
- **The version** is `VERSION`'s: the Makefile writes `GRDOSVER.INC` from
  it at each build, and fails unless it is `n.nn` with a major version of
  at most 255. `AH=30h` is unchanged: 4.00.

### Recognizing GR-DOS

A caller takes the answer for GR-DOS only if all of these are true:

1. `AX` is `4752h`;
2. `DX` is the nonce complemented;
3. `CL`, the revision, is at least 1;
4. `BL` is at most 99.

GRVER makes the call twice, with two nonces (5A3Ch and C3A5h), and the
two answers must agree. That rules out:

- **registers left as they were** (`AX` would still be `3347h`);
- **a handler that answers every call the same way**, which the second
  nonce catches.

A program deliberately written to imitate GR-DOS can still pass. No check
made from inside the machine can rule that out.

### Other kernels

| Kernel | Answer | GRVER |
|---|---|---|
| MS-DOS 4.00 (and 3.x, 5 to 6.22, which have no subfunction 47h) | `AL=FFh`, other registers unchanged | not detected, status 1 |
| DR DOS 5.0, 6.0 | carry set, `AX=0001h` | not detected, status 1 |
| DOSBox-X 2026.01.02 | `AX` not 4752h | not detected, status 1 |
| GR-DOS | as above | `GR-DOS n.nn`, status 0 |

`make test-grver` tests the first, fourth and DR DOS-style answers (below).
The DOSBox-X row was checked by hand. MS-DOS 5 to 6.22 and DR DOS were not
run: their rows are from Ralf Brown's Interrupt List.

### Choosing the number

Ralf Brown's Interrupt List (release 61) shows these allocations near
function 33h:

| `AX` | Owner |
|---|---|
| `3300h`–`3302h` | DOS 2+ / 3.x+: Ctrl-Break checking |
| `3303h`, `3304h` | DOS 3.4 / 4.0: CPSW (a no-op) |
| `3305h` | DOS 4.0+: the boot drive |
| `3306h` | DOS 5+: the true version; also a CBIS network redirector |
| `3307h` | Windows 95: DOS_FLAG |
| `330Fh` | Burghofer virus: an install check |
| `3341h` | Diet Disk 1.0: an install check |
| `33DAh`–`33DCh` | CoffeeShop virus |
| `33E0h` | Oropax virus: an install check |

`3347h` is not in the list. Function 33h was chosen because:

- every DOS from 2.0 on has it, and returns `AL=FFh` (MS-DOS) or an error
  (DR DOS) for a subfunction it does not know. Calling it on another
  DOS is harmless.
- MS-DOS 4.00 answers it with registers alone, on the caller's stack
  (`SAVREGS` in `DOS/DISP.ASM`), so the change is small: nine
  instructions after subfunction 05h's.
- a new function number is worse. A function above MS-DOS 4.00's last,
  6Ch, returns `AL=0` on MS-DOS 4.00 but is a real call on later DOS
  versions (`AH=6Dh` and up are OS/2, Windows and others). The ones near
  FFh are claimed by many TSRs.

`BX=4752h` keeps a stray `AX=3347h` (a program that meant something else)
from being answered. The nonce in `DX` lets a caller tell an answer from
registers that were never changed.

### Future revisions

- **`CL` grows** when the call returns more. A later revision keeps
  revision 1's registers as they are, so a revision 1 caller still works.
- **`CH`** is reserved for capability flags. It is 0 now: callers must
  ignore it, and not fail when it is not 0.

## The kernel change

`patches/kernel/0001-identification.patch` changes `DOS/DISP.ASM`:

- `QueryDOSboot`'s jump to `BadVal` (subfunctions above 05h) goes to
  `GRDOS_Ident` instead, which answers `AL=47h` with `BX=4752h` and sends
  everything else to `BadVal`, as before;
- `DISP.ASM` includes `GRDOSVER.INC`.

`PATCHES` applies it after the branding patch. `make check` builds
without it, so the M1 comparison is unchanged; the patched `MSDOS.SYS` is
32 bytes longer.

## GRVER.EXE

`grver/grver.c`, C for the 8086, built with Open Watcom C and libc16 like
MEM. It is 1.7 KB. libc16 has no `printf`, so it uses `fputs` and
`libc16_ultoa`. It is in `C:\DOS` on a CF install and in the release ZIP's
`BIN`, but not on the floppy images.

```
GRVER [/?]
```

| Exit status | Meaning | Output |
|---|---|---|
| 0 | GR-DOS | `GR-DOS 0.04` (`%u.%02u`: always two digits after the point) |
| 0 | `/?` | the help |
| 1 | not GR-DOS | `GR-DOS kernel not detected.` |
| 2 | `AX=4752h`, but an answer that fails a check above | `GR-DOS kernel response not valid.` |
| 3 | a parameter other than `/?` | `Invalid parameter - X`, then the help |

In a batch file:

```bat
GRVER > NUL
IF ERRORLEVEL 1 GOTO NOTGRDOS
```

## Calling it from a program

C, with libc16, Open Watcom's or Microsoft C's `intdos`:

```c
#include <dos.h>

/* 1 and the version in *major, *minor on GR-DOS; 0 elsewhere. */
int grdos_version(unsigned *major, unsigned *minor)
{
    union REGS r;
    unsigned nonce = 0x5A3C;

    r.x.ax = 0x3347;
    r.x.bx = 0x4752;
    r.x.cx = 0;
    r.x.dx = nonce;
    intdos(&r, &r);
    if (r.x.ax != 0x4752 || r.x.dx != (unsigned)~nonce || r.h.cl < 1 || r.h.bl > 99)
        return 0;
    *major = r.h.bh;
    *minor = r.h.bl;
    return 1;
}
```

Assembly:

```asm
        mov     ax, 3347h
        mov     bx, 4752h               ; 'GR'
        xor     cx, cx
        mov     dx, 5A3Ch               ; a nonce
        int     21h
        cmp     ax, 4752h
        jne     not_grdos
        cmp     dx, 0A5C3h              ; NOT 5A3Ch
        jne     not_grdos
        or      cl, cl                  ; the revision: at least 1
        jz      not_grdos
        cmp     bl, 99
        ja      not_grdos
        ; GR-DOS: BH = major, BL = minor
```

## Tests

`make test-grver` (part of `make test`) runs `tests/grver/grver.bat` on
two kernels:

- **`test-grver-grdos`:** GR-DOS. GRVER's line must be `VERSION`'s exactly.
- **`test-grver-msdos`:** MS-DOS 4.00, the reference build's IO.SYS,
  MSDOS.SYS and COMMAND.COM (make check's, without `PATCHES`).

On each, the test checks:

- GRVER's output and exit status;
- `/?`, and two bad parameter lines;
- FAKEID (`tests/grver/fakeid.asm`), which hooks `INT 21h AX=3347h`, runs
  GRVER, and unhooks. Its imitations:

| FAKEID | The answer | GRVER |
|---|---|---|
| `U` | registers unchanged | status 1 |
| `D` | carry set, `AX=0001h` (DR DOS) | status 1 |
| `S` | `AX=4752h` only (`DX` is the nonce, not complemented) | status 2 |
| `C` | the same answer to both calls | status 2 |
| `M` | minor version 100 | status 2 |
| `R` | revision 0 | status 2 |
| `G` | a valid answer for 2.99 | `GR-DOS 2.99`, status 0 |
