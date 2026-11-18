# BACKUP and RESTORE

GR-DOS builds MS-DOS 4.00's BACKUP and RESTORE from Microsoft's C source with
Open Watcom C, JWasm and libc16, as it does JOIN and SUBST
([JOIN and SUBST](join-subst.md)) (issue #19). Each is a `.COM` program,
as Microsoft's are. GR-DOS installs them in `C:\DOS`, and puts them on the
720 KB, 1.2 MB and 1.44 MB floppies, after KEYB: restoring a hard disk starts
from a floppy. The 360 KB floppy is unchanged. On a CF install with a
1.44 MB drive A:, GR-DOS tests them against Microsoft's own build of the
same source: their output, and the backup they write, byte for byte.

- `BACKUP source target: [/S] [/M] [/A] [/D:date] [/T:time] [/F[:size]]
  [/L[:file]]` backs up files to floppies, numbered disk by disk, or to
  `target:\BACKUP` on a hard disk. Each disk holds `BACKUP.nnn`, the files'
  data, and `CONTROL.nnn`, their names, paths, attributes, dates and times,
  and where each part is. A file goes on from one disk to the next.
- `RESTORE source: target [/S] [/P] [/B:date] [/A:date] [/E:time]
  [/L:time] [/M] [/N]` puts the files back, making their directories, with
  their attributes, dates and times. It reads DOS 2.0 to 3.2's format
  (`BACKUPID.@@@`) too.

`HELP BACKUP` and `HELP RESTORE` give the switches and errorlevels.

## Building

BACKUP is one C module, `CMD/BACKUP/BACKUP.C`. RESTORE is the twelve of
`RESTORE.LNK`: `RESTORE`, `RESTPARS`, `RTT1`, `RTT3`, `RTDO`, `RTDO1`,
`RTOLD`, `RTOLD1`, `RTNEW`, `RTNEW1`, `RTFILE` and `RTFILE1`. Each has its
assembly interfaces to the parser and the message retriever, `_PARSE` and
`_MSGRET`, and its messages, from `X.SKL`. Microsoft's makefiles also link
two libraries:

- **`MAPPER/MAPPER.LIB`**, the OS/2 API on DOS, in assembly. Both programs
  call it for their file, directory, disk and memory work (`DOSOPEN`,
  `DOSREAD`, `DOSFINDFIRST`, `DOSALLOCSEG`, `DOSSETSIGHANDLER` and so on).
  As FDISK does, GR-DOS links the objects of the routines they call, which
  JWasm assembles from `MAPPER`: 20 for both (with `DEVCONFG`, which
  `QCURDSK` calls), and `ERROR`, `FREESEG`, `GET_TOD`, `SEL_DISK` and
  `SETFSINF` for BACKUP, `QFILEINF` and `SFILEINF` for RESTORE.
- **`INC/COMSUBS.LIB`** is Microsoft C object code only, with no source in
  the tree. BACKUP calls `com_strchr`, `com_strrchr` and `com_toupper`
  from it; RESTORE, `com_toupper` and `rctomid`. For Open Watcom C,
  `BACKUP.C` and `RTT3.C` have their own (see below), and the library is
  not linked.

They are compiled with the same `wcc` flags as JOIN and SUBST, and linked
with `wlink` and libc16, with libc16's startup, as `.EXE` programs, which
`scripts/convert` (Microsoft's CONVERT, issue #17) makes into `.COM`
programs that load the `.EXE` they hold, as Microsoft's makefiles do.
RESTORE has RESTORE.LNK's 50,000-byte stack; BACKUP, which names none, has
2,048 bytes, Microsoft C's default and libc16's. `scripts/check-runtime`
checks their maps. From libc16 0.15, BACKUP takes `cstart`, `argv`, `args`,
`exit`, `intdos`, `intdosx`, `int86`, `int86x`, `segread`, `malloc`,
`free`, `mkdir`, `rmdir`, `chdir`, `spawnv` (with `spawnx`, `dosexec` and
`envblock`), `strcat`, `strcpy`, `strncpy`, `strlen`, `strcmp`, `strchr`
and `i4m`, with `errno` and `doserr`. RESTORE takes much the same, but
`fputs`, `stdout`, `write`, `fdtab` and `u4d` in place of the heap,
`rmdir`, `spawnv`, `strchr` and `segread`.

| | Microsoft (M1) | GR-DOS |
|---|---:|---:|
| `BACKUP.COM` | 36,880 bytes | 25,231 bytes |
| `RESTORE.COM` | 36,946 bytes | 27,015 bytes |

`make check` compares their message files (`BACKUP.CL1`, `BACKUP.CL2`,
`BACKUP.CLA`, `BACKUP.CTL`, and RESTORE's) with the M1 reference build. It
does not compare `BACKUP.COM` and `RESTORE.COM`, which are built with a
different compiler, nor the `_PARSE` and `_MSGRET` objects, which have the
`ES` change below. RESTORE's message build warns that message 31 of
RESTORE is not found, as Microsoft's does: its files are the same.

### COMSUBS

What the two programs call of `COMSUBS.LIB` was read from the library's
modules, which are part of the MIT-licensed MS-DOS 4.00 source,
disassembled with `wdis`. The C is GR-DOS's own, and does the same. No Open
Watcom runtime code was read for it.

- `com_toupper(c)` maps `a` to `z` alone to upper case (through a table
  that `DosCaseMap` makes).
- `com_strchr(s, c)` returns the first `c` in `s`, skipping both bytes of a
  double-byte character; `com_strrchr(s, c)` the last `c` whose previous
  byte is not a lead byte. Lead bytes are those in the ranges of DOS's
  DBCS vector (INT 21h 6300h), of which `check_dbcs` reads at most five.
- `rctomid(rc)` returns `rc`.

### Source edits

Every edit is under `#ifdef __WATCOMC__` in C or `IFDEF __JWASM__` in
assembly, so the Microsoft build is unchanged:

- **Calling convention.** `parse`, `sysloadmsg`, `sysdispmsg` and BACKUP's
  `update_logfile` are `#pragma aux (__cdecl)`. RESTORE's files include
  libc16's `direct.h` and `stdlib.h` (through `RT2.H`) for `chdir`, `mkdir`
  and `exit`, which they call without them.
- **`ES`.** Microsoft C kept `ES` equal to `DS`, and the parser and message
  retriever read their parameters through it, so `_PARSE.ASM` and
  `_MSGRET.ASM` set `ES` themselves, as ATTRIB's do.
- **`set_int24_vector`.** MAPPER's `SETINT24` takes a word and pops it,
  which the programs' `(void)` prototype does not pass. Watcom C keeps to
  the prototype, and the stack would lose two bytes, so for Watcom it takes
  the word, and the calls pass 0.
- **`printf` and `sprintf`.** libc16 has neither. RESTORE prints only
  `"\n"`, with `fputs`. BACKUP's `sprintf` builds file names and log lines
  with `%c`, `%s`, `%u`, `%02u` and the like, so `BACKUP.C` has a small
  `sprintf` for those conversions.
- **`spawnlp`.** BACKUP runs FORMAT for `/F` with
  `spawnlp(P_WAIT, path, "FORMAT", "A: /F:size /BACKUP /V:BACKUP", NULL)`,
  one argument with blanks. libc16's spawn functions quote such an
  argument, so it is split into its words for `spawnv`, which gives FORMAT
  the same command line. `path` is FORMAT's full path, which BACKUP found
  itself.
- **The heap.** BACKUP keeps its directory tree in the near heap, but first
  allocates its buffer from DOS, just above the program. libc16's heap grows
  the program's memory block as it needs to, which the buffer above it then
  stops. So BACKUP first takes as
  much heap as DGROUP has room for, and frees it: libc16's `free` keeps it
  for the tree.
- **`buf_pointer`.** `RESTORE.C` and `RTDO.C` define it as a near pointer,
  two bytes, and `RTT3.C`, which sets it, as a far pointer, four. Microsoft
  C made all three one communal variable of the largest size. Open Watcom C
  makes each an ordinary definition, and the linker took a two-byte one, so
  `RTT3.C` wrote the segment over the first two bytes of `infspec`, the
  file name to restore, and RESTORE found nothing. For Watcom, the two are
  far pointers too. No other variable of either program is defined with
  two sizes.
- **`fileheader_length`.** `RTNEW1.C` reads two bytes, the length of a file
  header in `CONTROL.nnn` and the first letter of its file name, into this
  one-byte variable. With Microsoft C the second byte fell on nothing that
  mattered; with Watcom C it fell on `got_first_fh`, and RESTORE took the
  first file of each directory to be read already, and skipped it. For
  Watcom it reads them into a word, and keeps the low byte.
- **`backdir`.** `RESTPARS.C` sets this local only when the target path
  has `..` in it, and then makes RESTORE check that the target's directory
  exists (in RESTORE, `TRUE` is 0). Microsoft C's stack happened to leave it
  nonzero; Watcom C's left 0, and RESTORE stopped with "Invalid path" when a
  directory it was to restore, and make, was gone. For Watcom it starts
  false.
- **`fsinfo_buf`.** `RTFILE1.C`'s `dos_write_error`, which works out
  whether the target is full when a write fails, passes `DOSQFSINFO` this
  pointer without ever setting it, and the free space lands wherever it
  points. For Watcom it points to a buffer on the stack.
- **`main`.** `RT2.H` declares `main(int, char *[0])`, which Watcom C
  refuses: `char *[]`.

`MAPPER/QFILEINF.ASM` (`DOSQFILEINFO`, which only RESTORE calls) ends by
storing the file's attribute at `[bp].Attributes`, where its `FileInfo`
structure has it, but relative to `BP`, not to the caller's buffer: two
bytes of the caller's stack, past the routine's parameters. Under Microsoft
C these were nothing that mattered. Under Open Watcom C they are bytes 6
and 7 of `switchmatch`'s `search_string`, the path of the file on the
target, which `DOSQFILEMODE` then could not find. RESTORE showed
"Source and target drives are the same" (message 2, for error 2) for every
file that existed with `/P`, `/N` or any other switch, and stopped. For
JWasm the attribute goes into the caller's buffer, as the structure meant.

`MAPPER/F_CLOSE.ASM` writes `and ds:[si],(not OpenedHandle)`, which JWasm
evaluates in 32 bits and refuses as too large for a word; for JWasm the
operand is masked to 16 bits, and assembles to MASM's bytes. The MAPPER
objects JWasm makes differ from MASM's in their OMF encoding (offsets kept
in the data rather than the fixups, fewer fixups for forward jumps), not in
what they do.

## How BACKUP and RESTORE 4.00 behave

The tests keep these behaviours of Microsoft's programs:

- **Errorlevels.** 0 done, 1 no files found (to back up, or to restore), 2
  some files not backed up or restored for a sharing conflict, 3 stopped
  by Ctrl+Break, 4 any other error, including bad parameters ("Invalid
  switch", "Source and target drives are the same", "No source drive
  specified", "No target drive specified").
- **Disks.** BACKUP asks for each floppy by number, and warns that the
  files in its root will be erased. RESTORE asks for each in order; a disk
  with the wrong number is "out of sequence", and the key goes on with it
  anyway.
- **What is backed up.** Every file of the source, hidden and system files
  too, but `IO.SYS`, `MSDOS.SYS`, `IBMBIO.COM`, `IBMDOS.COM`,
  `COMMAND.COM` and `CMD.EXE` in a root directory. BACKUP clears the
  archive bit of what it backs up; `/M` backs up only files that have it.
  The log (`/L`) names each file and its disk.
- **What is restored.** The path given must be the one backed up. RESTORE
  makes the directories, and gives the files their attributes, dates and
  times. `/N` restores only files that are not there; `/P` asks before
  writing over a read-only file.

## Tests (`make test-backup-restore`)

`scripts/backup-restore-test` provisions a 512 MB CF image with
`scripts/deploy-cf` in `build/linux/tests/backup-restore`, never on a block
device, with a 1.44 MB drive A: of disposable floppy images. It puts
`D:\BR\SRC`, a tree of three levels, on D: with mtools: small files with
fixed dates and times, one read-only, one hidden and one without its
archive bit, and two files of 1.2 MB and 2 MB. It copies
`tests/backup-restore/br.bat` to `C:\BR.BAT` and the errorlevel reporter
`EL.BAT` (`tests/join-subst`) to `C:\DOS`, writes `D:\AUTOEXEC.BAT` to run
`C:\BR`, and boots the image in QEMU, with the clock at 2026-01-01 12:00.

The batch file runs with `CTTY AUX`, so COM1 is the console, and the
script answers it: when BACKUP or RESTORE asks for disk NN and then for a
key, it changes A: (through QEMU's monitor) to the disk of the set the
batch file named last (`== set NAME`), and sends a key; to RESTORE `/P`'s
"Replace the file (Y/N)?", and to "Format another (Y/N)?" of the FORMAT
that BACKUP `/F` runs, it answers N. A new disk is
formatted with mtools, with its own volume serial number, or blank for
the set `RAWF`. The key waits 3 seconds: QEMU's BIOS gives drive A: no
change line, and DOS takes a floppy it read less than 2 seconds before to
be the same disk. DOS writes to COM1 through BIOS INT 14h, which gives up
when QEMU is slow to take the output, as on a busy host; the script then
stops with that message rather than waiting on DOS's "Abort, Retry,
Ignore, Fail?".

The batch file runs:

- BACKUP's and RESTORE's parameter errors, and nothing to back up or
  restore;
- `BACKUP D:\BR\SRC A: /S /L:...`, onto three disks, with one file over
  all three; the log, and the archive bits it cleared;
- everything deleted, then `RESTORE /S`, which makes the directories again;
  the dates, times and attributes, the small files, and `FC /B` of the
  large ones against copies;
- RESTORE of a wildcard without `/S`, `/N` and `/P`;
- `BACKUP /M` after a change, and `BACKUP /A /M` added to it, restored;
- `BACKUP /F` onto a blank disk, which FORMAT formats, restored;
- RESTORE of the set Microsoft's BACKUP wrote (`MSSET`, made from
  `tests/backup-restore/ms`).

COM1's output from `GRDOS-TEST-BEGIN` to `GRDOS-TEST-END` must be
`tests/backup-restore/expect.log`, byte for byte, CRs included, but for the
volume serial numbers FORMAT makes from the time. And each disk of the
three-disk backup must hold the files of `tests/backup-restore/ms/NN`,
byte for byte. Both are what Microsoft's BACKUP.COM and RESTORE.COM, from
the M1 reference build, write on the same install, with GR-DOS's kernel:
`make backup-restore-expect` replaces `C:\DOS\BACKUP.COM` and
`C:\DOS\RESTORE.COM` with them (`BACKUP_REFERENCE`, `RESTORE_REFERENCE`)
and writes both. So GR-DOS's RESTORE restores a backup Microsoft's BACKUP
wrote, and Microsoft's RESTORE restores what GR-DOS's BACKUP writes, which
is the same.

The floppy tests (`make test-floppy-720` and up) check the disks' files and
free space.
