# M5: The rest of the assembly utilities (issue #17)

GR-DOS now builds every external command in MS-DOS 4.00's `v4.0/src/CMD`
that is written in assembly language: the 19 below, on top of the
utilities of [M4](m4-utilities.md). Each one is Microsoft's own source,
assembled with JWasm and linked with `wlink` as in [M2](m2-jwasm.md), and
`make check` finds each binary and its message files byte-identical to
Microsoft's MASM/LINK build (M1). They are all on C: (`C:\DOS`) when
`scripts/deploy-cf` installs GR-DOS, and the 720 KB, 1.2 MB and 1.44 MB
floppies carry the ones a two-drive machine can use. The 360 KB floppy is
unchanged.

## The audit

`v4.0/src/CMD/MAKEFILE` builds 38 commands. M1–M4 built 13 of them
(COMMAND, FORMAT, SYS, CHKDSK, DISKCOPY, FDISK, ATTRIB, MORE, FIND, FC,
DEBUG, MEM and MODE). Of the other 25:

| Command | Source | GR-DOS |
|---|---|---|
| APPEND | assembly | built, `APPEND.EXE` |
| ASSIGN | assembly | built, `ASSIGN.COM` |
| BACKUP | C (`BACKUP.C`), with assembly helpers | built, `BACKUP.COM`, issue #19 ([backup-restore.md](backup-restore.md)) |
| COMP | assembly | built, `COMP.COM` |
| DISKCOMP | assembly | built, `DISKCOMP.COM` |
| EDLIN | assembly | built, `EDLIN.COM` |
| EXE2BIN | assembly | built, `EXE2BIN.EXE` |
| FASTOPEN | assembly | built, `FASTOPEN.EXE` |
| FILESYS | C (`FILESYS.C`), with assembly helpers | built, `FILESYS.EXE`, issue #20 ([filesys.md](filesys.md)) |
| GRAFTABL | assembly | built, `GRAFTABL.COM` |
| GRAPHICS | assembly, and the profile `GRAPHICS.PRO` | built, `GRAPHICS.COM` |
| IFSFUNC | assembly, with the kernel's objects | built, `IFSFUNC.EXE` |
| JOIN | C (`JOIN.C`), with assembly helpers | built, `JOIN.EXE`, issue #18 ([join-subst.md](join-subst.md)) |
| KEYB | assembly | built, `KEYB.COM` |
| LABEL | assembly | built, `LABEL.COM` |
| NLSFUNC | assembly | built, `NLSFUNC.EXE` |
| PRINT | assembly | built, `PRINT.COM` |
| RECOVER | assembly | built, `RECOVER.COM` |
| REPLACE | C (`REPLACE.C`), with assembly helpers | built, `REPLACE.EXE`, issue #21 ([replace.md](replace.md)) |
| RESTORE | C (14 files), with assembly helpers | built, `RESTORE.COM`, issue #19 ([backup-restore.md](backup-restore.md)) |
| SHARE | assembly, with the kernel's objects | built, `SHARE.EXE` |
| SORT | assembly | built, `SORT.EXE` |
| SUBST | C (`SUBST.C`), with assembly helpers | built, `SUBST.EXE`, issue #18 ([join-subst.md](join-subst.md)) |
| TREE | assembly | built, `TREE.COM` |
| XCOPY | assembly | built, `XCOPY.EXE` |

