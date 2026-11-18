# JOIN and SUBST

GR-DOS builds MS-DOS 4.00's JOIN and SUBST from Microsoft's C source with
Open Watcom C, JWasm and libc16, as it does FC ([FC](fc.md)) (issue #18).
It installs them in `C:\DOS` and puts them on the 1.2 MB and 1.44 MB
floppies. On a CF install, with C: and D:, it tests them against
Microsoft's own build of the same source.

- `JOIN d: path` makes drive `d:` appear as the directory `path` of another
  drive. `JOIN d: /D` undoes it, and `JOIN` lists the joins.
- `SUBST d: path` makes drive `d:` a name for `path`. `SUBST d: /D` undoes
  it, and `SUBST` lists the substitutions.

Both work on DOS's current directory structures (CDS), its table of
drives, which they read and write directly, from the list of lists that
INT 21h 52h returns.

## Building

Each program is its C module (`CMD/JOIN/JOIN.C`, `CMD/SUBST/SUBST.C`) with
four of INC's C modules, shared by both: `ERRTST` (paths, current
directories, find first), `SYSVAR` (the list of lists), `CDS` (the drive
table) and `DPB` (the drive parameter blocks). Each also has its
assembly interfaces to the parser and the message retriever, `_PARSE` and
`_MSGRET`, and its messages, from `X.SKL`. The objects are those of
`X.LNK`. Microsoft's makefiles also link two libraries:

- **`INC/COMSUBS.LIB`** is Microsoft C object code only, with no source in
  the tree. Its modules call Microsoft C's runtime (`__chkstk`, `_malloc`)
  and OS/2 API routines from `MAPPER`. JOIN and SUBST call only
  `com_substr`, through `ERRTST.C`'s `strbscan` and `rootpath`. For Open
  Watcom C, `ERRTST.C` has its own `com_substr`, and the library is not
  linked.
- **`MAPPER/MAPPER.LIB`**: neither program calls any of its routines.

They are compiled with the same `wcc` flags as ATTRIB, MEM, FDISK and FC,
and linked with `wlink` and libc16, with libc16's startup.
`scripts/check-runtime` checks their maps. JOIN takes `cstart`, `argv`,
`args`, `exit`, `intdos`, `intdosx`, `int86`, `int86x`, `mkdir`, `fputs`,
`stdout`, `write`, `strcat`, `strcpy`, `strlen`, `strcmp` and `strncmp`
from libc16 0.15, with `errno`, `doserr` and `fdtab`. SUBST takes the
same, but with `malloc`, `free`, `open` and `access` in place of `mkdir`.

| | Microsoft (M1) | GR-DOS |
|---|---:|---:|
| `JOIN.EXE` | 17,813 bytes | 10,344 bytes |
| `SUBST.EXE` | 18,467 bytes | 11,558 bytes |

