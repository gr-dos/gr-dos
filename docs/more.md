# MORE

MORE is the first of the eight assembly utilities that issue #16 ports
from MS-DOS 4.00's sources to programs of GR-DOS's own. GR-DOS's MORE.COM
is C (`src/more/more.c`), built with Open Watcom C and libc16 like ATTRIB,
MEM, FDISK and FC, and it is on every image and in the CF card
distribution in place of the one assembled from `CMD/MORE/MORE.ASM`. That
one is still built, for `make check` and for the tests, which compare the
two.

## Why C, and how it is a .COM program

MORE.ASM is a loop over INT 21h calls, and C with libc16's `intdos`,
`int86` and `bdos` says the same in fewer lines, with the toolchain the
other C utilities already use. Free Pascal would have added a compiler,
and a runtime larger than the program, for nothing MORE needs.

MORE must stay a `.COM` program, and libc16's startup makes `.EXE` ones.
`src/lib/comstart.asm`, a few lines of assembly that any of GR-DOS's
`.COM` utilities can share, takes its place (libc16's "program without
the startup", `docs/spec/startup.md`): it puts the code in `DGROUP`, so
that `wlink format dos com` can link small-model C into one segment at
100h, zeroes `_BSS`, and calls `com_main`, whose result is the
errorlevel. The program may only use libc16 members that need no
`cstart`, and the build checks the map for that (`scripts/check-runtime`,
and no `cstart`). The flags are those of the other C utilities, without
the ones for Microsoft C's sources (`-j`, `-ei`, `-w0`), and with
warnings as errors:

```text
wcc -q -w4 -we -zld -zl -x -ms -0 -os -zp1 -s -bt=dos -Ibuild/libc16/include -I. more.c
wlink format dos com option nodefaultlibs file COMSTART.OBJ file MORE.OBJ library LIBC16.LIB
```

`-zp1` matters: the IOCTL and extended attribute structures are DOS's,
unaligned. The code is 8086 (`-0`), with no assembly but the startup.

Its messages are MORE.SKL's, from `USA-MS.MSG`, as before: `scripts/msgh`
writes the utility's own classes (`MORE.CLA`, from `scripts/buildmsg`) as
a C header of string literals (`MSG_A_2` is `"-- More --"`), so it needs
no message retriever. It works for the other utilities' message files
too.

| | MS-DOS 4.00 | GR-DOS |
|---|---:|---:|
| `MORE.COM` | 2,134 bytes | 1,102 bytes |
| Memory it uses (beyond the program) | 4,096-byte buffer | 4,096-byte buffer (`_BSS`) |

Like any `.COM` program it is given the largest free block, and the stack
is where DOS puts it, as with MORE.ASM.

## How MORE 4.00 behaves

GR-DOS's MORE keeps these, from MORE.ASM:

- It writes CR LF to standard output first, then its input, a character
  at a time, through INT 21h function 02h.
- Standard input is duplicated and closed, and handle 0 becomes a
  duplicate of standard error, so the keys come from the console (or
  `AUX` under `CTTY AUX`) even when the input is a file or a pipe. Its
  command line is ignored.
- The screen is 25 rows, or the rows a display driver reports for a text
  mode through generic IOCTL 440Ch on standard error (ANSI.SYS, which
  GR-DOS does not build yet), and the BIOS's columns (INT 10h function
  0Fh).
- Rows and columns are counted in bytes, so they wrap at 256: CR is column
  1, LF the next row, BS a column back but not before column 1, TAB the
  next tab stop (1, 9, 17, ...), even past the last column, as only a
  printed character wraps; BEL does not move, and every other byte,
  control characters included, is a column, the last column's wrapping to
  the next row. A line of exactly 80 columns therefore takes two rows,
  and lines ended by LF alone add up their columns.
- After the 24th row feed of a page (`currow >= maxrow`), "-- More --"
  goes to standard error, MORE flushes the input and waits for a key
  without echo (INT 21h function 0Ch, 08h), reads a second byte after a
  0 (an extended key), and writes CR LF CR LF to standard error. ^C there
  ends MORE, through DOS.
- ^Z ends the input, wherever it is; nothing after it is written.
- The errorlevel is 0.
- With code page switching active (INT 21h function 3303h), the input's
  code page extended attribute is set on standard output (functions 5702h
  and 5704h).
- Any DOS version but 4.00 gets "Incorrect DOS version" on standard error,
  and errorlevel 1, as SYSLOADMSG gives it.

### Differences

- **Read errors.** MORE.ASM took the error code of a failed read for the
  number of bytes read, and wrote that many bytes of its buffer; GR-DOS's
  MORE stops, with errorlevel 0. MORE's input is always open for reading,
  so this is only reached with a closed handle 0.
- **Before DOS 2.0** GR-DOS's MORE writes "Incorrect DOS version" through
  the console and ends with function 00h; MORE.ASM's function 4Ch did not
  exist there. Neither is tested: GR-DOS is DOS 4.00.

The three things not tested, as GR-DOS has neither ANSI.SYS nor NLSFUNC
(code page switching), are the rows from the display driver, the code
page attribute, and the version message.

## Tests

`make test-more` boots a 1.44 MB image whose AUTOEXEC.BAT is
`tests/more/more.bat`, under `CTTY AUX`, with the files of
`tests/more/mkfiles`: an empty file, 23, 24 and 25 lines (the first page
boundary), 100 lines, lines with no end and with LF only, lines of 79, 80,
81, 160 and 200 columns, tabs (from the last columns, and enough to take
the column past 255), BS, CR, BEL and the other control characters, every
byte, ^Z, files of 12 KB (with ^Z in the third buffer) and a line across
the 4,096-byte buffers. The tests of columns are repeated over several
pages, so that a wrong count moves the prompts. MORE reads each from a
file, from a pipe (`TYPE ... | MORE`), with arguments, with its output
redirected to a file, and with a missing input file; `EL.BAT` (FC's)
reports the errorlevel after each.

`scripts/smoke-test --keys tests/more/answers` answers each "-- More --" on
COM1 with the next key of the list (a letter, an extended key, Enter, the
space bar), and the output, up to `GRDOS-TEST-END`, must be
`tests/more/expect.log` byte for byte, CRs included. `make more-expect`
writes it with the MORE.COM assembled from MORE.ASM in place of GR-DOS's.

`make test-more-keys` runs MORE at the console instead
(`tests/more/keys`, `scripts/disk-test`): it pages `LONG.TXT` from a file
and from a pipe with the keyboard (a letter, F1, Enter, the space bar and
^C) and reads the screen after each, which must be the screens
MS-DOS 4.00's MORE gave (`make more-expect`, with
`disk-test --update --program`).