The six C commands, like ATTRIB, MEM, FDISK and FC, have their `main` and
logic in C, compiled by Microsoft C 5.1, with only the message retriever
and parser in assembly. Issue #17 is about the assembly sources; porting
these is C work, like that of [M4](m4-utilities.md) and [FC](fc.md). JOIN
and SUBST are ported (issue #18, [join-subst.md](join-subst.md)), and BACKUP
and RESTORE (issue #19, [backup-restore.md](backup-restore.md)), FILESYS
(issue #20, [filesys.md](filesys.md)) and REPLACE (issue #21,
[replace.md](replace.md)).

Two built commands need data files from `v4.0/src/DEV`: KEYB needs
`KEYBOARD.SYS` (`DEV/KEYBOARD`), and NLSFUNC's code page switching
(`CHCP`) needs `COUNTRY.SYS` (`DEV/COUNTRY`). GR-DOS builds both since
issue #23 ([country-keyboard.md](country-keyboard.md)). MODE's code page
commands (`MODE CON CP`) need DISPLAY.SYS and its fonts (`DEV/DISPLAY`),
built since issue #24 ([codepage.md](codepage.md)), and `MODE LPTn CP`
PRINTER.SYS and its printer fonts (`DEV/PRINTER`), built since issue #25
([printer.md](printer.md)). GRAPHICS
needs its printer profile, `GRAPHICS.PRO`, which is a text file in the
source and is distributed with it.

## Building

The Makefile's `EXTRA_UTILITIES` lists the 19. Their objects come from
each `CMD/X/X.LNK`, but APPEND, ASSIGN and NLSFUNC, whose makefiles name
the objects. SHARE and IFSFUNC link objects of the kernel too
(`INC/NIBDOS`, `CONST2`, `MSDATA` and so on, and IFSFUNC `DOS/MSDISP` and
`MSCODE`), built from the same sources as MSDOS.SYS, and take part of
their messages from the kernel's `MSDOS.SKL` (`buildmsg --nosrvbld`).

| Link | Commands |
|---|---|
| EXE2BIN to a `.COM` | ASSIGN, COMP, DISKCOMP, GRAFTABL, GRAPHICS, KEYB, LABEL, TREE |
| `.EXE` as LINK writes it, then CONVERT to a `.COM` | EDLIN, PRINT, RECOVER |
| `.EXE` as LINK writes it | APPEND, FASTOPEN, NLSFUNC, SHARE, SORT, XCOPY |
| `.EXE` as LINK `/EXEPACK` writes it | EXE2BIN, IFSFUNC |

`make check` compares the 19 programs, `RECOVER.EXE` (the input of
CONVERT) and their 85 message files with M1: 202 files in all, from 97.

Particulars:

- **Message file names.** LABEL's messages are `LABL.SKL`. FASTOPEN and
  RECOVER include their message files by the name in their `MSG_UTILNAME`
  (`fastopen.ctl`, in lower case), so `scripts/case-alias` adds aliases
  by that name too.
- **EXEFIX.** SORT's makefile runs the binary-only `TOOLS/EXEFIX.EXE`
  (`exefix sort.exe 1 1`). `scripts/exefix` replaces it. It was written
  from what EXEFIX does to SORT.EXE and FIND.EXE under DOSBox-X. It sets
  the maximum and minimum allocation to its hexadecimal arguments, and,
  quirkily, adds 11 to the count of bytes in the last page.

### Source edits

Three, each under `IFDEF __JWASM__` (or `IFNDEF`), so that MASM builds the
same as before (`scripts/check-reference`):

- `CMD/KEYB/KEYBMAC.INC`: `OPTION NOKEYWORD:<MASK,OPTION,GOTO>`. KEYB
  has macros named `MASK` and `GOTO` and a macro parameter `OPTION`,
  which are JWasm keywords but not MASM 5's.
- `CMD/PRINT/PRINT_TM.ASM`: `OPTION NOKEYWORD:<ADDR,NAME>`, for the macro
  `addr` and its parameter `name`.
- `CMD/SHARE/GSHARE2.ASM`: `RestoreReg <` is left out for JWasm. It is an
  unterminated list, which MASM 5 takes as empty; JWasm reads on to the
  next `>`.

### JWasm patches

Ten more MASM 5 behaviours, under `-Zj` ([M2](m2-jwasm.md#jwasm-patches)
lists all the patches):

| Patch | MASM 5 behaviour | Needed by |
|---|---|---|
| `0012-Zj-forward-macro-use` | a line that uses a macro defined later is skipped in pass one, not an error | `HEADER` and `BREAK` before their definitions |
| `0013-Zj-self-referencing-variable` | `?x = ?x + 2` before `?x` is defined | `?stackdepth` in the message services |
| `0014-Zj-16-bit-constants` | `0FFFFh` and `-1` are the same 16-bit constant; a byte operand takes `0FF00h`–`0FFFFh` | IFSFUNC's `TRUE`, EDLIN's parser |
| `0015-Zj-rep-prefixes` | `REPE`/`REPNE` before `MOVS` are `REP` | KEYB's `KEYBCMD.ASM` |
| `0016-Zj-no-comma-continuation` | a line ending with a comma does not continue; `PUBLIC` ignores a final comma | RECOVER's `RECDATA.INC` |
| `0017-Zj-label-offset-segment` | `DW label` is relative to the label's segment, not its group | RECOVER's `int_24_retaddr` |
| `0018-Zj-forward-constant-word-immediate` | a forward-referenced constant after a 16-bit register stays a 16-bit immediate (`81`, not `83`) | GRAPHICS' `.IF <BX EQ MAX_BANDS>` |
| `0019-Zj-forward-equ-variable-word` | a variable named by an `EQU` with a forward reference is a `WORD` in pass one | KEYB's `TEST CS:SD.TABLE_OK,1` |
| `0020-Zj-field-size-and-length` | `SIZE` and `LENGTH` of a structure field's global name | GRAFTABL's `TABSIZE` |
| `0021-Zj-question-mark-zeros` | `?` outside `DUP` is written as zeros | EXE2BIN's `ZLOAD` (see below) |

### Linking

`scripts/mslink-layout` and `scripts/msexe` follow LINK more closely:

- **The stack segment** is the one with combine type `STACK` or, failing
  that, the first of class `STACK`, as LINK and `wlink` take it.
  EXE2BIN's is `PUBLIC 'STACK'`. Its size is given to `wlink`, which would
  otherwise make it 4 KB.
- **The load image** ends at the last segment with data records (`LEDATA`
  or `LIDATA`). A stack of `DUP (?)` at the end, which has none, is left
  out, as for NLSFUNC and SHARE. MASM 5 writes zeros for a `?` outside
  `DUP` (patch 0021), so EXE2BIN's last segment, a single `DB ?`, is in
  the image.
- **The minimum allocation** is the memory beyond the load image, rounded
  up to paragraphs, not the difference of the two rounded (NLSFUNC).
- **EXEPACK** unpacks up to the end of the image when segments follow the
  stack (EXE2BIN). The padding's fill takes in a run of 8 or more equal
  bytes before it (EXE2BIN), not fewer (FIND), and a run at the very start
  of the image is left as it is (IFSFUNC).

The first two rules also change the unpacked `FIND.EXE` of the images
(below): its stack, `DUP (?)`, is no longer written, so it is 10,094 bytes
rather than 11,288. The packed FIND.EXE that `make check` compares is
unchanged.

### 8086

The sources use no `.186`, `.286` or later directive, so JWasm assembles
them for the 8086, its default, and the binaries are MASM's, byte for byte.

## Distribution

LINK's EXEPACK unpacker fails when DOS loads the program in the first
64 KB of memory ([M4](m4-utilities.md#findexe)). So EXE2BIN.EXE and
IFSFUNC.EXE are distributed as `build/linux/image/EXE2BIN.EXE` and
`IFSFUNC.EXE`, linked again without EXEPACK, as FIND.EXE is (the
Makefile's `UNPACKED`).

### Floppies

The floppies are boot disks for a machine with two floppy drives. The
GR-DOS disk stays in A:, and B: holds programs and data. The image's
`AUTOEXEC.BAT` sets `PATH A:\`, so the commands run with B: as the current
drive. What a floppy carries is chosen for that use, not to fill it:

- **360 KB:** frozen by issue #17. It keeps its 17 files: IO.SYS,
  MSDOS.SYS and COMMAND.COM, the M4 utilities, TICO.EXE and AUTOEXEC.BAT.
- **720 KB:** those, and the everyday file and disk commands: XCOPY, COMP,
  DISKCOMP, LABEL, TREE, SORT, EDLIN, PRINT, ASSIGN and RECOVER; and KEYB
  with COUNTRY.SYS and KEYBOARD.SYS (issue #23,
  [country-keyboard.md](country-keyboard.md)); BACKUP and RESTORE
  (issue #19, [backup-restore.md](backup-restore.md)), for backing a hard
  disk up to floppies; and REPLACE (issue #21, [replace.md](replace.md)),
  which, like XCOPY, updates and adds files.
- **1.2 MB and 1.44 MB:** those, and the rest that work from a floppy:
  APPEND, SHARE, EXE2BIN, GRAFTABL, GRAPHICS and its GRAPHICS.PRO, and
  NLSFUNC; JOIN and SUBST (issue #18, [join-subst.md](join-subst.md)),
  which matter most with a hard disk, so the 720 KB disk keeps its room;
  DISPLAY.SYS with EGA.CPI (issue #24,
  [codepage.md](codepage.md)); and PRINTER.SYS with 4201.CPI, 4208.CPI
  and 5202.CPI (issue #25, [printer.md](printer.md)). Everything that is
  useful on a floppy fits on 1.2 MB, so the two have the same files.
- **No floppy:** GRVER ([grver.md](grver.md)), FASTOPEN, which works on hard disks only, IFSFUNC,
  which needs an installable file system driver, and there is none,
  FILESYS, which needs IFSFUNC (issue #20, [filesys.md](filesys.md)), and
  LCD.CPI, for the PC Convertible alone.

| Image | Files | Bytes free |
|---|---:|---:|
| 360 KB | 17 | 15,360 |
| 720 KB | 35 | 43,008 |
| 1.2 MB | 50 | 343,552 |
| 1.44 MB | 50 | 587,264 |

`image/files-360k.txt` to `files-1440k.txt` list each image's files in
order. They are part of the source: `make` checks both the Makefile's
`FILES_360` (and so on) and the image it builds against them. So any
change to a floppy's files, the 360 KB one's above all, shows up as a
change to its list. `build/linux/manifest-360k.txt` (and so on) lists each
image's files with their size, attributes, time and SHA-256.

### C: and the release

`ALL_FILES` is everything: the M4 utilities, TICO.EXE, all 19 commands,
GRAPHICS.PRO, COUNTRY.SYS and KEYBOARD.SYS (issue #23), DISPLAY.SYS, EGA.CPI
and LCD.CPI (issue #24), PRINTER.SYS, 4201.CPI, 4208.CPI and 5202.CPI
(issue #25), the other `*16` programs ([dist16.md](dist16.md), since
issue #36) and AUTOEXEC.BAT. `scripts/deploy-cf` installs all of it but
AUTOEXEC.BAT in `C:\DOS` (`build/linux/cf`). Its manifest is that of a
1.44 MB image of the same files, so each file is stamped as on the
floppies. The release ZIP's `BIN` has the same files.

## Tests

- **`make test-extras`** (`tests/extras`) boots a 1.44 MB image of
  `ALL_FILES` with a blank, disposable 1.44 MB disk in B:. It runs each of
  the 19 commands: their normal use, on B: where they write, and a bad
  switch, a missing file or a missing argument. It also checks what each
  resident one does when run again, and that MEM lists them. EXE2BIN
  converts the smoke test program, linked as an `.EXE`, and the `.COM` runs.
  RECOVER recovers a file on B:. DISKCOMP compares A: with a DISKCOPY of
  it, then again after LABEL changes B:. The expected output is
  MS-DOS 4.00's own, since the programs are Microsoft's.
- **`make test-floppy-360`** (also `-720`, `-1200` and `-1440`,
  `tests/floppy`) boots each format's files with the test's
  AUTOEXEC.BAT and a blank data disk in B:. The commands run from B: by
  name, through `PATH A:\`. The test checks that the format's commands work
  on the data disk and that the ones it leaves out are a "Bad command or
  file name". It then checks A:'s files and free space.
- **`make test-deploy-cf`** now also runs FASTOPEN C:, TREE C:\ and
  GRAPHICS from `C:\DOS` after provisioning and checks that FASTOPEN and
  GRAPHICS stay resident.

### Limits found

- MS-DOS 4.00's EXE2BIN takes an executable's header to be a multiple of
  512 bytes, as LINK writes it (`E2BINIT.ASM` rounds the header size up).
  Given `wlink`'s 32-byte header, it writes a wrong `.COM`. The test's
  `HELLOX.EXE` is given LINK's header (`tests/extras/pad-header`).
- APPEND must be loaded before ASSIGN ("APPEND / ASSIGN Conflict"), as in
  MS-DOS 4.00.
- DISKCOMP's errorlevel is 0 after a comparison that found differences, so
  the test checks only its messages then.
- IFSFUNC reports "Invalid configuration" (its message 4, "No IFS drivers
  found" in the source's comment) when no IFS driver is loaded, and stays
  resident.

The 19 have been tested in QEMU only. They have not been run on an 8088 or
a V20 in 86Box, as the kernel was ([M3](m3-boot.md)).
