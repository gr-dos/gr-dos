# GR-DOS

GR-DOS is a fork of the MS-DOS 4.00 source that Microsoft published under
the MIT license. It is built on Linux with open tools, booted in QEMU, and
tested in GitHub Actions.

Today the build produces the boot sector, IO.SYS, MSDOS.SYS, COMMAND.COM and
twelve utilities (FORMAT, SYS, CHKDSK, DISKCOPY, FDISK, ATTRIB, MORE, FIND,
FC, DEBUG, MEM and MODE), and bootable 1.44 MB, 1.2 MB, 720 KB and 360 KB floppy
images, which all hold the same files, with the tico16 editor. With FDISK,
FORMAT and SYS, GR-DOS installs on a hard disk and boots from it
([`docs/fdisk.md`](docs/fdisk.md)). Apart from the GR-DOS branding of the
banner, `VER` and FDISK's menu (`patches/branding`), the binaries of the
assembly sources are byte-identical to the original MASM/LINK build; ATTRIB,
MEM, FDISK and FC, which are C, are built with Open Watcom C and GR-DOS's own C
runtime ([`docs/m4-utilities.md`](docs/m4-utilities.md)). See
[`docs/00-mvp.md`](docs/00-mvp.md) for the plan and its status.

## Building

You need:

- Perl 5.42 as `perl` on `PATH`;
- a C compiler, make, git, curl and xz;
- mtools and `qemu-system-i386`.

```sh
make          # build into build/linux, fetching JWasm, Open Watcom and TICO.EXE into build/tools
make check    # build without the branding and compare with the MS-DOS 4.00 reference build
make test     # boot each image in QEMU, and test the utilities on disposable disks
make dist     # package the release assets in build/linux/release
```

## Floppy images

| Format | Image | Bytes | Geometry | Free |
|---|---|---:|---|---:|
| 3.5" 1.44 MB HD (default) | `build/linux/gr-dos-1440k.img` | 1,474,560 | 80 cylinders, 2 heads, 18 sectors | 1,125,376 |
| 5.25" 1.2 MB HD | `build/linux/gr-dos-1200k.img` | 1,228,800 | 80 cylinders, 2 heads, 15 sectors | 881,664 |
| 3.5" 720 KB DD | `build/linux/gr-dos-720k.img` | 737,280 | 80 cylinders, 2 heads, 9 sectors | 392,192 |
| 5.25" 360 KB DD | `build/linux/gr-dos-360k.img` | 368,640 | 40 cylinders, 2 heads, 9 sectors | 24,576 |

`make` builds all four, with the same files in each, in this order:

| File | |
|---|---|
| `IO.SYS`, `MSDOS.SYS` | the DOS BIOS and kernel (hidden, system, read-only) |
| `COMMAND.COM` | the command interpreter |
| `FORMAT.COM`, `SYS.COM`, `CHKDSK.COM`, `DISKCOPY.COM`, `FDISK.EXE` | disk utilities |
| `ATTRIB.EXE`, `MORE.COM`, `FIND.EXE`, `FC.EXE`, `DEBUG.COM`, `MEM.EXE`, `MODE.COM` | other utilities |
| `TICO.EXE` | the tico16 text editor, v0.02 (instead of EDLIN) |
| `AUTOEXEC.BAT` | `PROMPT $P$G` and `PATH A:\` |

`build/linux/manifest.txt` lists them with their checksums; `make` checks
that the four images have exactly these files, with the same contents. To
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
compares FC's output with Microsoft's FC.EXE's (`make test-fc`), runs FDISK on disposable hard disk images against Microsoft's build of
it (`make test-fdisk`), and installs GR-DOS on a blank hard disk and boots
it (`make test-install`).

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
│   └── AUTOEXEC.BAT
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

## License

GR-DOS's own scripts, patches and documentation are MIT, see
[`LICENSE`](LICENSE). The MS-DOS 4.00 source in `v4.0` keeps its own MIT
license, [`v4.0/LICENSE`](v4.0/LICENSE). TICO.EXE is
[tico16](https://github.com/tico-edit/tico16)'s, under its MIT license.
ATTRIB.EXE, MEM.EXE, FDISK.EXE and FC.EXE are compiled with Open Watcom C but linked with
[libc16](https://github.com/gr-dos/libc16), an MIT C runtime, and contain
no Open Watcom code ([`docs/m4-utilities.md`](docs/m4-utilities.md)). The release README includes
these notices. MS-DOS is a trademark of
Microsoft. GR-DOS is an independent project, not endorsed by Microsoft or
IBM.
