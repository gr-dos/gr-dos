# M4: Utilities and the system disk (issue #4)

GR-DOS builds a system disk for machines with one or two floppy drives and
no hard disk: the kernel files, ten external commands from the MS-DOS 4.00
source, the tico16 editor and an AUTOEXEC.BAT. Every image, from 1.44 MB to
360 KB, holds the same files.

## The disk

| File | Built from | Linked | Same as M1 |
|---|---|---|---|
| `IO.SYS`, `MSDOS.SYS`, `COMMAND.COM` | `BIOS`, `DOS`, `CMD/COMMAND` | as before ([M2](m2-jwasm.md)) | yes, but the branding |
| `FORMAT.COM` | `CMD/FORMAT` | `.EXE` as LINK writes it, then CONVERT | yes |
| `SYS.COM` | `CMD/SYS` | EXE2BIN | yes |
| `CHKDSK.COM` | `CMD/CHKDSK` | `.EXE` as LINK writes it, then CONVERT | yes (and `CHKDSK.EXE`) |
| `DISKCOPY.COM` | `CMD/DISKCOPY` | EXE2BIN | yes |
| `ATTRIB.EXE` | `CMD/ATTRIB` (C) | Open Watcom C, `wlink` and libc16 | no |
| `MORE.COM` | `CMD/MORE` | EXE2BIN | yes |
| `FIND.EXE` | `CMD/FIND` | `.EXE` as LINK writes it, not EXEPACKed | the EXEPACKed one is |
| `DEBUG.COM` | `CMD/DEBUG` | `.EXE` as LINK writes it, then CONVERT | yes |
| `MEM.EXE` | `CMD/MEM` (C) | Open Watcom C, `wlink` and libc16 | no |
| `MODE.COM` | `CMD/MODE` | EXE2BIN | yes |
| `TICO.EXE` | tico16 release v0.02, not built | | |
| `AUTOEXEC.BAT` | `image/autoexec.bat` | | |

EDLIN is left out: TICO.EXE replaces it. SPROCKET.EXE is not included yet,
as it has no release asset.

`make check` compares the eight assembler utilities, `CHKDSK.EXE` and the
message files of all ten (`X.CL*`, `X.CTL`, and FORMAT's copy of
`BOOT.CL1`) with the M1 reference build: 88 files in all.

`AUTOEXEC.BAT` sets the prompt to the current directory (`PROMPT $P$G`) and
`PATH A:\`, so the utilities run from a disk in drive B: too. Without an
AUTOEXEC.BAT, COMMAND.COM would ask for the date and time at every boot.

### Linking

`scripts/mslink` links each utility in Microsoft LINK's segment layout, as
it does the kernel. Two further scripts finish the programs whose final
form is not the `.COM` EXE2BIN makes:

- `scripts/msexe` rewrites `wlink`'s executable as LINK 3.65 writes one:
  its header (512 bytes, relocations relative to their segment, the stack
  segment's `SS`, minimum allocation, checksum) and load image. With
  `--exepack` it packs the program as LINK `/EXEPACK` does, with LINK's
  unpacker stub. `scripts/mslink --exe` and `--exepack` call it.
- `scripts/convert` replaces the DOS build's binary-only `TOOLS/CONVERT.EXE`:
  a `.COM` file that holds the `.EXE` and a 123-byte loader, which
  relocates the program in place and starts it.

`scripts/lnk-objects` now stops at the end of the object list of a LINK
response file (the first `,` or `;`), as FORMAT's `.LNK` lists the output
on the same line.

### FIND.EXE

Microsoft's FIND.EXE is EXEPACKed, and GR-DOS's build of it is
byte-identical. But LINK's EXEPACK unpacker fails with "Packed file is
corrupt" when the program is loaded in the first 64 KB of memory, and
GR-DOS loads programs at segment 0FDDh. The images therefore carry
`build/linux/image/FIND.EXE`, the same objects linked without EXEPACK
(11,288 bytes rather than 5,941). `make check` still compares the EXEPACKed
`CMD/FIND/FIND.EXE`.

### ATTRIB and MEM

ATTRIB and MEM are C programs, compiled by Microsoft with Microsoft C 5.1,
and MEM linked with its runtime library (`MEM.LIB`). GR-DOS compiles them
with Open Watcom C, so they work but are not byte-identical:

```text
wcc -q -w0 -zld -zl -x -ms -0 -os -zp1 -s -j -ei -bt=dos -I... -Ibuild/libc16/include ...
```

Small model, 8086 instructions, packed structures (`-zp1`), signed `char`
(`-j`) and `int`-sized enums (`-ei`), as Microsoft C 5.1 compiled them.
Their C runtime is [libc16](https://github.com/gr-dos/libc16) (decision
20): its headers, and its `LIBC16.LIB` with `wlink`. libc16's functions
are `__cdecl`, and the rest of each program has Open Watcom's register
calling convention (libc16's `docs/ABI.md`). The assembly modules of the
DOS build, ATTRIBA (ATTRIB's startup code) and the C interfaces to the
parser and the message retriever (`_PARSE.ASM`, `_MSGRET.ASM`), use the
C calling convention, so the functions they define or call are declared
`__cdecl` with `#pragma aux` in the sources. ATTRIB has its own startup
code (`XCMAIN`), so it links no libc16 startup (libc16's
`docs/spec/startup.md`, "Programs without the startup"); MEM has libc16's.

