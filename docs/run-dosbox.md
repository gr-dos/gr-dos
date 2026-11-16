# Trying the tools in DOSBox-X (`make run-dosbox`)

`make run-dosbox` starts DOSBox-X with C:\DOS holding exactly the files of
a CF install's C:\DOS ([deploy-cf.md](deploy-cf.md)). That is every file
of `build/linux/cf/manifest.txt`, but IO.SYS, MSDOS.SYS and COMMAND.COM.
It is for trying GR-DOS's command line tools quickly: the MS-DOS 4.00
utilities, TICO and the other `*16` programs ([dist16.md](dist16.md)).

The DOS underneath is DOSBox-X's, not GR-DOS's. DOSBox-X emulates a DOS
kernel and runs its own shell. GR-DOS's IO.SYS, MSDOS.SYS and COMMAND.COM
are not loaded, so a program can behave differently here than on GR-DOS.
For GR-DOS itself, boot an image (`make test` does, in QEMU), or a CF
card.

```sh
make run-dosbox                     # dosbox-x, with its window
make run-dosbox DOSBOX=/opt/dosbox-x/bin/dosbox-x
make run-dosbox DOSBOX_ARGS='-set "cpu cycles=max"'
```

`dosbox-x` is not needed to build or test GR-DOS, and `run-dosbox` is not
part of `make test`.

## The session

Everything is in `build/linux/dosbox`, which `make clean` removes:

| Path | In DOSBox-X | |
|---|---|---|
| `build/linux/dosbox/C/DOS` | `C:\DOS` | copied afresh from `build/linux/cf` each time, so nothing done in DOSBox-X changes the build |
| `build/linux/dosbox/D` | `D:` | a scratch directory for your files; kept between sessions; the session starts in `D:\` |
| `build/linux/dosbox/dosbox-x.conf` | | the configuration, written each time |

`scripts/run-dosbox` passes the configuration with `-conf`, so your own
DOSBox-X configuration is not loaded. It sets:

- `[dos] ver = 4.0`: DOSBox-X reports DOS 4.00 (`VER`). Many of MS-DOS
  4.00's utilities refuse any other version.
- `[config] set path = C:\DOS`, and `[dos] drive z expand path = false`:
  `PATH` is `C:\DOS` alone, not DOSBox-X's
  `Z:\;Z:\SYSTEM;Z:\BIN;Z:\DOS;…`. So a name runs GR-DOS's program, not
  DOSBox-X's own TREE, LABEL, MODE or KEYB from `Z:\DOS`.

Z: is still there, because DOSBox-X keeps its tools on it. Run them by
their full paths, for example `Z:\SYSTEM\MOUNT` or `Z:\SYSTEM\IMGMOUNT`.
`COMSPEC` is DOSBox-X's shell, `Z:\COMMAND.COM`.

## Commands DOSBox-X runs itself

DOSBox-X's shell runs some commands itself, before looking at `PATH`.
For these, a typed name runs DOSBox-X's command, even with the program's
extension. Only the full path runs GR-DOS's:

| GR-DOS program | `NAME` | `NAME.EXT` | Use |
|---|---|---|---|
| `ATTRIB.EXE` | DOSBox-X's | DOSBox-X's | `C:\DOS\ATTRIB` |
| `MORE.COM` | DOSBox-X's | DOSBox-X's | `C:\DOS\MORE` |

No other program of the distribution is intercepted: every other name, typed alone,
runs C:\DOS's program. This was checked with DOSBox-X 2026.01.02, and the
session's banner says it too. A new DOSBox-X may change the list, and
another check finds out:

```sh
scripts/run-dosbox --intercepts build/linux/cf build/linux/dosbox
```

Without a window, that puts in C:\DOS, for each program of the
distribution, a `.COM` that prints its own name. It runs each one as
`NAME`, `NAME.EXT` and `C:\DOS\NAME`, and prints the ones that did not run.

## What works here, and what does not

As checked with DOSBox-X 2026.01.02:

- **Work:** the `*16` programs (CRCSUM, DF, DIFF16, LESS, MD5SUM, TAR,
  TRUNCATE and WHICH) and TICO; FIND, SORT, FC, COMP, TREE, XCOPY, MEM,
  GRAFTABL, and ATTRIB and MORE by their full paths.
- **Refuse the drives, safely:** the disk tools work on sectors, which a
  mounted host directory does not have.
  - CHKDSK says "Cannot CHKDSK a network drive" (DOSBox-X reports mounted
    directories as network drives).
  - FORMAT A: says "Cannot format an ASSIGNed or SUBSTed drive".
  - SYS and DISKCOPY say "Invalid drive specification".
  - FDISK and RECOVER have no disk of their own to work on. RECOVER waits
    for a key before it starts.

  To try them, attach a disposable image with `Z:\SYSTEM\IMGMOUNT`, never
  a disk you need.
- **Stop or hang DOSBox-X:**
  - **SHARE** ends DOSBox-X at once ("Corrupt MCB chain"). DOSBox-X
    already emulates SHARE (`[dos] share = true`).
  - **PRINT** installs its resident part, and then the session hangs.
  - **DEBUG and EDLIN** end DOSBox-X when input redirected from a file
    runs out ("Redirected input reached EOF"). Typing at them is fine.
- **Load, but are not tested here:** APPEND, ASSIGN, NLSFUNC, GRAPHICS
  and FASTOPEN. They are resident programs that hook into MS-DOS 4.00's
  kernel, which DOSBox-X's only resembles. IFSFUNC says "IFSFUNC already
  installed", because DOSBox-X reports a network redirector. KEYB needs
  KEYBOARD.SYS, which GR-DOS does not have yet.
- **Report DOSBox-X's devices:** `MODE CON` shows the status DOSBox-X's
  CON device gives (`COLUMNS=40`, `LINES=136`), not the screen's.
