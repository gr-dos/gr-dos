# CONFIG.SYS's INCLUDE= (issue #49)

**Status:** investigated, and prototyped in `patches/kernel/0002-config-include.patch`.
**Recommendation:** proceed. It works, it is small, and it has no resident cost.
#48, deploy-cf merging `D:\CONFIG.SYS` into `C:\CONFIG.SYS`, can be closed
or reduced once deploy-cf writes the `INCLUDE=` line (see the end).

```
C:\CONFIG.SYS                  D:\CONFIG.SYS (yours)
FILES=20                       COUNTRY=049,,C:\DOS\COUNTRY.SYS
BUFFERS=20                     BREAK=ON
INCLUDE=D:\CONFIG.SYS          INSTALL=C:\DOS\FASTOPEN.EXE C:
```

DOS configures itself as if `D:\CONFIG.SYS`'s lines were in
`C:\CONFIG.SYS` in place of the `INCLUDE=` line. This is GR-DOS's own
extension. MS-DOS 6's `INCLUDE=` names a block of the same file, for its
boot menus, which GR-DOS does not have.

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

1. **It finds the first line that is `INCLUDE`.** Case is ignored and
   blanks may come before it. The keyword is followed by `=`, a space or a
   tab, then a file name. The name is taken as given, so a drive and full
   path are best.
2. **It opens the file and checks its size,** which must be at most 32 KB.
3. **It builds a new buffer just below the old one:**
   - CONFIG.SYS's lines before the `INCLUDE=` line;
   - the file's lines, up to a ^Z, followed by a CR LF;
   - CONFIG.SYS's lines after the `INCLUDE=` line.
4. **It switches to the new buffer.** `CONFBOT`, `COUNT` and `Config_Size`
   now describe it, and `TEMPCDS` moves the CDSs below it, as step 4 does.

Everything after that is MS-DOS 4.00's own code, unchanged. That covers
ORGANIZE, the passes, the error messages and the order of the lines.

### What it handles

| Case | Result |
|---|---|
| A file that is included | its lines take effect exactly as if they were in CONFIG.SYS, in every pass |
| Lines before and after `INCLUDE=` | the usual order: a later `COUNTRY=` overrides an included one |
| No such file, no such drive, a drive not ready, a file over 32 KB, a name over 63 characters | `Cannot include D:\NAME`; the line becomes a REM and the boot goes on |
| `INCLUDE=` in the included file (nested, or a cycle) | MS-DOS's own `Unrecognized command in CONFIG.SYS` and `Error in CONFIG.SYS line N`; the line is ignored |
| A second `INCLUDE=` in CONFIG.SYS | the same: only one file is included |
| A ^Z, no final CR LF, an empty file | as for CONFIG.SYS itself |

### Memory

**No resident cost.** The new code is SYSINIT's, and the new buffer is in
SYSINIT's temporary memory: both are freed before COMMAND.COM starts.
`make test-config-include` boots the same settings both ways, in
`C:\CONFIG.SYS` itself and through `INCLUDE=D:\CONFIG.SYS`. MEM reports
the same largest executable program size each time (574,304 bytes).

While CONFIG.SYS is processed, the old buffer is left unused. So for that
time, the memory left for `DEVICE=` drivers is less by both files' size.
The include is refused unless the new buffer stays more than 64 KB above
the start of free memory.

**On disk,** IO.SYS is 592 bytes longer (33,913 bytes). That is one more
cluster on every floppy, so each has 512 or 1,024 bytes less free. C:'s
4 KB clusters still hold it in nine.

### Limits

- **Drive letters are IO.SYS's.** The include happens before any
  `DEVICE=`, so a drive that a driver adds can't hold the included file.
  - **With a second hard disk,** MS-DOS gives the second disk's primary
    partition D:, before the CF card's logical drives. The included drive
    letter moves too.
  - **With no D:** (a floppy-only machine), the include fails safely and
    the machine boots on C:'s lines.
- **Line numbers count the expanded lines.** In `Error in CONFIG.SYS line
  N`, the included file's lines are counted in place of the `INCLUDE=`
  line. An error after a three-line include is reported two lines later
  than in C:'s file.
- **One file, one level.** `INCLUDE=` lines in the included file are not
  followed.
- **The included file is at most 32 KB,** and CONFIG.SYS and the file
  together must fit in 64 KB, the buffer's segment.

## Tests

`make test-config-include` (`scripts/config-include-test`, part of
`make test`):

1. **Provision** a 512 MB CF install with `scripts/deploy-cf`.
2. **For each scenario,** write its `C:\CONFIG.SYS` and its files on D:
   with mtools, and boot a copy in QEMU (`scripts/hd-boot-test`).
3. **Check COM1:** `D:\AUTOEXEC.BAT` reports the country (`NLSINFO`, from
   the country tests), `BREAK`, and `MEM /PROGRAM`, which shows an
   `INSTALL=`ed FASTOPEN.
4. **Check the screen:** `hd-boot-test` now saves it as `screen.txt`,
   because that is where CONFIG.SYS's messages go. Each scenario lists what
   must and must not be there.

| Scenario | `C:\CONFIG.SYS` | Expected |
|---|---|---|
| `base` | the settings themselves | country 049, BREAK on, FASTOPEN |
| `include` | `INCLUDE=D:\CONFIG.SYS` holding them | the same, and the same free memory as `base` |
| `order` | `COUNTRY=044`, `  include = d:\config.sys`, `COUNTRY=033` | country 033, BREAK on, FASTOPEN |
| `missing` | `INCLUDE=D:\NOPE.SYS`, `BREAK=ON` | `Cannot include D:\NOPE.SYS`; BREAK on |
| `nodrive` | `INCLUDE=Q:\CONFIG.SYS` | `Cannot include Q:\CONFIG.SYS` |
| `notready` | `INCLUDE=A:\CONFIG.SYS`, no disk in A: | `Cannot include A:\CONFIG.SYS` |
| `nested` | the included file has `INCLUDE=` first | `Unrecognized command`, `Error in CONFIG.SYS line 3`; the rest applies |
| `toobig` | a 38 KB file | `Cannot include D:\BIG.SYS` |
| `ctrlz` | the file has a ^Z, then other lines | the lines before the ^Z apply |
| `noeol` | `BREAK=ON` with no CR LF | BREAK on |
| `empty` | an empty file | nothing, no message |

## Compared with #48

| | `INCLUDE=` (this) | deploy-cf merges (#48) |
|---|---|---|
| A change to `D:\CONFIG.SYS` | takes effect at the next boot | needs `deploy-cf update` from Linux |
| Editing on the machine itself | yes | no: C:'s file is regenerated |
| Checking the user's lines | DOS's usual messages at boot | deploy-cf could refuse bad lines beforehand |
| Cost | 592 bytes of IO.SYS, none resident | none in DOS |
| Other DOS versions | GR-DOS only | any |

## Follow-ups

1. **deploy-cf writes `INCLUDE=D:\CONFIG.SYS`** into the generated
   `C:\CONFIG.SYS`, after its defaults, so the user's lines override them.
   It should do so only when `D:\CONFIG.SYS` exists at provision or update
   time; otherwise every boot prints `Cannot include`.
2. **Close #48** or reduce it to that follow-up.
3. **Optional:** an `INCLUDE?=` form that is silent when the file is
   missing. That would let deploy-cf always write the line.
