# REPLACE

GR-DOS builds MS-DOS 4.00's REPLACE from Microsoft's C source with Open
Watcom C, JWasm and libc16, as it does FILESYS ([filesys.md](filesys.md))
(issue #21). It installs it in `C:\DOS`, and puts it on the 720 KB, 1.2 MB
and 1.44 MB floppies, after BACKUP and RESTORE: like XCOPY, it updates and
adds files, from one disk to another or to a hard disk. The 360 KB floppy
is unchanged. On a CF install, with floppies in A: and B:, GR-DOS tests it
against Microsoft's own build of the same source: its output, and the files
it leaves, to the second.

## What REPLACE does

```
REPLACE source [target] [/A] [/P] [/R] [/W]
REPLACE source [target] [/P] [/R] [/S] [/U] [/W]
```

`source` is a file name, which may have wildcards, with a drive and path;
`target` a directory, the current one by default. REPLACE lists the source
files that match (normal files: the search attribute is 0), and then:

- **without `/A`**, it looks in the target directory, and with `/S` in each
  of its subdirectories too, for files of the same names, and replaces
  them, with `/U` only those older than the source's (by date, then time:
  one as old is not replaced). The search there finds subdirectories but
  no hidden or system files, so those are never replaced;
- **with `/A`**, it copies the source files that the target directory does
  not have, as far as it can see: a hidden or system file of the same name
  is not seen, and creating the file over it is "Access denied".

`/P` asks "Replace NAME? (Y/N)" or "Add NAME? (Y/N)" for each file, through
DOS's country Y/N check (INT 21h 6523h), until the answer is one or the
other. `/R` replaces read-only files too; without it, a read-only target is
"Access denied", and REPLACE stops. `/W` waits for a key first. `/A` cannot
be used with `/S` or `/U`.

Each copy is made with DOS 4.00's extended open (INT 21h 6Ch, its critical
errors returned rather than raised), through a buffer of up to 64 KB from
DOS. It keeps the source's date and time, and gets the archive attribute; a
replaced file keeps the target's other attributes, read-only among them. If
the target disk fills, the part written is deleted, REPLACE says
"Insufficient disk space", and goes on with the next file, and the
errorlevel is 8. If APPEND is loaded, REPLACE sets its state to 0 while it
runs (INT 2Fh B707h), and puts it back. Its own handlers take Ctrl-C (errorlevel 3) and critical errors: it
calls DOS's handler, and if the answer is abort or fail, it ends with
errorlevel 1.

| Errorlevel | |
|---:|---|
| 0 | done, even when nothing was replaced or added |
| 1 | a critical error answered abort or fail, or another DOS error |
| 2 | no source files |
| 3 | a path not found, or Ctrl-C |
| 5 | access denied: a read-only file without `/R`, or a hidden one with `/A` |
| 8 | out of memory, or the target disk full |
| 11 | a parameter error |

An invalid drive is "Path not found" too, from DOS. REPLACE's
messages are `REPLACE.SKL`'s, the parser's and DOS's extended error
messages.

## Building

REPLACE is `CMD/REPLACE/REPLACE.C` with its own `_PARSE` and `_MSGRET`, and
`_REPLACE`, its Ctrl-C and critical error handlers, as `REPLACE.LNK` links
them, and its messages, from `REPLACE.SKL`. Microsoft's makefile also links
`MAPPER.LIB`, of which it calls nothing, and `INC/COMSUBS.LIB`, Microsoft
C object code only, of which it calls `com_strchr` and `com_strrchr`, the
DBCS forms of `strchr` and `strrchr`. For Open Watcom C, `REPLACE.C` has
those two, as `BACKUP.C` has them ([backup-restore.md](backup-restore.md),
"COMSUBS"), and neither library is linked.

It is compiled with the same `wcc` flags as FILESYS, and linked with
`wlink` and libc16, with libc16's startup and `REPLACE.LNK`'s 31,620-byte
stack: `main` keeps 500 directory entries on it. `scripts/check-runtime`
checks its map: it takes `cstart`, `argv`, `args`, `exit`, `intdos`,
`intdosx`, `int86`, `int86x`, `segread`, `strcat`, `strcpy`, `strcmp` and
`strlen` from libc16 0.15.

| | Microsoft (M1) | GR-DOS |
|---|---:|---:|
| `REPLACE.EXE` | 19,415 bytes | 14,786 bytes |

`make check` compares its message files (`REPLACE.CL1`, `REPLACE.CL2`,
`REPLACE.CLA`, `REPLACE.CTL`) with the M1 reference build. It does not
compare `REPLACE.EXE`, which is built with a different compiler, nor the
`_PARSE` and `_MSGRET` objects, which have the `ES` change below.

### Source edits

Every edit is under `#ifdef __WATCOMC__` in C or `IFDEF __JWASM__` in
assembly, so the Microsoft build is unchanged:

- **Calling convention.** `parse`, `sysloadmsg`, `sysdispmsg`, the handlers
  `crit_err_handler` and `ctl_brk_handler`, and `restore`, which the
  handlers call, are `#pragma aux (__cdecl)`. `REPLACE.C` includes
  `string.h` and `stdlib.h`, for libc16's declarations of the functions it
  calls without them.
