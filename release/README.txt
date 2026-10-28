GR-DOS @VERSION@

GR-DOS is a fork of the MS-DOS 4.00 source that Microsoft published under
the MIT license, built on Linux with open tools.

  https://github.com/plicease/dos-gr-dos

This archive holds the GR-DOS system files. The bootable floppy images are
separate downloads from the same release:

  gr-dos-@VERSION@-1440k.img   3.5" 1.44 MB disk (HD, 80 tracks of 18 sectors)
  gr-dos-@VERSION@-1200k.img   5.25" 1.2 MB disk (HD, 80 tracks of 15 sectors)
  gr-dos-@VERSION@-720k.img    3.5" 720 KB disk (DD, 80 tracks of 9 sectors)
  gr-dos-@VERSION@-360k.img    5.25" 360 KB disk (DD, 40 tracks of 9 sectors)

All four are double sided, with 512-byte sectors, and hold the same files,
the files in BIN below except MSBOOT.BIN, so any of them is a complete system
disk for a machine with one or two floppy drives, and installs GR-DOS on a
hard disk (see below).

Contents
--------

  README.txt       this file, with the licenses
  BIN\IO.SYS       the DOS BIOS (MSLOAD and MSBIO)
  BIN\MSDOS.SYS    the DOS kernel
  BIN\COMMAND.COM  the command interpreter
  BIN\MSBOOT.BIN   the boot sector program; its last 512 bytes are the boot
                   sector on the images
  BIN\FORMAT.COM   formats a disk, /S also makes it a system disk
  BIN\SYS.COM      copies IO.SYS and MSDOS.SYS to a formatted disk
  BIN\CHKDSK.COM   checks a disk
  BIN\DISKCOPY.COM copies a whole disk to another of the same format
  BIN\FDISK.EXE    creates and deletes hard disk partitions
  BIN\ATTRIB.EXE   shows or sets the read-only and archive attributes
  BIN\MORE.COM     shows its input a screen at a time
  BIN\FIND.EXE     finds lines with a string in files
  BIN\DEBUG.COM    the debugger
  BIN\MEM.EXE      shows the memory in use
  BIN\MODE.COM     sets up the screen, serial and parallel ports
  BIN\TICO.EXE     a text editor, from tico16 (it replaces EDLIN)
  BIN\AUTOEXEC.BAT sets the prompt and PATH A:\
  BUILDINFO        the commit and the tool versions it was built with
  SHA256SUMS       SHA-256 checksums of the other files in this archive
  LOGS\make.log    the build log
  LOGS\test.log    the QEMU test log: each image booted, and the utilities

The utilities are built from the MS-DOS 4.00 source. ATTRIB.EXE, MEM.EXE
and FDISK.EXE are compiled with Open Watcom C, where Microsoft's were
compiled with Microsoft C 5.1, and linked with libc16, a C runtime for DOS
programs. FIND.EXE is not EXEPACKed, as Microsoft's was: the EXEPACK
loader fails with "Packed file is corrupt" when it is loaded in the first
64 KB of memory, as it is on GR-DOS. TICO.EXE is tico16's release v0.02,
unchanged (https://github.com/tico-edit/tico16).

Booting
-------

Boot an image in QEMU:

  qemu-system-i386 -drive file=gr-dos-@VERSION@-1440k.img,if=floppy,format=raw -boot a

or, for the 360 KB image:

  qemu-system-i386 -drive file=gr-dos-@VERSION@-360k.img,if=floppy,format=raw -boot a

The DOS version reported to programs is 4.00. The boot sector loads IO.SYS
and MSDOS.SYS only from the first two root directory entries, stored
contiguously, so copy the images rather than these files to make a boot
disk, or use FORMAT /S or SYS on GR-DOS.

Installing on a hard disk
-------------------------

Boot from a GR-DOS floppy and run FDISK. Choose 1, Create DOS Partition,
then 1, Create Primary DOS Partition, and answer Y to use the whole disk
and make it active; FDISK then restarts the machine. Boot from the floppy
again and run:

  FORMAT C:
  SYS C:
  COPY COMMAND.COM C:\

Remove the floppy and restart, and the machine boots GR-DOS from the hard
disk. FDISK and FORMAT erase what is on the disk. Like MS-DOS 4.00, GR-DOS
uses at most 1024 cylinders of a disk, as the BIOS reports them, and
partitions of up to 2 GB; it has no FAT32.

Writing a floppy disk
---------------------

Each image is the disk's sectors in order, nothing more, so writing it to a
disk of the same format makes a GR-DOS boot disk. Use a disk of the right
density: 1.44 MB and 1.2 MB disks are high density (HD), 720 KB and 360 KB
ones double density (DD). Writing overwrites everything on the disk, and
the disk must already be formatted (low-level), as new disks usually are.

On Linux, with a USB floppy drive (find its device with lsblk; here
/dev/sdX), which takes 1.44 MB and usually 720 KB disks:

  sudo dd if=gr-dos-@VERSION@-1440k.img of=/dev/sdX bs=512 conv=fsync

With a drive on the floppy controller, the device names the format:

  sudo dd if=gr-dos-@VERSION@-720k.img of=/dev/fd0u720 bs=512 conv=fsync

where /dev/fd0u1440 and /dev/fd0u720 are the 3.5" formats, /dev/fd0h1200
the 1.2 MB 5.25" one, and /dev/fd0h360 a 360 KB disk in a 1.2 MB drive
(/dev/fd0d360 in a 360 KB drive). fdformat formats a disk the same way, for
example fdformat /dev/fd0u720. A 360 KB disk written in a 1.2 MB drive may
not read reliably in a 360 KB drive, whose tracks are wider; write it in the
kind of drive that will read it if you can.

On Windows, write the image with a raw disk writer such as RawWrite for
Windows; on DOS, with RAWRITE.

On a running GR-DOS system, FORMAT B: /S makes a new boot disk in drive B:
(FORMAT B: /F:720 or /F:360 for a double-density disk in a high-density
drive), and DISKCOPY A: B: copies the system disk to a disk of the same
format.

Checking the downloads
----------------------

The release's SHA256SUMS covers the four images and this archive:

  sha256sum -c SHA256SUMS

and, once unpacked, this archive's own SHA256SUMS covers its files:

  cd gr-dos-@VERSION@ && sha256sum -c SHA256SUMS

Licenses
--------

GR-DOS's own work is MIT licensed. The MS-DOS 4.00 source it is built from
keeps its own MIT license. MS-DOS is a trademark of Microsoft. GR-DOS is an
independent project, not endorsed by Microsoft or IBM. TICO.EXE is tico16's,
under its MIT license. ATTRIB.EXE, MEM.EXE and FDISK.EXE are compiled with
Open Watcom C, but contain no Open Watcom code: their C runtime is libc16
(https://github.com/gr-dos/libc16), under its MIT license. The four MIT
licenses follow.
