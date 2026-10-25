GR-DOS @VERSION@

GR-DOS is a fork of the MS-DOS 4.00 source that Microsoft published under
the MIT license, built on Linux with open tools.

  https://github.com/plicease/dos-gr-dos

This archive holds the GR-DOS system files. The bootable floppy images are
separate downloads from the same release:

  gr-dos-@VERSION@-1440k.img   3.5" 1.44 MB disk
  gr-dos-@VERSION@-1200k.img   5.25" 1.2 MB disk

Contents
--------

  README.txt      this file, with the licenses
  BIN\IO.SYS      the DOS BIOS (MSLOAD and MSBIO)
  BIN\MSDOS.SYS   the DOS kernel
  BIN\COMMAND.COM the command interpreter
  BIN\MSBOOT.BIN  the boot sector program; its last 512 bytes are the boot
                  sector on the images
  BUILDINFO       the commit and the tool versions it was built with
  SHA256SUMS      SHA-256 checksums of the other files in this archive
  LOGS\make.log   the build log
  LOGS\test.log   the QEMU boot test log of both images

Booting
-------

Boot an image in QEMU:

  qemu-system-i386 -drive file=gr-dos-@VERSION@-1440k.img,if=floppy,format=raw -boot a

The DOS version reported to programs is 4.00. The boot sector loads IO.SYS
and MSDOS.SYS only from the first two root directory entries, stored
contiguously, so copy the images rather than these files to make a boot
disk.

Checking the downloads
----------------------

The release's SHA256SUMS covers the two images and this archive:

  sha256sum -c SHA256SUMS

and, once unpacked, this archive's own SHA256SUMS covers its files:

  cd gr-dos-@VERSION@ && sha256sum -c SHA256SUMS

Licenses
--------

GR-DOS's own work is MIT licensed. The MS-DOS 4.00 source it is built from
keeps its own MIT license. MS-DOS is a trademark of Microsoft. GR-DOS is an
independent project, not endorsed by Microsoft or IBM. Both licenses
follow.
