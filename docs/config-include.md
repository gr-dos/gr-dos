# CONFIG.SYS's INCLUDEFILE= (issue #49)

**Status:** done, in `patches/kernel/0002-config-include.patch`. A CF
install made by `scripts/deploy-cf` uses `D:\CONFIG.SYS` by default
(#68): its generated `C:\CONFIG.SYS` ends with `INCLUDEFILE=D:\CONFIG.SYS`
([deploy-cf.md](deploy-cf.md)).
#48, deploy-cf merging `D:\CONFIG.SYS` into `C:\CONFIG.SYS`, was the
alternative; see Follow-ups.

```
C:\CONFIG.SYS                  D:\CONFIG.SYS (yours, optional)
FILES=20                       COUNTRY=049,,C:\DOS\COUNTRY.SYS
BUFFERS=20                     BREAK=ON
INCLUDEFILE=D:\CONFIG.SYS      INSTALL=C:\DOS\FASTOPEN.EXE C:
```

DOS configures itself as if `D:\CONFIG.SYS`'s lines were in
`C:\CONFIG.SYS` in place of the `INCLUDEFILE=` line. If there is no
`D:\CONFIG.SYS`, nothing happens and nothing is shown. So a generated
`C:\CONFIG.SYS` can always have the line.

This is GR-DOS's own directive. MS-DOS 6's `INCLUDE=` is not the same
thing: it names a block of the same file, for boot menus. GR-DOS does not
take that syntax. `INCLUDE=` stays an unrecognized command, as on MS-DOS
4.00.

## How MS-DOS 4.00 reads CONFIG.SYS

SYSINIT (`BIOS/SYSINIT1.ASM`, `SYSCONF.ASM`, `SYSINIT2.ASM`, in IO.SYS) does
the configuration. In the order it happens:

1. **IO.SYS's drivers are set up first.** The built-in drivers, and the
   drive letters of every floppy and hard disk partition the BIOS reports,
   are ready before SYSINIT runs. `SYSI_NUMIO` counts them.
2. **SYSINIT moves to the top of memory.** `CONFBOT`, just below it, starts
   as a one-sector buffer area. `TEMPCDS` puts temporary CDSs (the drive
   table) below `CONFBOT`, and sets `ALLOCLIM`, the limit for drivers
   loaded from CONFIG.SYS.
3. **DOS file I/O works now.** `RE_INIT` and the INT 24h handler, which
   answers "fail", are in place. SYSINIT selects the boot drive.
4. **`DOCONF` reads `\CONFIG.SYS`** in one go. It gets the size with
   `LSEEK`, moves `CONFBOT` down by that much, and calls `TEMPCDS` again.
   It reads the file to `CONFBOT:0`, cuts it at a ^Z, and adds a CR LF.
5. **`ORGANIZE` compacts the buffer in place.** It replaces each keyword
   with a letter and drops blank lines and comments. `Org_Count` is the
   result's length.
6. **Every pass reads that same buffer.**
   - **Pass 0** runs XMAEM.SYS and pre-scans `BUFFERS=`.
   - **Pass 1** runs everything else and notes any `INSTALL=`.
   - **Pass 2** runs `IFS=`.
   - **`ENDFILE`** allocates FILES, BUFFERS and the final CDSs.
   - **Pass 3** runs `INSTALL=`.
7. **The temporary memory is freed.** The buffer, the temporary CDSs and
   SYSINIT itself all go, and COMMAND.COM is loaded.

So all the passes see one buffer, filled once, before ORGANIZE. That is
where an include belongs. The drives an include can name are those IO.SYS
set up, which on a CF install include D:, a logical drive in the extended
partition.

## The prototype

`BIOS/GRINCL.INC`, called by `DOCONF` just before `ORGANIZE`
(`patches/kernel/0002-config-include.patch`):

1. **It finds the first `INCLUDEFILE` line.** Case is ignored and blanks
   may come before the keyword. After it come `=` or blanks, the file
   name, and optionally blanks.
   - The keyword's letters are never CR or LF, and the buffer ends in
     CR LF, so neither the match nor the name can run into the next line.
   - The name is taken as given, so a drive and full path are best.
2. **It opens the file and checks its size.** While it opens and reads the
   file, its own INT 24h handler records any critical error and fails
   the call, as SYSINIT's does. A disk fault can then be told from a
   missing file (below).
3. **It builds a new buffer just below the old one:**
   - CONFIG.SYS's lines before the `INCLUDEFILE=` line;
   - the file's lines, up to a ^Z, followed by a CR LF;
   - CONFIG.SYS's lines after the `INCLUDEFILE=` line.
4. **It switches to the new buffer.** `CONFBOT`, `COUNT` and `Config_Size`
   now describe it, and `TEMPCDS` moves the CDSs below it, as step 4 above
   does.

Everything after that is MS-DOS 4.00's own code, unchanged. That covers
ORGANIZE, the passes, the error messages and the order of the lines.

### What it does in each case

Whenever the file isn't used, the `INCLUDEFILE=` line becomes a REM, and
CONFIG.SYS's own lines are used as they are, none of the file's. The
handle is closed and SYSINIT's INT 24h handler put back on every path.

| Case | Result |
|---|---|
| The file is read | its lines take effect exactly as if they were in CONFIG.SYS, in every pass; a later `COUNTRY=` overrides an included one |
| No such file (error 2), path (3) or drive (15); the drive not ready (critical error 2: no disk) | **silent** |
| An empty file | **silent**: nothing to include |
| A critical error other than not ready, while opening, seeking or reading: a bad sector, a controller or read failure | `INCLUDEFILE=NAME not used: disk error` |
| Another open error, such as a directory (access denied) | `INCLUDEFILE=NAME not used: cannot open` |
| Another seek or read error, or a short read | `INCLUDEFILE=NAME not used: cannot read` |
| Over 32 KB, or more than 65,520 bytes with CONFIG.SYS | `INCLUDEFILE=NAME not used: too large` |
| The new buffer would come within 64 KB of the start of free memory | `INCLUDEFILE=NAME not used: not enough memory` |
| No name, a name over 63 characters, or more after the name | `INCLUDEFILE=NAME not used: bad line` |
| Bad lines inside the file | MS-DOS's own messages, as for CONFIG.SYS's |
| `INCLUDEFILE=` in the file (nested, or a cycle), or a second one in CONFIG.SYS | MS-DOS's own `Unrecognized command in CONFIG.SYS` and `Error in CONFIG.SYS line N`; not followed |
| `INCLUDE=` | an unrecognized command, as on MS-DOS 4.00 |

Its messages are printed before CONFIG.SYS's first line is run. They
don't give a line number, because `LineCount` is counted later, in the
passes.

### Memory

**No resident cost.** The new code is SYSINIT's, and the new buffer is in
SYSINIT's temporary memory: both are freed before COMMAND.COM starts.
`make test-config-include` boots the same settings both ways, in
`C:\CONFIG.SYS` itself and through `INCLUDEFILE=D:\CONFIG.SYS`. MEM
reports the same largest executable program size each time (574,304
bytes).

While CONFIG.SYS is processed, the old buffer is left unused. So for that
time, the memory left for `DEVICE=` drivers is less by both files' size.
That's why the include is refused unless the new buffer stays more than
64 KB above the start of free memory. In the test, a 160 KB machine
refuses a 32 KB file and still boots.

**On disk,** IO.SYS is 917 bytes longer (34,238 bytes). That is one more
cluster on every floppy, so each has 512 or 1,024 bytes less free. C:'s
4 KB clusters still hold it in nine.

### Limits

- **Drive letters are IO.SYS's.** The include happens before any
  `DEVICE=`, so a drive that a driver adds can't hold the included file.
  - **With a second hard disk,** MS-DOS gives the second disk's primary
    partition D:, before the CF card's logical drives. The included drive
    letter moves too.
  - **With no D:** (a floppy-only machine), the include is silently
    skipped.
- **Line numbers count the expanded lines.** In `Error in CONFIG.SYS line
  N`, the included file's lines are counted in place of the
  `INCLUDEFILE=` line. An error after a three-line include is reported two
  lines later than in C:'s file.
- **An empty floppy drive may not be silent.** A real drive with no disk
  reports "not ready" (critical error 2), which is silent. QEMU's (with
  SeaBIOS) reports a general failure (0Ch), as `DIR A:` shows. DOS can't
  tell that from a broken drive, so it is reported as a disk error.
  Because of that, the silent not-ready path isn't tested in emulation.