- **`NULL`.** `REPLACE.C` defines its own, `0`, and uses it as a character;
  libc16's, `((void *)0)`, is undefined first.
- **`_psp`.** `REPLACE.C` reads the default DTA, at offset 80h of the PSP,
  through `_psp`, which it declared for Microsoft C's runtime to define; for
  Watcom, libc16's (`dos.h`) is it.
- **`display_msg`.** Its calls for messages that substitute nothing give
  no second argument, which Watcom C allows only of a function with a
  variable argument list, so for Watcom it has one, and reads the second
  argument only for the messages that substitute something (the six that
  substitute nothing are the only ones called without it). One `dcreate`
  call passes a pointer for an `unsigned`, and is cast.
- **`ES`.** Microsoft C kept `ES` equal to `DS`, and the parser and message
  retriever read their parameters through it; `_PARSE.ASM` and
  `_MSGRET.ASM` set it themselves, as BACKUP's do. (REPLACE.C's own
  `strcpy(fix_es_reg,NULL)`, after its far reads, was there to do the same
  through Microsoft C's `strcpy`; with libc16 it copies the two zero bytes
  at `DS:0`.)
- **`strcmp`.** Without `/P`, `docopy` takes `strcmp`'s result, of the
  source and target names, for the answer to its question, where 2 is "no".
  C promises only its sign, and Microsoft's REPLACE replaced the file;
  libc16's `strcmp` returns the difference of the bytes, and was 2 for
  `D:\R\C\A.TXT` and `D:\R\A\A.TXT`, and the file was not replaced. For
  Watcom only the sign is kept.
- **A switch with a value.** For `/R:X`, the parser matches `/R` but fills
  in no result, and `REPLACE.C` copies the switch from the result's
  synonym pointer: 0, or the last switch's. From a null pointer it took
  whatever its three-byte local held, which with Microsoft's build was no
  switch ("Invalid switch - /R:X"), and with Watcom's happened to be `R`.
  For Watcom, a null pointer is an invalid switch.

## How REPLACE 4.00 behaves

- **Directory order.** The source's files, and the target's, are taken in
  their directories' order, and REPLACE stops at the first error that is
  not a full disk: in a target with a read-only file, the files before it
  are replaced, and "N file(s) replaced" counts them.
- **Names.** Relative paths, `..` and a drive alone (its current
  directory) are made full first. A file onto itself is "File cannot be
  copied onto itself", and REPLACE goes on.
- **Switches.** A switch twice, or with a value, is "Invalid switch".
- **A write-protected target.** With `/R`, setting a read-only file's
  attributes is DOS's "Write protect error", and abort or fail ends
  REPLACE with errorlevel 1. For a file that is not read-only, the file is
  opened, and the error comes when DOS writes it: REPLACE then exits from its critical error
  handler with the file still open, closing it is the same error, and DOS
  asks again for each abort, as with Microsoft's REPLACE.

## Tests (`make test-replace`)

`scripts/replace-test` provisions a 512 MB CF image with
`scripts/deploy-cf` in `build/linux/tests/replace`, never on a block
device, with a 1.44 MB floppy image in A:, empty, and one in B:,
write-protected, with a file and a read-only one. It puts `D:\R` on the
image with mtools: the source `SRC`, nine copies of a target `T1` to `T9`,
one for each case, with a subdirectory, files older, as old as, newer and
two seconds older than the source's, a read-only one and a hidden one, and
a 1.6 MB file. It copies `tests/replace/rp.bat` to `C:\RP.BAT`,
`tests/replace/show.bat` to `C:\SHOW.BAT` (a directory's files, their
attributes and contents) and `EL.BAT` (`tests/join-subst/el.bat`) to
`C:\DOS`, writes `D:\AUTOEXEC.BAT` to run `C:\RP`, and boots the image in
QEMU, its clock from 2026-01-01 12:00. With `CTTY AUX`, the batch file runs:

- replace, `/R`, `/U /R`, `/S /R`, `/U /S` and `/A`;
- `/P` (yes, no, a wrong key and yes, no, yes), `/A /P` and `/W`, with
  the keys from `== keys` lines, which the script sends on COM1;
- the target as the current directory, `..`, a drive alone, paths from
  another directory and from another drive, the names whose `strcmp` is 2,
  and a file onto itself;
- adding and replacing on A: (FAT12), then filling it;
- B: write-protected, with `/R`, answered abort and then fail, and Ctrl-C
  at a question;
- nothing to do, bad paths and drives, and bad parameters.

COM1's output from `GRDOS-TEST-BEGIN` to `GRDOS-TEST-END` must be
`tests/replace/expect.log`, CRs included. Then `fsck.fat -n` must pass on
D: and A:, and their files and B:'s, read with mtools, must be
`tests/replace/files.txt`: each one's attributes, date and time to the
second, size and SHA-256, hidden files too, which DIR and ATTRIB do not
show. Both files are what Microsoft's REPLACE.EXE, from the M1 reference
build, does on the same install, with GR-DOS's kernel: `make
replace-expect` replaces `C:\DOS\REPLACE.EXE` with it (`REPLACE_REFERENCE`)
and writes them.

The floppy tests run `REPLACE DATA.TXT SUB` from the 720 KB, 1.2 MB and
1.44 MB disks (`tests/floppy`).
