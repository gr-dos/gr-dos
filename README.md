# GR-DOS

GR-DOS is a fork of the MS-DOS 4.00 source that Microsoft published under
the MIT license. It is built on Linux with open tools, booted in QEMU, and
tested in GitHub Actions.

Today the build produces the boot sector, IO.SYS, MSDOS.SYS, COMMAND.COM and
33 utilities: FORMAT, SYS, CHKDSK, DISKCOPY, FDISK, ATTRIB, MORE, FIND, FC,
DEBUG, MEM and MODE, every other MS-DOS 4.00 command written in
assembly ([`docs/m5-utilities.md`](docs/m5-utilities.md)), and JOIN and
SUBST ([`docs/join-subst.md`](docs/join-subst.md)), with offline command
help, `HELP` ([`docs/help.md`](docs/help.md)). It also makes
bootable 1.44 MB, 1.2 MB, 720 KB and 360 KB floppy images with the tico16
editor; the larger ones carry more of the utilities. With FDISK,
FORMAT and SYS, GR-DOS installs on a hard disk and boots from it
([`docs/fdisk.md`](docs/fdisk.md)), and `scripts/deploy-cf` installs it from
Linux on a CF card or disk image, then updates C: without touching the data
drives ([`docs/deploy-cf.md`](docs/deploy-cf.md)). That install, and the release ZIP, also
carry the DOS programs of the [gr-dos](https://github.com/gr-dos) organization's
`*16` repositories, such as LESS, DIFF and TAR. They are found on GitHub
and pinned in `dist16/lock` ([`docs/dist16.md`](docs/dist16.md)). Apart from the GR-DOS branding of the
banner, `VER` and FDISK's menu (`patches/branding`), and the kernel's GR-DOS
identification call (`patches/kernel`, [`docs/grver.md`](docs/grver.md)), the binaries of the
assembly sources are byte-identical to the original MASM/LINK build; ATTRIB,
MEM, FDISK, FC, JOIN, SUBST, BACKUP, RESTORE, FILESYS and REPLACE, which are C, are built with Open Watcom C and GR-DOS's own C
runtime ([`docs/m4-utilities.md`](docs/m4-utilities.md)). See
[`docs/00-mvp.md`](docs/00-mvp.md) for the plan and its status.

## Building

You need:

- Perl 5.42 as `perl` on `PATH`;
- a C compiler, make, git, curl and xz;
- mtools and `qemu-system-i386`;
- `fsck.fat` (dosfstools), for `make test-deploy-cf`.

```sh
make          # build into build/linux, fetching JWasm, Open Watcom and the *16 programs into build/tools
make check    # build without the branding and compare with the MS-DOS 4.00 reference build
make test     # boot each image in QEMU, and test the utilities on disposable disks
make dist     # package the release assets in build/linux/release
make run-dosbox  # try the tools in DOSBox-X, with C:\DOS as a CF install has it
make run-dosbox-cf  # boot GR-DOS in DOSBox-X from a throwaway CF install (or run-dosbox-1440k, ...)
make help     # list every target, including each single test, and the variables
```

`make run-dosbox` needs `dosbox-x`. It runs the tools on DOSBox-X's own DOS
kernel and shell, not GR-DOS's, and DOSBox-X runs its own ATTRIB and MORE.
`make run-dosbox-cf`, `make run-dosbox-1440k` and the other floppy formats
boot GR-DOS itself, from a copy of the image that is discarded when DOSBox-X
exits ([`docs/run-dosbox.md`](docs/run-dosbox.md)).

## CF cards

`scripts/deploy-cf` installs GR-DOS on a CF card in a USB reader, or a disk
image ([`docs/deploy-cf.md`](docs/deploy-cf.md)). `provision` erases the
card and makes C: (10 MiB) and FAT16 data drives D:, E:, ... over the
rest. `update` replaces C: only: it checks that the partition tables are as
it made them, and never writes a sector outside C:. Your own settings go
in `D:\AUTOEXEC.BAT`, which C:'s calls, and `D:\CONFIG.SYS`, which C:'s
includes with `INCLUDEFILE=`.

```sh
scripts/deploy-cf inspect /dev/sdX          # writes nothing
sudo scripts/deploy-cf provision /dev/sdX   # first time: erases the card
sudo scripts/deploy-cf update /dev/sdX      # afterwards: C: only
```

## Floppy images

| Format | Image | Bytes | Geometry | Free |
|---|---|---:|---|---:|
| 3.5" 1.44 MB HD (default) | `build/linux/gr-dos-1440k.img` | 1,474,560 | 80 cylinders, 2 heads, 18 sectors | 591,360 |
| 5.25" 1.2 MB HD | `build/linux/gr-dos-1200k.img` | 1,228,800 | 80 cylinders, 2 heads, 15 sectors | 347,648 |
| 3.5" 720 KB DD | `build/linux/gr-dos-720k.img` | 737,280 | 80 cylinders, 2 heads, 9 sectors | 47,104 |
| 5.25" 360 KB DD | `build/linux/gr-dos-360k.img` | 368,640 | 40 cylinders, 2 heads, 9 sectors | 16,384 |

`make` builds all four. Each is a boot disk for a machine with two floppy
drives, the GR-DOS disk in A: and programs and data in B:; the larger ones
carry more commands ([`docs/m5-utilities.md`](docs/m5-utilities.md#floppies)):

| File | 360 KB | 720 KB | 1.2 MB, 1.44 MB |
|---|:-:|:-:|:-:|
| `IO.SYS`, `MSDOS.SYS` (hidden, system, read-only), `COMMAND.COM` | ✓ | ✓ | ✓ |
| `FORMAT.COM`, `SYS.COM`, `CHKDSK.COM`, `DISKCOPY.COM`, `FDISK.EXE` | ✓ | ✓ | ✓ |
| `ATTRIB.EXE`, `MORE.COM`, `FIND.EXE`, `FC.EXE`, `DEBUG.COM`, `MEM.EXE`, `MODE.COM` | ✓ | ✓ | ✓ |
| `TICO.EXE`, the tico16 text editor, v0.02 | ✓ | ✓ | ✓ |
| `XCOPY.EXE`, `COMP.COM`, `DISKCOMP.COM`, `LABEL.COM`, `TREE.COM`, `SORT.EXE`, `EDLIN.COM`, `PRINT.COM`, `ASSIGN.COM`, `RECOVER.COM` | | ✓ | ✓ |
| `KEYB.COM`, with `COUNTRY.SYS` and `KEYBOARD.SYS` ([`docs/country-keyboard.md`](docs/country-keyboard.md)) | | ✓ | ✓ |
| `BACKUP.COM`, `RESTORE.COM` ([`docs/backup-restore.md`](docs/backup-restore.md)) | | ✓ | ✓ |
| `REPLACE.EXE` ([`docs/replace.md`](docs/replace.md)) | | ✓ | ✓ |
| `APPEND.EXE`, `SHARE.EXE`, `EXE2BIN.EXE`, `GRAFTABL.COM`, `GRAPHICS.COM`, `GRAPHICS.PRO`, `NLSFUNC.EXE` | | | ✓ |
| `JOIN.EXE`, `SUBST.EXE` ([`docs/join-subst.md`](docs/join-subst.md)) | | | ✓ |
| `DISPLAY.SYS`, with `EGA.CPI` ([`docs/codepage.md`](docs/codepage.md)) | | | ✓ |
| `PRINTER.SYS`, with `4201.CPI`, `4208.CPI` and `5202.CPI` ([`docs/printer.md`](docs/printer.md)) | | | ✓ |
| `HELP.EXE` and `GRDOS.HLP`, GR-DOS's command help ([`docs/help.md`](docs/help.md)) | | ✓ | ✓ |
| `AUTOEXEC.BAT`: `PROMPT $P$G` and `PATH A:\` | ✓ | ✓ | ✓ |

The 360 KB disk's files are frozen. FASTOPEN, IFSFUNC, FILESYS, GRVER and LCD.CPI are on C: only. `image/files-360k.txt` (and so on) lists each image's
files in order, and `make` checks the image against it.
`build/linux/manifest-360k.txt` (and so on) lists them with their checksums. To
build one image from a built tree, choose the format with `--format` (1440
if omitted); further arguments are files to copy to it:

```sh
scripts/mkimage --format 720 gr-dos-720k.img build/linux/SRC
```

To boot an image in QEMU, which picks the drive type from the image size:

```sh
qemu-system-i386 -drive file=build/linux/gr-dos-1440k.img,if=floppy,format=raw -boot a
qemu-system-i386 -drive file=build/linux/gr-dos-360k.img,if=floppy,format=raw -boot a
```

The images are raw: the disk's sectors in order. To write one to a floppy
disk of the same format on Linux:

```sh
sudo dd if=build/linux/gr-dos-1440k.img of=/dev/sdX bs=512 conv=fsync      # USB drive
sudo dd if=build/linux/gr-dos-720k.img of=/dev/fd0u720 bs=512 conv=fsync    # floppy controller
```

`/dev/fd0u1440`, `/dev/fd0h1200` and `/dev/fd0h360` (`/dev/fd0d360` in a
360 KB drive) are the other formats on the floppy controller. The release's
`README.txt` has more, including Windows and DOS.

The images are reproducible: file times and the volume serial number come
from `SOURCE_DATE_EPOCH`, by default the time of the last commit. `make test`
boots each one (`make test-1440`, `test-1200`, `test-720` or `test-360` for
one) and tests the utilities (`make test-utils`, `make test-sys-1440` and so
on), FORMAT, SYS and DISKCOPY on blank, disposable images in drive B:. It
tests the commands of [`docs/m5-utilities.md`](docs/m5-utilities.md)
(`make test-extras`), and boots each format's files with a data disk in B:
(`make test-floppy-360` and so on). It
compares FC's output with Microsoft's FC.EXE's (`make test-fc`), and JOIN's
and SUBST's with Microsoft's on a CF install's C: and D: (`make
test-join-subst`), and BACKUP's and RESTORE's, onto and from floppy images,
with Microsoft's output and backup (`make test-backup-restore`), and
FILESYS's, without IFSFUNC and with it (`make test-filesys`), and
REPLACE's, and the files it leaves, on C:, D: and floppy images (`make
test-replace`), boots
with `COUNTRY=` in CONFIG.SYS (`make test-country`), types through KEYB's
layouts (`make test-keyb`), checks what PRINTER.SYS, PRINT and GRAPHICS
send to QEMU's parallel port (`make test-printer`), runs FDISK on disposable hard disk images against Microsoft's build of
it (`make test-fdisk`), and installs GR-DOS on a blank hard disk and boots
it (`make test-install`). It provisions disk images of 512 MB to 8 GB with
`scripts/deploy-cf`, boots them, and updates them, checking that every
sector outside C: stays the same (`make test-deploy-cf`). It tests
`scripts/dist16` offline, against a fake GitHub (`make test-dist16`).

## Releases

CI creates a release when a merge to `main` carries a new `VERSION`. It has
exactly six assets:

| Asset | Contents |
|---|---|
| `gr-dos-VERSION-1440k.img` | bootable 1.44 MB floppy image |
| `gr-dos-VERSION-1200k.img` | bootable 1.2 MB floppy image |
| `gr-dos-VERSION-720k.img` | bootable 720 KB floppy image |
| `gr-dos-VERSION-360k.img` | bootable 360 KB floppy image |
| `gr-dos-VERSION.zip` | system files, utilities, documentation, build details and logs |
| `SHA256SUMS` | checksums of the four images and the ZIP |

The ZIP holds no disk images. It unpacks to:

```text
gr-dos-VERSION/
├── README.txt        what is in the release, how to boot it, and the licenses
├── BIN/
│   ├── IO.SYS
│   ├── MSDOS.SYS
│   ├── COMMAND.COM
│   ├── MSBOOT.BIN
│   ├── FORMAT.COM, SYS.COM, CHKDSK.COM, DISKCOPY.COM, FDISK.EXE,
│   │   ATTRIB.EXE, MORE.COM, FIND.EXE, FC.EXE, DEBUG.COM, MEM.EXE,
│   │   MODE.COM
│   ├── TICO.EXE
│   ├── APPEND.EXE, ASSIGN.COM, COMP.COM, DISKCOMP.COM, EDLIN.COM,
│   │   EXE2BIN.EXE, FASTOPEN.EXE, GRAFTABL.COM, GRAPHICS.COM,
│   │   IFSFUNC.EXE, KEYB.COM, LABEL.COM, NLSFUNC.EXE, PRINT.COM,
│   │   RECOVER.COM, SHARE.EXE, SORT.EXE, TREE.COM, XCOPY.EXE,
│   │   JOIN.EXE, SUBST.EXE, BACKUP.COM, RESTORE.COM, FILESYS.EXE,
│   │   REPLACE.EXE, GRAPHICS.PRO, COUNTRY.SYS, KEYBOARD.SYS
│   ├── DISPLAY.SYS, EGA.CPI, LCD.CPI   code page switching for the screen
│   ├── PRINTER.SYS, 4201.CPI, 4208.CPI, 5202.CPI   for printers
│   ├── GRVER.EXE     the GR-DOS release version, from the kernel
│   ├── CRCSUM.EXE, DF.EXE, DIFF.EXE, LESS.EXE, MD5SUM.EXE, PATCH.EXE,
│   │   RETROFCH.EXE, TAR.EXE, TCL.EXE, TERM16.EXE, TRUNCATE.EXE, WHICH.COM (the *16 programs dist16/lock pins)
│   ├── SOURCES.TXT   only with a *16 program under the GPL or another
│   │                 source license: where its source is, and its license
│   └── AUTOEXEC.BAT
├── SOURCE/           only then: each such program's source archives
├── BUILDINFO         the commit and tool versions
├── SHA256SUMS        checksums of the files in the ZIP
└── LOGS/
    ├── make.log
    └── test.log
```

`scripts/mkzip` writes it reproducibly: sorted entries, every time set to
`SOURCE_DATE_EPOCH`, fixed permissions and no extra fields. `make dist`
writes the same assets locally in `build/linux/release`, and the ZIP's tree
in `build/linux/dist`. It packages `build/make.log` and `build/test.log` if
they exist (set `DIST_LOGS` to choose others).

To verify a download, put the assets in one directory and run:

```sh
sha256sum -c SHA256SUMS
unzip gr-dos-VERSION.zip
cd gr-dos-VERSION && sha256sum -c SHA256SUMS
```

Every CI run also uploads the release assets (`gr-dos`) and, for
debugging, the unpacked tree, the logs and the QEMU output of each test
(`gr-dos-unpacked`) as Actions artifacts.

## Documentation

- [`docs/00-mvp.md`](docs/00-mvp.md): goals, decisions, milestones.
- [`docs/provenance.md`](docs/provenance.md): the source, restorations and
  licenses.
- [`docs/m1-reference-build.md`](docs/m1-reference-build.md): the original
  build run under DOSBox-X, used as the reference.
- [`docs/m2-jwasm.md`](docs/m2-jwasm.md): the Linux build with JWasm and
  `wlink`.
- [`docs/m3-boot.md`](docs/m3-boot.md): the boot image and smoke test, and the
  86Box check on an 8088 and a V20.
- [`docs/m4-utilities.md`](docs/m4-utilities.md): the utilities, TICO.EXE,
  the four images and the utility tests.
- [`docs/fdisk.md`](docs/fdisk.md): FDISK, its tests against Microsoft's
  build, and installing on a hard disk.
- [`docs/fc.md`](docs/fc.md): FC and its tests against Microsoft's build.
- [`docs/join-subst.md`](docs/join-subst.md): JOIN and SUBST, how they
  behave, and their tests against Microsoft's build on C: and D:.
- [`docs/deploy-cf.md`](docs/deploy-cf.md): installing on a CF card from
  Linux, and updating C: only.
- [`docs/m5-utilities.md`](docs/m5-utilities.md): the other assembly
  utilities, each format's files, and their tests.
- [`docs/country-keyboard.md`](docs/country-keyboard.md): COUNTRY.SYS and
  KEYBOARD.SYS, the countries and layouts, configuration and limits.
- [`docs/codepage.md`](docs/codepage.md): DISPLAY.SYS, EGA.CPI and LCD.CPI,
  code page switching with MODE, CHCP and KEYB, the displays, and limits.
- [`docs/printer.md`](docs/printer.md): PRINTER.SYS and the printer fonts,
  PRINT and GRAPHICS, the printers, their tests on QEMU's parallel port,
  and limits.
- [`docs/grver.md`](docs/grver.md): the kernel's GR-DOS identification
  call (`INT 21h AX=3347h`), GRVER.EXE, and how a program calls it.
- [`docs/help.md`](docs/help.md): HELP.EXE and GRDOS.HLP, the offline
  command help, its topic files and how the build checks them against the
  distribution.
- [`docs/dist16.md`](docs/dist16.md): the `*16` programs, how they are
  found, pinned and checked, how to add or exclude one, and how a program
  under the GPL ships with its source.
- [`docs/run-dosbox.md`](docs/run-dosbox.md): `make run-dosbox`, the
  commands DOSBox-X runs itself, and what works there; and `make
  run-dosbox-cf` and the floppy targets, which boot GR-DOS.

## License

GR-DOS's own scripts, patches and documentation are MIT, see
[`LICENSE`](LICENSE). The MS-DOS 4.00 source in `v4.0` keeps its own MIT
license, [`v4.0/LICENSE`](v4.0/LICENSE). TICO.EXE is
[tico16](https://github.com/tico-edit/tico16)'s, and each other `*16` program is its
repository's, under that repository's license (`dist16/lock`). Most are
MIT. TCL.EXE ([tcl16](https://github.com/gr-dos/tcl16)) is under the Tcl
license, with Tiny Tcl's notice; GitHub does not recognize that license,
so `dist16/config` names it, pinned to the license file's SHA-256
([`docs/dist16.md`](docs/dist16.md#license-overrides), issue #83).
PATCH.EXE ([patch16](https://github.com/gr-dos/patch16)) is under the GPL
version 2 or later, and a `*16` program may also be under version 1 or
later (perl16's Perl 3); such a program ships with its exact
corresponding source
([`docs/dist16.md`](docs/dist16.md#source-licenses), issue #56). GR-DOS is
an aggregation of separately licensed programs: including one under the
GPL does not relicense GR-DOS, its kernel or any other program.
ATTRIB.EXE, MEM.EXE, FDISK.EXE, FC.EXE, JOIN.EXE, SUBST.EXE, BACKUP.COM,
RESTORE.COM, FILESYS.EXE, REPLACE.EXE, GRVER.EXE and HELP.EXE are
compiled with Open Watcom C but linked with
[libc16](https://github.com/gr-dos/libc16), an MIT C runtime, and contain
no Open Watcom code ([`docs/m4-utilities.md`](docs/m4-utilities.md)). The release README includes
these notices. MS-DOS is a trademark of
Microsoft. GR-DOS is an independent project, not endorsed by Microsoft or
IBM.
