# Installing on a CF card (issue #14)

`scripts/deploy-cf` installs GR-DOS from Linux on a CF card in a USB reader,
or on a raw hard disk image file. The first deployment, `provision`, sets
the card up. Later deployments, `update`, replace only C:. They never write
a sector of the partition tables or of the data drives, D:, E: and so on.

```sh
make                                        # also stages the distribution in build/linux/cf
scripts/deploy-cf inspect /dev/sdX          # writes nothing: identity, partitions, plan
sudo scripts/deploy-cf provision /dev/sdX   # once: erases the whole card
sudo scripts/deploy-cf update /dev/sdX      # each time after: replaces C: only
```

`/dev/disk/by-id/usb-...` names work too. Disk images use the same code:

```sh
truncate -s 512483328 cf.img                # a 512 MB card: 993 cylinders, 16 heads, 63 sectors
scripts/deploy-cf provision --confirm cf.img cf.img
qemu-system-i386 -drive file=cf.img,if=none,id=hd,format=raw \
  -device ide-hd,drive=hd,cyls=993,heads=16,secs=63,bios-chs-trans=none -boot c
```

## Prerequisites

- Linux, with `lsblk` (util-linux) and Perl 5.36 or later. Under `sudo`,
  `scripts/deploy-cf` runs with the system's `perl`, not the 5.42 the build
  needs; it uses no modules beyond core Perl.
- A built tree. `make` stages the distribution in `build/linux/cf`, and
  `--dist DIR` names another. It holds `manifest.txt`, the files it lists,
  `MSBOOT.BIN`, `FDBOOT.BIN` and `VERSION`. Every file is checked against
  its SHA-256 in the manifest.
- `sudo`, or membership of the `disk` group, for a block device. Image
  files need neither.
- The tests (`make test-deploy-cf`) also need mtools, `fsck.fat`
  (dosfstools) and `qemu-system-i386`.

