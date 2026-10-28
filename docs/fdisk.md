# FDISK and hard disk installation (issue #10)

GR-DOS builds MS-DOS 4.00's FDISK with Open Watcom C, JWasm and libc16,
puts it on every image, and tests it in QEMU against Microsoft's own build
of the same source, on disposable hard disk images only. With FDISK, FORMAT
and SYS, GR-DOS installs on a blank hard disk and boots from it.

FAT32, LBA (INT 13h extensions) and GPT are out of scope: FDISK 4.00 knows
none of them, and GR-DOS does not add them.

## Building

FDISK is C, like ATTRIB and MEM ([M4](m4-utilities.md#attrib-and-mem)),
with assembly modules: `BOOTREC` (the master boot record), `REBOOT`, and the
C interfaces to the parser and message retriever (`_PARSE`, `_MSGRET`). It
is compiled with the same `wcc` flags, linked with `wlink` and libc16, and
`scripts/check-runtime` checks its map: it takes `cstart`, `exit`,
`setvect`, `bdos`, `int86`, `int86x`, `intdos`, `intdosx`, `segread`,
`strcpy`, `strncpy`, `strcat`, `strcmp`, `strchr`, `strlen`, `memset`,
`isalpha`, `isdigit`, `ltoa` and the long arithmetic helpers from libc16
0.03.

| | Microsoft (M1) | GR-DOS |
|---|---:|---:|
| `FDISK.EXE` | 60,935 bytes, EXEPACKed | 37,694 bytes |

Other parts of the build:

- **Messages.** `FDISK.SKL` is built by `scripts/buildmsg` like the other
  utilities', and `FDISK5.SKL`, the messages of the master boot record, by
  `scripts/buildmsg --nosrvbld`.
- **Menus.** `scripts/menubld` replaces the DOS build's binary-only
  `MENUBLD`: it writes `FDISKM.C` from the template `FDISK.MSG`, putting the
  text of FDISK's message NNNN of `USA-MS.MSG` in place of each E8h byte
  followed by NNNN.
- **Master boot record.** `FDBOOT.ASM` is assembled and linked to
  `FDBOOT.BIN` (EXE2BIN), and `scripts/dbof` makes `FDBOOT.INC` of it, at
  0:0600, which `BOOTREC.ASM` includes. Microsoft's `FDISK.LNK` also links
  `FDBOOT.OBJ` into FDISK.EXE, but nothing refers to it; GR-DOS leaves it
  out, saving 2 KB.
- **MAPPER.** Microsoft linked `MAPPER.LIB`, the OS/2-style API of the DOS
  build. FDISK calls five of its routines, and GR-DOS links just those
  objects: `BEEP`, `EXIT`, `SCROLLUP`, `SCURPOS` and `WCHSTRA`.

`make check` compares `FDISK.CL1`, `.CL2`, `.CLA`, `.CLB`, `.CTL`,
`FDISK5.CL1`, `FDISKM.C`, `FDBOOT.BIN` and `FDBOOT.INC` with the M1
reference build. `FDISK.EXE` itself is not compared, as it is built with a
different compiler.

### Source edits

As for ATTRIB and MEM, every edit is under `#ifdef __WATCOMC__` in C or
`IFDEF __JWASM__` in assembly, or produces the same bytes, so the Microsoft
build is unchanged (`scripts/check-reference`):

- **Calling convention.** `#pragma aux (__cdecl)` for `reboot`, `parse`,
  `sysloadmsg`, `sysdispmsg` and `sysgetmsg`, which are assembly.
- **`ES`.** `_MSGRET.ASM` sets `ES` to `DS` before each call into the
  message retriever, as MEM's does, and `segread` reports `DS` for `ES`.
  FDISK's own `DOS.H` includes libc16's `<dos.h>` instead of declaring
  Microsoft's: libc16's include directory comes before FDISK's on the
  include path, as Watcom has no `#include_next`.
- **`main`.** It takes no parameters (`parse_command_line` reads the PSP).
- **Ctrl-C.** `signal(SIGINT, SIG_IGN)` becomes an INT 23h handler that
  returns, installed with `_dos_setvect`, which is how Microsoft C 5.1's
  `signal` ignored Ctrl-C; libc16 has no `signal`. DOS restores INT 23h
  when FDISK exits.
- **`getch` and `putch`.** Macros for DOS functions 08h and 06h, which
  Microsoft C 5.1's `getch` and `putch` call; libc16 has neither.
- **Floating point.** Two divisions by `double`, in `cylinders_to_percent`
  and in the FAT12 sectors-per-FAT estimate (a division by
  `2 + 512*8/1.5`, that is 8198/3), are written in integer arithmetic. Both
  give the same quotient for every possible input, so no floating-point
  library is linked.
- **`sprintf`.** libc16 has no `sprintf`. FDISK's 23 calls use three
  conversions: a number right-justified with precision 0 (`%4.0d`, which
  prints no digits for 0), a string cut or padded to a width (`%-11.11s`)
  and a character (`%c`). `fdisk_number` (a number and a suffix, such as
  `%3.0d%%`) and `fdisk_text`, in `DISPLAY.C`, do the first two exactly,
  with `libc16_ltoa`. Characters are assigned, and a call with several
  conversions becomes a chain of calls, each writing at the end of the
  last.
- **Null pointer.** Deleting a partition or logical drive cleared its
  system and volume label with `strcpy(x, NULL)`. With Microsoft C, `DS:0`
  is a zero byte, so it copied an empty string. In GR-DOS's link, `DS:0` is
  code bytes, and the copy ran into the next entry's boot indicator. It is
  now `x[0] = NUL`.
- **JWasm.** `FDBOOT.ASM`'s `repnz movsw` is a `REPNZ` byte and `MOVSW`,
  as in CHKDSK; `WCHSTRA.ASM` uses `ADDR` as a name (`OPTION NOKEYWORD`).

`scripts/prepare-dos-tree` also strips a final `^Z` from `.C` and `.H`
files, which Open Watcom C rejects.

### Branding

The first line of the main menu, message 1001, says "GR-DOS Version 4.00"
(`patches/branding`, decision 7); the copyright line stays. It is the same
length as "MS-DOS Version 4.00", so the centred menu is unchanged.

## How FDISK 4.00 behaves

The tests keep Microsoft's FDISK behaviour, including these quirks:

- FDISK writes every DOS partition as type 06h. FORMAT then gives a
  partition of fewer than 65,536 sectors type 04h.
- A Primary DOS Partition of all the disk ends a cylinder before the last
  one the BIOS reports, as the sizes below show.
- Choosing *Create Primary DOS Partition* (or an extended partition, or a
  logical drive) tests the first tracks of the free space by writing them
  (`verify_tracks`), even if the creation is then cancelled. It writes
  whole tracks from a 512-byte buffer: the first sector is F6h, and the
  rest is whatever follows the buffer in FDISK's data segment.
- `DISKOUT.C`'s `if (find_partition_type(uc(EXTENDED)));` ends in a stray
  semicolon, so the guard it was meant to be never applies.
- FDISK sees only the cylinders, heads and sectors INT 13h AH=08h reports:
  at most 1024 cylinders, 256 heads and 63 sectors, or about 8 GB. On a
  disk of more than 1024 cylinders, it sees what the BIOS's translation
  makes of it.

| Disk | Drive geometry | BIOS geometry | Partition | FDISK's size |
|---|---|---|---:|---:|
| 20 MB | 615/4/17 | same | 41,735 sectors | 20 MB |
| 32 MB | 964/4/17 | same | 65,467 sectors | 32 MB |
| 40 MB | 820/6/17 | same | 83,521 sectors | 41 MB |
| 100 MB | 203/16/63 | same | 203,553 sectors | 99 MB |
| 128 MB | 260/16/63 | same | 261,009 sectors | 127 MB |
| 500 MB | 1015/16/63 | same | 1,022,049 sectors | 499 MB |
| 1 GB | 2080/16/63 | 1024/32/63 (LBA) | 2,062,305 sectors | 1007 MB |
| 2 GB | 4160/16/63 | 520/128/63 (LBA) | 4,185,153 sectors | 2044 MB |

MS-DOS 6.22's FDISK is not a practical substitute: its source is not
published, so it cannot be built here.

## Tests

The tests run only on new, sparse image files, never on a block device.

### Tools

- **`scripts/disk-test`** runs a scenario. It boots a floppy image in QEMU
  with a new hard disk image of the size and geometry the scenario gives
  (optionally translated, as SeaBIOS does with `bios-chs-trans=lba`). It
  types at the DOS prompt through QEMU's monitor (`sendkey`), and reads
  the screen from video memory (`xp` at B8000h). The floppy is opened with
  `snapshot=on`, so it is never written.
- **`scripts/partition-table`** lists the master boot record and the chain
  of extended boot records: each entry's boot indicator, type, CHS start
  and end, and relative start and length. With `--chs` it checks the CHS
  fields against the LBA ones for the BIOS geometry.
- **`scripts/disk-sectors`** dumps a disk's non-zero sectors as text, or
  only the boot records and FDISK's test tracks (`--fdisk`). It also loads
  such a dump into an image, so that a scenario can start from the disk
  another left.

### FDISK against Microsoft's (`make test-fdisk`)

Each scenario in `tests/fdisk` has a `script`. Its expected screens, its
partition table (`expect.table`) and its boot records (`expect.sectors`)
are what Microsoft's FDISK.EXE, from the M1 reference build, does in the
same scenario (`make fdisk-expect`). The only change is the branded menu
line. GR-DOS's FDISK must match them exactly, screen for screen and
attribute for attribute.

| Scenario | |
|---|---|
| `display-blank` | a blank disk: no partitions, and no writes |
| `create-primary-max` | a primary partition of all the disk, active, then the restart |
| `create-partitions` | primary 8 MB, extended, two logical drives, set active |
| `display-partitions` | that disk's partitions and logical drives, and no writes |
| `delete-logical` | delete the last logical drive |
| `delete-all` | delete the logical drives, then the extended and primary partitions |
| `cancel` | every refusal and Esc on that disk; it must be unchanged |
| `cancel-create` | Esc at each question of a primary partition |
| `create-32m` | a 32 MB primary partition on a 40 MB disk; an extended partition too big, then 20% |
| `switches` | `FDISK 1 /PRI:8 /EXT:12 /LOG:5 /Q`, its errorlevel, and bad switches |
| `size-32m` … `size-2g` | a primary partition of all of a disk of each size in the table above |

### Installing GR-DOS (`make test-install`)

Each scenario in `tests/install` boots the 1.44 MB release image with a
blank hard disk. FDISK creates a Primary DOS Partition of all of it, active,
and restarts. Then `FORMAT C:` (with a label), `SYS C:` and
`COPY COMMAND.COM C:\` run, the floppy is ejected, and the machine is
reset. It must boot from the hard disk to the date and time prompts and
`C>`, `VER` must say GR-DOS, and `DIR` must show the label and
COMMAND.COM. `expect.table` checks the type FORMAT gave the partition: 04h
on the 20 MB disk, 06h on the 100 MB one.