`make check` compares their message files (`JOIN.CL1`, `JOIN.CL2`,
`JOIN.CLA`, `JOIN.CTL`, and SUBST's) with the M1 reference build. It does
not compare `JOIN.EXE` and `SUBST.EXE`, which are built with a different
compiler.

### com_substr

`COMSUBS.LIB`'s `com_substr(s, t)` returns a pointer to the first
occurrence of the string `t` in the string `s`, or NULL. It skips a match
whose previous byte is a lead byte of the DBCS vector (INT 21h 63h). This
was read from the library's `cmsubstr` and `cmdbcs` modules, which are
part of the MIT-licensed MS-DOS 4.00 source, disassembled with `wdis`.
The C in `ERRTST.C` is GR-DOS's own and does the same. No Open Watcom
runtime code was read for it.

`com_substr` finds a substring, not one of a set of characters, so
`strbscan(p, "/\\")` looks for the two characters `/\`. JOIN's
`*strbscan(path+3, "/\\") != 0` was meant to refuse a directory below the
root, but it never matches a path from `rootpath`. So JOIN 4.00 joins a
drive to any empty directory, `C:\JN\DEEP` as well as `C:\MNT`, and so
does GR-DOS's.

### Source edits

Every edit is under `#ifdef __WATCOMC__` in C or `IFDEF __JWASM__` in
assembly, so the Microsoft build is unchanged:

- **Calling convention.** JOIN.C and SUBST.C call `strcat`, `strcpy`,
  `mkdir`, `exit` and others without including their headers. Watcom
  would call them with its register convention, so the C files include
  libc16's `string.h`, `stdlib.h`, `direct.h`, `stdio.h` and `io.h`, which
  declare them `__cdecl`. `ERRTST.C` does the same. The two programs'
  declarations of `strchr` and `malloc`, without `__cdecl`, give way to
  libc16's. `parse`, `sysloadmsg`, `sysgetmsg` and `sysdispmsg` are
  `#pragma aux (__cdecl)`, as in ATTRIB and MEM.
- **`char` returns.** JOIN and SUBST call `fPathErr`, `fPhysical`, `fNet`,
  `fShared` and `getdrv`, which return `char`, without declaring them, so
  as if they returned `int`. Watcom C returns a `char` in `AL` and leaves
  `AH` as it is, so a FALSE could read as true. The programs declare them.
- **`dispmsg_terminate`.** Its K&R definition takes a message number and a
  substitution, but its calls for the messages that substitute nothing
  (`MSG_NETERR`, `MSG_NOMEM`) pass only the number, which Watcom refuses,
  and which leaves `outline` undefined. For Watcom those calls pass a null
  pointer, and a prototype declares both parameters. `display_msg` uses no
  substitution for those messages, so the output is the same.
- **`printf`.** libc16 has none. `DoList` and `Display` print
  `"%c: => %s\n"`. They build the same line and write it with one `fputs`,
  and `ERRTST.C`'s `Fatal`, which nothing calls, writes its message with
  `fputs`.
- **`ES`.** Microsoft C kept `ES` equal to `DS`, and the parser and message
  retriever read their parameters through it. `_PARSE.ASM` and
  `_MSGRET.ASM` set `ES` themselves, as ATTRIB's do. The calls to
  `strcpy(fix_es_reg, NULL)` that "set ES correct" stay: libc16's startup
  keeps `DS:0000` zero, so they copy an empty string, as with Microsoft C.
- **`inregs` and `outregs`.** `ERRTST.C` and each program define both.
  Microsoft C made the two definitions one communal variable, but Watcom
  would define them twice, so `ERRTST.C` declares them `extern`.
- **Overrun.** `GetVars` and `PutVars` copy `sizeof(SysVars) + 1` bytes
  (`i <= sizeof`). `GetVars` overwrites the byte after `SysVars` in the
  program, and `PutVars` writes it back to DOS. They copy
  `sizeof(SysVars)` bytes.
- **DBCS vector.** `testkanj` looks for the vector's end, a word of 0, by
  comparing each word with `(unsigned)"00"`, the address of a string. In a
  single-byte country it never finds it, and reads DOS's memory past the
  vector until a word happens to equal that address. A pair of bytes there
  could make it take a path character for a DBCS lead byte. The loop now
  ends at the word of 0. In Microsoft's programs nothing reaches the loop:
  `fPathErr` calls `testkanj` only for a path that is a prefix of its
  drive's current directory, which never happens, as JOIN's check below
  shows. But GR-DOS's `com_substr` calls it for the byte before each
  match, where `COMSUBS.LIB`'s called its own `check_dbcs`, so it must
  end.

## How JOIN and SUBST 4.00 behave

The tests keep these behaviours of Microsoft's programs:

- **Errorlevels.** 0 on success, and 1 for every error, a listing never
  fails.
- **Messages.** "Invalid parameter", "Too many parameters", "Incorrect
  number of parameters" (SUBST's, for a drive, path and `/D`), "Invalid
  switch", "Path not found" (SUBST) and "Directory not empty" (JOIN), each
  followed by the parameter as the parser read it, with its trailing
  blanks.
- **SUBST.**
  - The path must exist and be a directory, or "Path not found". A file is
    "Invalid parameter".
  - `SUBST E: D:\` works, but `SUBST E: D:\JS\WORK\`, with a trailing
    backslash, is "Path not found", as is `..` past the root.
  - Relative paths (`D:WORK`, `..\JS\WORK\SUB`, `.`) are made full with
    the drive's current directory.
  - It refuses the current drive, a drive already substituted or joined,
    a drive past LASTDRIVE (E: by default, so F: and Q: are invalid), and a
    path on the drive itself. `SUBST E: /D` refuses a drive that is not
    substituted, and E: while it is the current drive.
  - SUBST on a floppy drive, A:, works, and `/D` gives it back its own
    drive parameter block.
- **JOIN.**
  - The drive must be a physical one, not the current drive, a SUBST
    drive or a drive with no DPB (E:).
  - The directory must be on another drive. If it does not exist, JOIN
    makes it (`C:\MNT`, `C:\NEWDIR`). If it does, it must be empty
    ("Directory not empty"), not a file, not the root, and its parent must
    exist (`C:\NO\SUCH`).
  - The directory may be at any depth (see `com_substr`).
  - JOIN's check that the directory is not the current directory of its
    drive compares `C:\INUSE` with the current directory DOS returns,
    `\INUSE`, which has no drive letter, so it never matches: `CD \INUSE`
    then `JOIN D: C:\INUSE` works.
  - `JOIN D: /D` while C:'s current directory is the join's is refused.
  - After `JOIN D: C:\MNT`, `D:` is an invalid drive, and what is written
    to `C:\MNT` is on D: once it is unjoined.
- **Parsing.** Each program joins its arguments with blanks and gives the
  line to the DOS parser. So `SUBST E:D:\JS\WORK` and `JOIN D:C:\MNT`,
  with no blank, are one parameter, and invalid. `JOIN D C:\MNT` and
  `SUBST 1: ...` are invalid drives, and `/D` twice is an invalid switch.

## Tests (`make test-join-subst`)

`scripts/join-subst-test` provisions a 512 MB CF image with
`scripts/deploy-cf` in `build/linux/tests/join-subst`, never on a block
device. It copies `tests/join-subst/js.bat` to `C:\JS.BAT` and the
errorlevel reporter `EL.BAT` to `C:\DOS`, writes `D:\AUTOEXEC.BAT` to run
`C:\JS`, and boots the image in QEMU (`scripts/hd-boot-test`). The batch
file is on C:, as D: is joined during it. It runs about 115 commands, with
`CTTY AUX`:

- each SUBST form and error above, on D: (the data volume), A: and E:;
- each JOIN form and error, with D: joined to directories of C: (the
  system volume) and A: to `C:\FLOPPY`;
- files read and written through the joins and substitutions, then read
  through the drives themselves.

COM1's output from `GRDOS-TEST-BEGIN` to `GRDOS-TEST-END` must be
`tests/join-subst/expect.log`, byte for byte, CRs included. That file is
what Microsoft's JOIN.EXE and SUBST.EXE, from the M1 reference build, write
on the same install, with GR-DOS's kernel: `make join-subst-expect`
replaces `C:\DOS\JOIN.EXE` and `C:\DOS\SUBST.EXE` with them
(`JOIN_REFERENCE`, `SUBST_REFERENCE`) and writes it.

The floppy tests (`make test-floppy-1200`, `test-floppy-1440`) run SUBST and
JOIN from A: too: `SUBST E: B:\SUB`, which `SUBST` lists and `TYPE E:\...`
reads through, `SUBST E: /D`, and `JOIN`. On 720 KB and 360 KB they are a
bad command or file name.
