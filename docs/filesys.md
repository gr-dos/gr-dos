# FILESYS

GR-DOS builds MS-DOS 4.00's FILESYS from Microsoft's C source with Open
Watcom C, JWasm and libc16, as it does JOIN and SUBST
([join-subst.md](join-subst.md)) (issue #20). It installs it in `C:\DOS`,
and on no floppy. On a CF install it tests it against Microsoft's own build
of the same source.

## What FILESYS is

FILESYS is IFSFUNC's command line. `FILESYS.C` describes it as "an
interface to IFSFUNC to allow assignment of logical drive letters to
various devices": it attaches a drive or device to an installable file
system (IFS), detaches it, and lists what is attached. IFSFUNC
(`CMD/IFSFUNC`, issue #17) is the resident part of DOS that passes requests
for those drives and devices to an IFS driver, loaded with `IFS=` in
CONFIG.SYS. FILESYS does nothing by itself, and the source has no file
system of its own.

```
FILESYS                         lists what is attached
FILESYS name                    shows one drive (E:) or device (LPT1)
FILESYS name fsname [p1 [p2]]   attaches it to the file system fsname
FILESYS name /D                 detaches it
```

Each is one DOS call, INT 21h AH=5Fh, the redirector functions that DOS
passes on through INT 2Fh, to IFSFUNC or a network redirector:

| Call | FILESYS's use |
|---|---|
| 5F06h | the list of attachments, one entry (BX) at a time, until an error or 18 (no more files) |
| 5F00h | whether a network printer or drive is paused, for the list's status column |
| 5F03h | attach: BL 2 for a drive (the name has a `:`), 1 for a device; DS:SI the name, DS:DI the file system's name and parameters |
| 5F04h | detach: DS:SI the name |
| 5900h | the extended error of a failed attach or detach, shown with its message |

The list prints a header and a line for each entry, with "PAUSED" or
"ERROR" in the status column, or "No entries found". FILESYS's messages
(`FILESYS.SKL`) are its header and those lines, and "No entries found";
the rest are the parser's and DOS's extended error messages.

## On GR-DOS

GR-DOS has no IFS driver, and no network, so nothing can be attached:

- **Without IFSFUNC**, DOS answers each 5Fh call with error 1. The list
  shows "No entries found", and attach and detach "Invalid function".
- **With IFSFUNC**, loaded from the command line (it says "Invalid
  configuration", as there is no driver, and stays resident), the list is
  the same, and attach and detach say "NET809: Network request not
  supported".

These are the same with Microsoft's FILESYS.EXE on GR-DOS's kernel: the
test below shows both.

## Building

FILESYS is `CMD/FILESYS/FILESYS.C` with its own `_PARSE` and `_MSGRET`, as
its makefile links it, and its messages, from `FILESYS.SKL`. It calls
nothing of `COMSUBS.LIB` or `MAPPER.LIB`. It is compiled with the same
`wcc` flags as JOIN and SUBST, and linked with `wlink` and libc16, with
libc16's startup. `scripts/check-runtime` checks its map: it takes
`cstart`, `argv`, `args`, `exit`, `intdos`, `intdosx`, `int86`, `int86x`,
`strcpy`, `strchr`, `stricmp` and `strncat` from libc16 0.15.

| | Microsoft (M1) | GR-DOS |
|---|---:|---:|
| `FILESYS.EXE` | 11,129 bytes | 8,774 bytes |

`make check` compares its message files (`FILESYS.CL1`, `FILESYS.CL2`,
`FILESYS.CLA`, `FILESYS.CTL`) with the M1 reference build. It does not
compare `FILESYS.EXE`, which is built with a different compiler.

FILESYS's `_PARSE.ASM` and `_MSGRET.ASM` are an older form than JOIN's:
the parser and the message retriever are in `_DATA`, in DGROUP, and the C
interfaces in `_TEXT` call them far, with CS equal to DGROUP. `_PARSE`'s
`CallParser` sets DS and ES to DGROUP itself.

### Source edits

Every edit is under `#ifdef __WATCOMC__` in C or `IFDEF __JWASM__` in
assembly, so the Microsoft build is unchanged:

- **Calling convention.** `parse`, `sysloadmsg` and `sysdispmsg` are
  `#pragma aux (__cdecl)`, as in JOIN and SUBST. FILESYS.C includes
  `stdio.h`, `stdlib.h` and `string.h`, so libc16 declares the rest.
- **`strcmpi`.** Microsoft C 5.1's other name for `stricmp`, which libc16
  has; FILESYS.C defines the one as the other.
- **`NULL`.** FILESYS.C defines its own, `0`, after the headers, and uses
  it as a character (`name[0] == NULL`). libc16's is `((void *)0)`, which
  FILESYS.C's then replaces.
- **`ES`.** Microsoft C kept `ES` equal to `DS`, and the message retriever
  reads through it. `_MSGRET.ASM` sets it, as JOIN's does.
- **Errorlevel.** `main` is `void`, and only the parse errors call
  `exit(1)`. Otherwise Microsoft C's startup passed whatever `AL` held to
  DOS: 202 after a list, 132 after an attach, 44 or 54 after a detach,
  depending on the last call. For Watcom, `main` ends with `exit(0)`.

## How FILESYS 4.00 behaves

- **Errorlevels.** 1 for a parse error, else undefined (above); GR-DOS's
  is 0.
- **Parsing.** The first parameter is a drive (`E:`) or, failing that, any
  word (a device, `LPT1`); up to three more words follow, the file system
  and two parameters for it. More is "Too many parameters". `/D` must be
  the second parameter, else "Parameter format not correct", as is `/D`
  twice; any other switch is "Invalid switch".
- **Name.** `FILESYS E:` and `FILESYS LPT1` show only that entry, and
  "No entries found" if it is not attached.
- **Errors.** A failed attach or detach shows DOS's extended error message
  on standard error, and FILESYS goes on: the errorlevel does not show it.

## Tests (`make test-filesys`)

`scripts/filesys-test` provisions a 512 MB CF image with
`scripts/deploy-cf` in `build/linux/tests/filesys`, never on a block
device. It copies `tests/filesys/fs.bat` to `C:\FS.BAT`, and the errorlevel
reporters `EL.BAT` (`tests/join-subst/el.bat`) and `ELU.BAT` to `C:\DOS`,
writes `D:\AUTOEXEC.BAT` to run `C:\FS`, and boots the image in QEMU
(`scripts/hd-boot-test`). With `CTTY AUX`, the batch file runs each case
twice, without IFSFUNC and then with it: the list, one drive and one
device, attaching a drive and a device with parameters, detaching E:, C:
and LPT1, and each parse error above.

COM1's output from `GRDOS-TEST-BEGIN` to `GRDOS-TEST-END` must be
`tests/filesys/expect.log`, CRs included. That file is what Microsoft's
FILESYS.EXE, from the M1 reference build, writes on the same install, with
GR-DOS's kernel: `make filesys-expect` replaces `C:\DOS\FILESYS.EXE` with
it (`FILESYS_REFERENCE`) and writes it. The one difference allowed is the
errorlevel where Microsoft's is undefined: there the batch file calls
`ELU.BAT`, which reports it as `errorlevel? N`. The comparison ignores N,
and GR-DOS's must be 0.