The tool formats with its own code, not `mkfs.fat` or `mformat`, and
partitions with its own code, not `sfdisk`. DOS 4.00 needs details those
tools do not give (see [What DOS 4.00 needs](#what-dos-400-needs)). mtools,
`fsck.fat` and DOS's own CHKDSK check the result in the tests.

## Commands

| Command | Writes | Options |
|---|---|---|
| `inspect TARGET` | nothing | `--system-size` (for the plan it shows) |
| `provision TARGET` | the whole disk | `--system-size SIZE` (default `10M`), `--geometry C/H/S`, `--allow-unaddressable`, `--allow-fixed-disk`, `--dist`, `--dry-run`, `--confirm NAME` |
| `update TARGET` | partition 1 (C:) only | `--recover`, `--allow-fixed-disk`, `--dist`, `--dry-run`, `--confirm NAME` |

`provision` and `update` show the target first: its path and what that
path resolves to, the vendor and model, the serial number, the bus, the
`by-id` name and the size. They then show the plan. To go on, type the
target's kernel name (`sdd`) or image file name on the terminal, or give it
beforehand as `--confirm NAME`. `--dry-run` runs every check and shows the
plan, but writes nothing.

### Which devices are refused

A block device is refused unless all of these hold:

- it is a whole disk, not a partition;
- it has 512-byte logical sectors and a medium (an empty reader shows 0
  bytes);
- no partition of it is mounted, used as swap, or held by device-mapper or
  md;
- none of its partitions is a ZFS, LVM, md RAID or LUKS member;
- it is not the disk under `/`, `/boot`, `/boot/efi`, `/usr`, `/var` or
  `/home`, followed through partitions and device-mapper or md members;
- it is removable or on USB, unless `--allow-fixed-disk` is given.

All of these checks read `/proc/self/mountinfo`, `/proc/swaps` and
`/sys` before anything is opened, and `--dry-run` runs them too. The
device is then opened `O_EXCL`, so the kernel refuses it (`EBUSY`) if any
part of it is mounted or in use. An image file attached to a loop device
is refused.

## Layout

`provision` writes:

| Sectors | |
|---|---|
| 0 | master boot record: FDISK's boot code (`FDBOOT.BIN`, bytes 600h–7BDh) and a table of two entries |
| 1 | the layout record (text: magic, disk id, geometry, size, partitions, SHA-256) |
| 2 – end of track 0 | zero |
| partition 1 | C:, active, from head 1 of cylinder 0 to a cylinder boundary: at least `--system-size` |
| partition 2 | extended (05h), over the remaining reachable cylinders |
| in partition 2 | one logical drive per extended boot record, each at most 2000 MiB, the cylinders shared evenly |

Each extended boot record is at head 0, sector 1 of a cylinder. Its
logical drive starts one track later. Partition types are those FORMAT
gives: 01h for FAT12, 04h for FAT16 under 65,536 sectors, and 06h for the
rest.

| Card | Geometry | C: | Logical drives |
|---|---|---|---|
| 512 MB (`/dev/sdd`, 512,483,328 bytes) | 993/16/63 | 10.3 MiB, FAT12, 4 KiB clusters | D: 478 MiB, FAT16, 8 KiB |
| 2 GB (4160/16/63 drive) | 520/128/63 | 11.8 MiB, FAT12 | D: and E:, 1020 MiB and 1016 MiB, 16 KiB |
| 4 GB (8320/16/63) | 522/255/63 | 15.7 MiB, FAT12 | D:, E:, F:, 1.3 GiB each, 32 KiB |
| 8 GiB (16644/16/63) | 1024/255/63, `--allow-unaddressable` | 15.7 MiB, FAT12 | D: to H:, 1.6 GiB each, 32 KiB; the last 160 MiB unused |

C: is rounded up to whole cylinders, so it is more than 10 MiB when the
cylinders are large. The current distribution uses 94 of C:'s clusters of
4 KiB, about 380 KB.

### C:

C: is formatted afresh on every deployment, and holds the following files
in this order:

1. `IO.SYS` and `MSDOS.SYS`, the first two directory entries. IO.SYS starts
   at cluster 2.
2. `COMMAND.COM`.
3. `CONFIG.SYS`: `FILES=20` and `BUFFERS=20`.
4. `AUTOEXEC.BAT`: `PROMPT $P$G` and `PATH C:\`, ending with:

   ```bat
   REM User configuration is on persistent storage
   IF EXIST D:\AUTOEXEC.BAT CALL D:\AUTOEXEC.BAT
   ```

5. `GRDOS.ID`, the marker (read-only): the layout version, the disk id,
   the GR-DOS version, the geometry, C:'s sectors and the installation
   time.
6. The other files of the distribution, as on the floppy images: FORMAT,
   SYS, CHKDSK, DISKCOPY, FDISK, ATTRIB, MORE, FIND, FC, DEBUG, MEM, MODE
   and TICO.

`D:\AUTOEXEC.BAT` is yours. Neither command creates or changes it. It runs
after C:'s defaults, so it can change `PATH`, `PROMPT` and the rest. CALL
returns to C:'s AUTOEXEC.BAT afterwards, which then ends, so the prompt
appears. COMMAND.COM 4.00 supports `IF EXIST` and `CALL` in batch files
(`TBATCH2.ASM`), and restores the caller's echo state when the called file
returns.

## update's safety contract

Before it writes anything, `update` checks:

- the layout record in sector 1: its magic, its SHA-256, and that the disk
  has the number of sectors the record gives (the same card, not a copy or
  another card);
- the master boot record's partition table and its signature, and every
  extended boot record in full: each must be byte for byte what the record
  describes;
- C:'s boot sector: an MS-DOS 4.00 BPB matching partition 1 and the
  geometry;
- C:\GRDOS.ID, which must carry the record's disk id.

If any check of the record or the partition tables fails, `update` stops,
and nothing can override that. If only C: is unusable, `update` also stops,
but `--recover` lets it replace C:. C: is unusable when it has no boot
sector, no GRDOS.ID or another disk's GRDOS.ID, which is what an
interrupted update leaves.

When it writes, the disk object accepts only sectors of partition 1. Any
other write is refused before it happens, so the data drives are never
opened for writing. C:'s size and the geometry come from the disk's
record, never from today's defaults, so a C: provisioned with another
`--system-size` keeps it. The order of writes is:

1. C:'s boot sector, as zeros, then a flush;
2. the FATs, the root directory and the files, then a flush;
3. the boot sector, then a flush.

An update cut off at any point leaves a C: without a boot sector, which
`update` then refuses without `--recover`.

After writing, it verifies:

- the written sectors read back identically. The kernel's cache is dropped
  first, `BLKFLSBUF`, so the reads come from the card;
- C:'s FATs agree;
- C:'s directory holds exactly the distribution's files, in order, with
  their contents and attributes. Old files do not survive;
- the record and the tables are unchanged (SHA-256 before and after).

It reports success only after all of these. An I/O error, such as a card
removed mid-write, stops it with the sector number, without retrying or
touching anything else.

`provision` writes in this order:

1. track 0 is zeroed;
2. the data drives;
3. C:;
4. the master boot record and the layout record, last.

A provision cut off part way leaves no layout record, which `update`
refuses; run `provision` again. `provision` then runs the same checks
`update` makes, so its result is one `update` will accept.

### Recovering C:

- An update that stopped part way, or a C: that DOS or a tool damaged:
  `sudo scripts/deploy-cf update --recover /dev/sdX`. This needs the
  partition tables and the record to be intact, and leaves D: onwards as
  they are.
- Tables or record damaged: `update` refuses, and the only way on is
  `provision`, which erases the card. Copy the data drives off first, for
  example with mtools: `mcopy -s -i /dev/sdX@@OFFSET ::* backup/`, with
  OFFSET the drive's first sector (`inspect` lists them) times 512.

## Geometry and BIOSes

DOS 4.00 reaches disks only through INT 13h in cylinders, heads and
sectors. The boot sector, IO.SYS's partition scan and its disk driver all
pack a 10-bit cylinder, so nothing past cylinder 1023 of the geometry the
BIOS reports is reachable. The tables and boot sectors must also use that
same geometry:

- the master boot record loads C:'s boot sector from the CHS of its
  partition entry;
- the boot sector computes CHS from the BPB's sectors per track and heads;
- IO.SYS reads each extended boot record from the CHS of the link entry.

The default geometry is the usual LBA-assisted translation: 63 sectors,
and the fewest of 16, 32, 64, 128 or 255 heads that cover the disk within
1024 cylinders. `inspect` and `provision` show it.

- **SeaBIOS (QEMU)** gives the same geometry for every test size, and the
  tests check it. Its translation rounds down where the usual one rounds
  up, so at a few sizes just above a boundary it picks fewer heads: for
  example 1024/32/63 rather than 520/64/63 for a 2080/16/63 drive. Use
  `--geometry` there.
- **XT-IDE Universal BIOS** with a CF card has not been tested on hardware
  yet. For cards up to 504 MiB, including `/dev/sdd`'s 993/16/63, it
  reports the card's own geometry, which is the default here. For larger
  cards its translation should be the LBA-assisted one, but check what the
  BIOS shows at boot and pass `--geometry` if it differs. If the geometry
  is wrong, the MBR prints "Error loading operating system" or "Missing
  operating system", or DOS cannot read D:.
- Disks over 1024 × 255 × 63 sectors (8,422,686,720 bytes) are refused,
  since part of them cannot be reached. `--allow-unaddressable` uses the
  first 8.4 GB and leaves the rest unused. Most "8 GB" CF cards, at about
  8.0 × 10⁹ bytes, fit without it.

### Drive letters

IO.SYS gives letters first to one primary DOS partition per hard disk,
then to the logical drives of each disk in turn. With the CF card as the
only fixed disk, C: is partition 1 and D:, E:, ... are the logical drives
in order, which the tests check by reading a sentinel on each drive
through its letter. With a second hard disk that has a primary DOS
partition, that partition becomes D:, and the card's logical drives move
to E: and on. `C:\AUTOEXEC.BAT` would then call `D:\AUTOEXEC.BAT` on the
other disk. GR-DOS is meant to have the card as its only fixed disk.

## What DOS 4.00 needs

Read from the MS-DOS 4.00 source, and followed by `deploy-cf`:

- **Master boot record** (`CMD/FDISK/FDBOOT.ASM`):
  - it finds the first entry with boot indicator 80h, and stops at any
    indicator other than 00h or 80h, or at a second 80h entry;
  - it reads the entry's start CHS with INT 13h and checks for 55AAh.
- **Boot sector** (`BOOT/MSBOOT.ASM`):
  - it uses BPB byte 24h, not the BIOS's DL, as the drive number, so 24h
    must be 80h;
  - it computes CHS from the BPB's geometry and hidden sectors;
  - the first two directory entries must be named `IO      SYS` and
    `MSDOS   SYS`;
  - it loads three sectors from the first data sector (cluster 2), and
    MSLOAD follows the FAT for the rest (`BIOS/MSLOAD.ASM`).
- **IO.SYS** (`BIOS/MSINIT.ASM`):
  - it takes the first entry of type 01h, 04h or 06h in the master boot
    record, or in each extended boot record;
  - it follows type 05h links by their CHS, and adds the extended boot
    record's cylinder to the logical drive's;
  - it trusts the boot sector's BPB only if its OEM name starts `MSDOS`,
    `IBM ` or `OS2 ` with a version of 3.1 or later. `deploy-cf` writes
    `MSDOS4.0`. Otherwise IO.SYS computes its own BPB from the partition
    size.
  - It always assumes 1 reserved sector, 2 FATs, 512-byte sectors and
    media F8h.
- **FAT** (`deploy-cf` uses the cluster sizes IO.SYS's own table and
  FORMAT choose):
  - FAT16 from 4,086 clusters for IO.SYS, MSLOAD and FORMAT, and from
    4,085 for the kernel, so a count of 4,085 is never used;
  - FAT16 cluster numbers from FFF8h mean end of file, so at most 65,524
    clusters;
  - 64 sectors per cluster (32 KiB) at most.
  - With the 2000 MiB cap, a drive has at most about 64,000 clusters.

## Tests

`make test-deploy-cf` (`scripts/deploy-cf-test`, with the boot test
`scripts/hd-boot-test`) uses only new, sparse image files.

- **`test-deploy-cf-512m`, `-2g`, `-4g`, `-8g`**:
  - `provision`. The geometry must be the one SeaBIOS gives the drive,
    `scripts/partition-table --chs` must agree with the BIOS geometry,
    and `fsck.fat` must find C: clean.
  - Sentinel files go on every logical drive, with a `D:\AUTOEXEC.BAT`
    that reports to COM1. Every sector outside C: is hashed: the MBR, the
    record, the extended boot records and the logical drives.
  - Boot from the hard disk in QEMU. `D:\AUTOEXEC.BAT` must run exactly
    once. Each sentinel must be read through its letter. CHKDSK on each
    logical drive must report the free space mtools does. At the prompt
    `D:\AUTOEXEC.BAT` set, a typed command must run, which shows the CALL
    returned.
  - Put a stray file on C:, then `update` with a distribution in which a
    file is renamed and another removed. Then `update` twice with the real
    one. Each time C: must hold exactly the distribution's files, and the
    hash must not change.
  - Boot again.
- **`test-deploy-cf-failures`**. `update` must refuse:
  - a blank disk, and a disk without the record;
  - a changed byte in the master boot record's table, or in an extended
    boot record's;
  - a disk of another size than the record;
  - a wrong `--confirm`;
  - a C: without GRDOS.ID, which `--recover` then reinstalls;
  - after an I/O error part way through an update, which `--recover` then
    completes.

  In each case nothing outside C: may change. The suite also checks:
  - that dry runs and `inspect` write nothing;
  - refusals for too small a disk, too small a C: for the distribution,
    more than 1024 cylinders, more than 63 sectors per track, and a
    geometry larger than the disk;
  - on hosts whose `/` is on a disk partition, refusals for the system
    disk and for a partition.

`GRDOS_DEPLOY_CF_FAIL_AFTER=N` makes the tool fail with an I/O error after
writing N sectors. It exists only to simulate a card pulled out mid-write.

Not automated:

- a mounted card: that needs root to mount, and `O_EXCL` and the
  mountinfo check cover it;
- real BIOSes other than SeaBIOS, and real cards.
