# FC

GR-DOS builds MS-DOS 4.00's FC with Open Watcom C, JWasm and libc16, as it
does FDISK ([FDISK](fdisk.md)), puts it on every image, and tests it in QEMU
against Microsoft's own build of the same source.

## Building

FC is C (`FC`, `ERROR`, `FGETL`, `NTOI`, `UPDATE` and `INC/KSTRING.C`) with
assembly modules written with `CMACROS.INC` (`GETL`, `ITOUPPER`, `MAXMIN`,
`MOVE`, `STRING`, `XTAB`) and its messages, `MESSAGES.ASM`. Unlike the other
utilities, it has no `.SKL` and no message retriever: its messages are
strings in `MESSAGES.ASM`. It is compiled with the same `wcc` flags as
ATTRIB, MEM and FDISK, linked with `wlink` and libc16, and
`scripts/check-runtime` checks its map: it takes `cstart`, `exit`, `bdos`,
`intdos`, `fopen`, `fgetc`, `fgets`, `fputs`, `fwrite`, `malloc`,
`strerror`, `strcpy`, `strlen`, `strcmp`, `tolower`, `isxdigit`,
`ltoa` and `ultoa` from libc16 0.04.

| | Microsoft (M1) | GR-DOS |
|---|---:|---:|
| `FC.EXE` | 15,807 bytes | 8,392 bytes |

`FC.EXE` is not compared by `make check`, as it is built with a different
compiler. The six assembly modules assemble to the same code as MASM's.

### Source edits

Every edit is under `#ifdef __WATCOMC__` in C or `IFDEF __JWASM__` in
assembly, so the Microsoft build is unchanged (`scripts/check-reference`):

- **`CMACROS.INC`.** Its macros define macros with MASM 5's `&macro` and
  `&endm`, and rely on how MASM 5 removes `&` in nested `IRP` loops, which
  JWasm does not do. Under JWasm, `INC/CMACROS.INC` is instead the part FC's
  modules use, for the small model and the C calling convention: `sBegin`,
  `sEnd`, `assumes`, `cProc` (public, with a list of registers to save),
  `parmB`, `parmW`, `parmD`, `cBegin`, `cEnd`, `cCall` (one argument),
  `externB`, `externP`, `staticW`, `globalB` and the like, written to give
  the same code. It stops with an error for any other model or language.
  `ITOUPPER.ASM` uses `C` as a parameter name (`OPTION NOKEYWORD`).
- **Calling convention.** `#pragma aux (__cdecl)` for the assembly
  routines and for `KSTRING.C`'s `toupper`, `strpbrk` and `strupr`, which
  take the place of the C library's (they use DOS's country case map, so
  `/C` folds code page 437's accented letters as DOS does). `fgetl`,
  `strcmpi`, `strcmps` and `strcmpis`, which FC calls through the pointers
  `funcRead` and `fCmp`, as it does `fgets` and `strcmp`, are declared
  `__cdecl`, as are the pointers.
- **`TTYPES.H`.** Four prototypes FC does not use, which are not valid C
  (`forsemi`, `rspawnl`, `rspawnv`, `forfile`), are left out.
- **`printf` and `sprintf`.** libc16 has neither. FC uses `%s`, `%5d` and
  `%0nlX` / `%02X`: `fc_format`, `fc_dec` and `fc_hex`, in `FC.C`, do them
  with `libc16_ltoa` and `libc16_ultoa`. As with `printf`, each line is
  written to DOS in one call (`fc_flush`): DOS stops writing to a device at
  a `^Z`, so a line holding one is cut there, as with Microsoft's FC.
- **`ERROR.C`.** `sys_errlist[errno]` becomes `strerror(errno)`; libc16's
  texts are Microsoft C's ("No such file or directory", "Permission
  denied").
- **Version check.** `_osmajor` and `_osminor` come from `bdos(0x30)`.
- **`ISSPACE`.** Microsoft C's `_ctype_` table becomes the test it made:
  blank and 09h to 0Dh.
- **Buffer overruns.** Microsoft's FC copies each file name into an 80-byte
  array on the stack, and a third name past the two; an argument of 80
  characters or more overwrites the stack (Microsoft C's `R6001` "null
  pointer assignment", and garbled output, in the test). Its 128-byte
  `line`, which holds "cannot open" and "longer than" messages, is overrun
  by long names. GR-DOS's FC has room for any argument of the command line
  (127 characters), only counts a third name for its usage message, and
  `line` holds two such names; `fc_format` stops at its end in any case.
  `fc_puts` writes a line too long for `fc_out` in more than one call
  rather than overrun it, though no output of FC's is that long.
- **Out of memory.** `usage(NoMem)` gave no exit code, so Microsoft's FC
  exits with whatever was on the stack (52 in the test); GR-DOS's exits
  with 1.

## How FC 4.00 behaves

The tests keep these quirks of Microsoft's FC:

- Files ending in `.EXE`, `.OBJ`, `.LIB`, `.COM`, `.BIN` or `.SYS` are
  compared byte by byte unless `/L` is given; others line by line.
- When FC finds differences between lines, its `main` returns no value,
  so the errorlevel is whatever is left in `AX`: 0 or 1 in the tests. Byte
  differences, a file longer than the other and the errors give 1, and no
  differences 0.
- The resync message prints a literal `\n`: `MESSAGES.ASM` is assembled,
  and MASM does not know C's escapes.
- `/T` reads lines with `fgets`, which does not expand tabs and keeps each
  line's CR, so FC writes it before its own CR LF.
- A line of more than 127 characters is read as more than one.
- `/LBn` sets the number of lines FC keeps (100); FC needs 130 bytes for
  each in each of two buffers, so `/LB400` runs out of memory.
- FC takes no wildcards: `FC *.TXT A.TXT` cannot open `*.TXT`.

## Tests (`make test-fc`)

`tests/fc/fc.bat` is the AUTOEXEC.BAT of a 1.44 MB test image with the
files of `tests/fc`. It runs FC with each switch (`/A`, `/B`, `/C`, `/L`,
`/LBn`, `/N`, `/T`, `/W` and `/nnnn`), on identical and different files,
files of different lengths, a file ending in `^Z`, lines longer than FC's
buffer, code page 437 letters with `/C`, `.EXE` files, and each error
(usage, bad and incompatible switches, a missing file or directory, a
directory, a wildcard). It also compares files of 400 lines, with `/LB50`
too, so that FC refills and resynchronises its buffers; files of the same
line repeated, which resynchronise on the wrong lines; and the longest
paths DOS allows. After each command, `EL.BAT` reports the errorlevel. The
output goes to COM1 (`CTTY AUX`).

Up to the line `GRDOS-AB-END`, `tests/fc/expect.log` is what Microsoft's
FC.EXE, from the M1 reference build, writes in the same image
(`make fc-expect`); GR-DOS's must be the same, byte for byte, CRs included.
After it come the arguments that overran Microsoft's buffers (a 116- and
an 84-character name), checked against `tests/fc/expect`.
