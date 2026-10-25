# GR-DOS

GR-DOS is a fork of the MS-DOS 4.00 source that Microsoft published under
the MIT license. It is built on Linux with open tools, booted in QEMU, and
tested in GitHub Actions.

Today the build produces the boot sector, IO.SYS, MSDOS.SYS and COMMAND.COM,
and bootable 1.44 MB and 1.2 MB floppy images. Apart from the GR-DOS branding of the
banner and `VER` (`patches/branding`), the binaries are byte-identical to
the original MASM/LINK build. See
[`docs/00-mvp.md`](docs/00-mvp.md) for the plan and its status.

## Building

You need:

- Perl 5.42 as `perl` on `PATH`;
- a C compiler, make, git, curl and xz;
- mtools and `qemu-system-i386`.

```sh
make          # build into build/linux, fetching JWasm and Open Watcom into build/tools
make check    # build without the branding and compare with the MS-DOS 4.00 reference build
make test     # boot both images in QEMU and check a scripted session
make dist     # package the release assets in build/linux/release
```

## Floppy images

| Format | Image | Bytes | Geometry |
|---|---|---|---|
| 3.5" 1.44 MB (default) | `build/linux/gr-dos-1440k.img` | 1,474,560 | 80 cylinders, 2 heads, 18 sectors |
| 5.25" 1.2 MB | `build/linux/gr-dos-1200k.img` | 1,228,800 | 80 cylinders, 2 heads, 15 sectors |

`make` builds both. To build one image from a built tree, choose the format
with `--format` (1440 if omitted):

```sh
scripts/mkimage --format 1200 gr-dos-1200k.img build/linux/SRC
```

To boot an image in QEMU, which picks the drive type from the image size:

```sh
qemu-system-i386 -drive file=build/linux/gr-dos-1440k.img,if=floppy,format=raw -boot a
qemu-system-i386 -drive file=build/linux/gr-dos-1200k.img,if=floppy,format=raw -boot a
```

The images are reproducible: file times and the volume serial number come
from `SOURCE_DATE_EPOCH`, by default the time of the last commit. `make test`
boots each one (`make test-1440`, `make test-1200` for one).

## Releases

CI creates a release when a merge to `main` carries a new `VERSION`. It has
exactly four assets:

| Asset | Contents |
|---|---|
| `gr-dos-VERSION-1440k.img` | bootable 1.44 MB floppy image |
| `gr-dos-VERSION-1200k.img` | bootable 1.2 MB floppy image |
| `gr-dos-VERSION.zip` | system files, documentation, build details and logs |
| `SHA256SUMS` | checksums of the two images and the ZIP |

The ZIP holds no disk images. It unpacks to:

```text
gr-dos-VERSION/
├── README.txt        what is in the release, how to boot it, and the licenses
├── BIN/
│   ├── IO.SYS
│   ├── MSDOS.SYS
│   ├── COMMAND.COM
│   └── MSBOOT.BIN
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
debugging, the unpacked tree, the logs and the QEMU serial output of each
smoke test (`gr-dos-unpacked`) as Actions artifacts.

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

## License

GR-DOS's own scripts, patches and documentation are MIT, see
[`LICENSE`](LICENSE). The MS-DOS 4.00 source in `v4.0` keeps its own MIT
license, [`v4.0/LICENSE`](v4.0/LICENSE). MS-DOS is a trademark of
Microsoft. GR-DOS is an independent project, not endorsed by Microsoft or
IBM.