- **One file, one level.**
- **The included file is at most 32 KB,** and CONFIG.SYS and the file
  together at most 65,520 bytes, the buffer's segment.

## Tests

`make test-config-include` (`scripts/config-include-test`, part of
`make test`):

1. **Provision** a 512 MB CF install with `scripts/deploy-cf`.
2. **For each scenario,** write its `C:\CONFIG.SYS` and its files on D:
   with mtools, and boot a copy in QEMU (`scripts/hd-boot-test`).
3. **Check COM1:** `D:\AUTOEXEC.BAT` reports the country (`NLSINFO`, from
   the country tests), `BREAK`, and `MEM /PROGRAM`, which shows an
   `INSTALL=`ed FASTOPEN.
4. **Check the screen:** `hd-boot-test` saves it as `screen.txt`, because
   that is where CONFIG.SYS's messages go. Each scenario lists what must
   and must not be there.

Some scenarios need help from outside DOS:

- **Disk errors** use QEMU's `blkdebug` driver (`hd-boot-test
  --blkdebug`). It fails every read of one sector: the file's first, or
  its directory's.
- **Low memory** uses `tests/config-include/lowmem.asm`, a master boot
  record. It sets the BIOS's memory size (40:13h) before booting the
  active partition, as on a machine with less memory.

In the table, the failure scenarios have `BREAK=ON` after the include
line, and the file holds `BREAK=ON`, `COUNTRY=049` and an `INSTALL=`.
"None applied" means country 001 and no FASTOPEN, with BREAK on from
C:'s own line.

| Scenario | `C:\CONFIG.SYS`, D: | Expected |
|---|---|---|
| `base` | the settings themselves | country 049, BREAK on, FASTOPEN |
| `include` | `INCLUDEFILE=D:\CONFIG.SYS` holding them | the same, and the same free memory as `base` |
| `order` | `COUNTRY=044`, `  includefile = d:\config.sys `, `COUNTRY=033` | country 033, BREAK on, FASTOPEN |
| `missing`, `nopath`, `nodrive` | no such file, directory, or drive Q: | none applied; nothing on the screen |
| `emptyfloppy` | `INCLUDEFILE=A:\CONFIG.SYS`, no disk in QEMU's A: | `not used: disk error` (see below) |
| `empty` | an empty file | the same |
| `readerror` | the file's first sector fails | none applied; `not used: disk error` |
| `openerror` | `D:\CFG\CONFIG.SYS`, `CFG`'s sector fails | the same |
| `directory` | `INCLUDEFILE=D:\CFG`, a directory | `not used: cannot open` |
| `max` | a file of exactly 32,768 bytes | all applied |
| `toobig` | 32,769 bytes | `not used: too large` |
| `segment` | CONFIG.SYS and the file 65,000 bytes together | all applied |
| `oversegment` | 65,600 bytes together | `not used: too large` |
| `lowmem` | a 32 KB file on a 160 KB machine | `not used: not enough memory`; boots |
| `noname` | `INCLUDEFILE=` | `INCLUDEFILE= not used: bad line` |
| `bare` | `INCLUDEFILE`, then `=D:\CONFIG.SYS` on the next line | `bad line`, and the next line is unrecognized: nothing read from it |
| `extra` | `INCLUDEFILE=D:\CONFIG.SYS EXTRA` | `bad line` |
| `longname` | a 72-character name | `bad line`, with the first 63 characters |
| `split` | `INCLUDEFIL`, then `E=D:\CONFIG.SYS` | two unrecognized commands |
| `include6` | `INCLUDE=D:\CONFIG.SYS` | unrecognized command, line 3; none applied |
| `nested` | the file has `INCLUDEFILE=` first | unrecognized command, line 3; the rest applies |
| `second` | a second `INCLUDEFILE=` in CONFIG.SYS | unrecognized command, line 6; the first applies |
| `ctrlz` | the file has a ^Z, then other lines | the lines before the ^Z apply |
| `noeol` | `BREAK=ON` with no CR LF | BREAK on |

## Compared with #48

| | `INCLUDEFILE=` (this) | deploy-cf merges (#48) |
|---|---|---|
| A change to `D:\CONFIG.SYS` | takes effect at the next boot | needs `deploy-cf update` from Linux |
| Editing on the machine itself | yes | no: C:'s file is regenerated |
| Checking the user's lines | DOS's usual messages at boot | deploy-cf could refuse bad lines beforehand |
| Cost | 917 bytes of IO.SYS, none resident | none in DOS |
| Other DOS versions | GR-DOS only | any |

## Follow-ups

1. **Done (#68): deploy-cf writes `INCLUDEFILE=D:\CONFIG.SYS`** into the
   generated `C:\CONFIG.SYS`, after its defaults, so the user's lines
   override them. It doesn't check whether D: has the file, because when
   it is absent the line does nothing. `make test-deploy-cf` boots without the file and
   with it, and checks that `update` keeps it.
2. **#48** stays open as the alternative until this is proven on real
   hardware; it can be closed then.