The source edits, under `#ifdef __WATCOMC__` in C and `IFDEF __JWASM__` in
assembly, keep the Microsoft C build identical (`scripts/check-reference`):

- **K&R definitions.** Watcom checks calls against old-style definitions:
  three parameters ATTRIB passes different pointer types to are `void *`.
- **Calling convention.** `#pragma aux (__cdecl)` for ATTRIBA's `inmain`
  and `Reset_appendx` callbacks and its `getpspbyte`, `putpspbyte` and
  `crit_err_handler`, and for `parse`, `sysloadmsg`, `sysgetmsg` and
  `sysdispmsg`. MEM's declarations of `strcmp`, `exit` and `kbhit`, which
  lack `__cdecl`, give way to libc16's.
- **Startup.** Watcom's compiled `main` pulls in startup code (`_cstart_`),
  which ATTRIB has its own of, so ATTRIB's `main` is renamed. ATTRIB's
  `exit` is DOS function 4Ch, with the exit code, which Microsoft's call
  left out. MEM's `main` takes no parameters, as it reads its command line
  from the PSP, so libc16 links no argument parser.
- **`ES`.** Microsoft C kept `ES` equal to `DS`, and the parser and message
  retriever read their parameters through it; ATTRIB even calls `strcpy`
  "to fix ES". Watcom C does not, so the C interfaces set `ES` themselves,
  and both programs' `segread` is a macro that reports `DS` for `ES`.
- **`SI` and `DI`.** ATTRIBA's `getpspbyte` and `putpspbyte` change `SI`
  and `DI`, which Watcom keeps variables in across calls; they save them.
- **Uninitialised data.** Watcom leaves `_BSS` out of the program and the
  startup code must clear it. ATTRIB's startup code does not, so it now clears
  `_edata` to `_end` (`wlink` defines both).
- **Group.** ATTRIBA's `pgroup` holds only `_TEXT`, as Watcom's code
  addresses are offsets from `_TEXT`.
- **Overruns.** ATTRIB writes `string[16]` of a `char string[16]`, and MEM
  the fifth element of a four-element sublist array; Microsoft C's layout
  made both harmless, Watcom's does not.
- **Sublists.** Microsoft C word-aligned each message sublist (12 bytes);
  ATTRIB's `struct m_sublist` gains a filler byte.
- **MEM.** MEM read `DOS_TopOfMemory` from Microsoft's runtime; it now reads
  the top of memory from the PSP, through a far pointer built with
  `FP_SEG` and `FP_OFF`. It includes no `ctype.h`, which it uses nothing
  from.
- **`sprintf`.** MEM's five `sprintf` calls make a drive name (`"%c:"`,
  `"%c: - %c:"`) or copy a string with no conversions. They are written as
  the assignments and `strcpy` calls they amount to, so the runtime has no
  `sprintf`.

### The C runtime (libc16)

libc16 is a small MIT C runtime for 16-bit DOS programs built with Open
Watcom C, written for GR-DOS and the `gr-dos/*16` utilities. Each
function is its own library member, so `wlink` takes only what a program
calls. ATTRIB and MEM need 0.02, which added the Microsoft C 5.1
interfaces they use (`int86x`, `intdos`, `intdosx`, `segread`, `bdos`,
`kbhit`, `exit`, `struct SREGS`, assignable `FP_SEG`/`FP_OFF`) and support
for a program with its own startup code.

- **Pinned release.** `scripts/fetch-libc16` (libc16's
  `consumers/fetch-libc16`) downloads `libc16-VERSION.zip` from the libc16
  release named in it, checks its SHA-256 against the one written there
  before unpacking it, and unpacks it into `build/libc16`, which `make
  clean` keeps. To move to a newer libc16, set `version` and `sha256` in
  the script together (libc16's `docs/CONSUMERS.md`). `make
  LIBC16_ROOT=../libc16` builds against a libc16 checkout instead.
- **Same Open Watcom.** libc16 is built with the Open Watcom snapshot
  GR-DOS pins (libc16's decision 1); the build fails if the release's
  `tools/fetch-watcom` names a different one from `scripts/fetch-watcom`.
- **Compiler and runtime kept apart.** `wcc` runs with `-x` (no `INCLUDE`)
  and only libc16's headers, and with `-zl`, so the objects name no
  default library. `wlink` runs with `format dos` and `option
  nodefaultlibs` and is given only the objects and `LIBC16.LIB`: an Open
  Watcom runtime symbol could not be resolved, and the link would fail. It
  writes a map (`X.MAP`, next to `X.EXE`), and `scripts/check-runtime`
  fails the build unless every module in it is one of the program's
  objects or from `LIBC16.LIB`, and `LIBC16.LIB` the only library. ATTRIB
  takes `segread`, `strcpy`, `strcmp`, `bdos`, `intdos`, `intdosx`,
  `strcat`, `strlen`, `filelen`, `close`, `int86`, `int86x`, `doserr`,
  `fdtab` and `errno` from it; MEM takes `cstart`, `exit`, `intdosx`,
  `intdos`, `kbhit`, `strcpy`, `int86`, `int86x` and `segread`.

**Provenance.** libc16 records its own (its `docs/LICENSE-PROVENANCE.md`):
each member is written from a behavioural spec citing the C standard, the
DOS interrupt documentation and the Microsoft C 5.1 interfaces; no Open
Watcom runtime source is read and no Open Watcom library disassembled;
the startup and `exit` are written by a separate session from the spec
alone; and an audit of each release compares its code with Open Watcom's
runtime library. GR-DOS's earlier runtime, `compat/crt`, was written after
the Open Watcom runtime once linked into these programs had been
disassembled ([PR #6](https://github.com/plicease/dos-gr-dos/pull/6#issuecomment-6404653096)).
libc16 replaces it and was written without reading it. Open Watcom C,
`wlink` and `wlib` are build tools only, under the Sybase Open Watcom
Public License 1.0; no Open Watcom code is in ATTRIB.EXE or MEM.EXE.

**Size.** Against the same programs linked with Open Watcom's `clibs`, and
with GR-DOS's earlier runtime:

| | Open Watcom runtime | `compat/crt` | libc16 0.02 | 360 KB disk clusters |
|---|---:|---:|---:|---|
| `ATTRIB.EXE` | 20,504 bytes | 19,446 bytes | 19,369 bytes | 21 → 19 |
| `MEM.EXE` | 19,974 bytes | 11,986 bytes | 12,036 bytes | 20 → 12 |

MEM's own memory, as `MEM /PROGRAM` lists it, is 3A70h bytes with libc16,
3A40h with `compat/crt` and 7A70h with Open Watcom's runtime. Otherwise
ATTRIB's and MEM's output is the same with each runtime, as checked by
running the utility tests with each in QEMU.

### Assembler edits

The other compatibility edits, all keeping MASM's output identical:

- **CHKDSK.** CHKEQU.INC's `A_DeviceParameters` structure, a different
  one of the same name as IOCTL.INC's, is renamed `ChkDeviceParameters`; trailing commas removed from `PUBLIC` and
  `EXTRN` lists (JWasm joins the next line); `REPNZ MOVSB`, which JWasm
  rejects, written as a `REPNZ` byte and `MOVSB`. FORMAT has the same
  `REPNZ` change, and declares an `EXTRN` in the segment it is in.
- **SYS.** SYSHDR.INC defines `BREAK`, used before DOSSYM.INC defines it.
- **DEBUG.** DEBUG.ASM opens `CONST` and `DATA` first without an alignment
  and then as `BYTE`, which MASM 5 makes `BYTE` segments and JWasm does
  not; the first opening says `BYTE` too.
- **DISKCOPY.** A `HEADER` macro call moved after the macro's definition.
- **STRUC.INC.** The structured-programming macros (`.IF`, `.WHILE`, ...)
  are names JWasm takes as directives (`OPTION NOKEYWORD`); two `$&&&x` in
  nested macros are `$&x`, as JWasm removes `&` only next to a parameter;
  `$LastLabelOrg` starts as 0 rather than `$`, which JWasm rejects outside
  a segment, and is not used as an address before a label sets it.
- **MODE.** `ECHO`, `FOR`, `REPEAT` and `C` are names in MODE's modules but
  keywords in JWasm (`OPTION NOKEYWORD`); an unused `EQU` of an external
  difference is left out; and two `MOV`s in MODEPARS.ASM give the operand
  MASM 5.1 assembled, without the `[BX]` of `parm_list`.

The JWasm patches the utilities need, 0003 to 0011, are described in
[M2](m2-jwasm.md#jwasm-patches).

## TICO.EXE

`scripts/fetch-tico` downloads `tico.exe` from the tico16 release v0.02 and
the `LICENSE` from the release's commit, and checks both against pinned
SHA-256 checksums. It is not compiled here. The disk has it as `TICO.EXE`,
and the release README includes its MIT license.

## The images

`make` builds `build/linux/gr-dos-{1440,1200,720,360}k.img` with
`scripts/mkimage --format`. `scripts/image-manifest` lists each image's
files with their size, attributes, time and SHA-256; `make` requires the
four lists to be identical and to be exactly IO.SYS, MSDOS.SYS, COMMAND.COM
and the files above, in that order, and keeps the list in
`build/linux/manifest.txt`.

The files take 297 of the 354 clusters of a 360 KB disk (1 KB clusters),
leaving 58,368 bytes free. Free space on each image:

| Image | Bytes free |
|---|---:|
| 1.44 MB | 1,159,168 |
| 1.2 MB | 915,456 |
| 720 KB | 425,984 |
| 360 KB | 58,368 |

## Tests

`make test` runs, in QEMU:

- **`test-1440`, `test-1200`, `test-720`, `test-360`**: each image's files,
  with the smoke test's AUTOEXEC.BAT and HELLO.COM ([M3](m3-boot.md)). The
  `DIR` it checks lists every file of the disk.
- **`test-utils`**: `tests/utils/utils.bat` runs MORE, FIND, ATTRIB, DEBUG
  (assembling, writing and running a program, then unassembling it), MEM,
  MODE and CHKDSK, then DISKCOPY A: B: and FORMAT B: /S to a blank,
  disposable 1.44 MB image in drive B: (`scripts/smoke-test --drive-b`),
  which is then booted.
- **`test-sys-1440`, `-1200`, `-720`, `-360`**: `tests/utils/sys.bat`
  formats a blank, disposable disk of each format in drive B:, transfers the
  system with SYS, and the disk is booted.

The programs read their input from files (`tests/utils/*.in`), and
`CTTY AUX` sends their output and error messages to COM1. TICO.EXE, an
interactive editor, is not run; its checksum is pinned.

QEMU's floppy drives are all high density, and its BIOS lacks INT 13h
AH=18h, which FORMAT needs to format a 720 KB disk in a 1.44 MB drive (it
reports "Parameters not supported"). The 720 KB test disk is formatted by
`mformat` instead, and only SYS is tested on it. A 360 KB disk in QEMU's
1.2 MB drive is formatted with `FORMAT B: /F:360`.
