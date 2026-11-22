GR-DOS @VERSION@

GR-DOS is a fork of the MS-DOS 4.00 source that Microsoft published under
the MIT license, built on Linux with open tools.

  https://github.com/gr-dos/gr-dos

This archive holds the GR-DOS system files. The bootable floppy images are
separate downloads from the same release:

  gr-dos-@VERSION@-1440k.img   3.5" 1.44 MB disk (HD, 80 tracks of 18 sectors)
  gr-dos-@VERSION@-1200k.img   5.25" 1.2 MB disk (HD, 80 tracks of 15 sectors)
  gr-dos-@VERSION@-720k.img    3.5" 720 KB disk (DD, 80 tracks of 9 sectors)
  gr-dos-@VERSION@-360k.img    5.25" 360 KB disk (DD, 40 tracks of 9 sectors)

All four are double sided, with 512-byte sectors, and each is a complete
system disk for a machine with one or two floppy drives: leave it in A:
and use B: for programs and data. Each also installs GR-DOS on a hard disk
(see below). The larger disks carry more of the utilities in BIN below:

  360 KB   IO.SYS, MSDOS.SYS, COMMAND.COM, FORMAT, SYS, CHKDSK, DISKCOPY,
           FDISK, ATTRIB, MORE, FIND, FC, DEBUG, MEM, MODE, TICO and
           AUTOEXEC.BAT
  720 KB   those, and XCOPY, COMP, DISKCOMP, LABEL, TREE, SORT, EDLIN,
           PRINT, ASSIGN, RECOVER and KEYB, with COUNTRY.SYS and
           KEYBOARD.SYS, BACKUP, RESTORE and REPLACE
  1.2 MB,  those, and APPEND, SHARE, EXE2BIN, GRAFTABL, GRAPHICS,
  1.44 MB  GRAPHICS.PRO, NLSFUNC, JOIN and SUBST, DISPLAY.SYS with
           EGA.CPI, and PRINTER.SYS with 4201.CPI, 4208.CPI and 5202.CPI

All but the 360 KB disk also have HELP and its file GRDOS.HLP: type HELP
for the list of topics, HELP START to get started, or HELP and a command,
such as HELP XCOPY.

FASTOPEN, IFSFUNC, FILESYS, GRVER, MOVE and LCD.CPI are on no floppy:
FASTOPEN works on hard disks only, IFSFUNC needs an installable file system
driver, and FILESYS needs IFSFUNC, GRVER and MOVE are for C:\DOS and this
archive, and LCD.CPI is for the IBM PC Convertible.

COUNTRY.SYS and KEYBOARD.SYS are MS-DOS 4.00's country and keyboard
data. COUNTRY=049 in CONFIG.SYS gives the German date, time and number
formats, for example, from \COUNTRY.SYS on the boot disk (or
COUNTRY=049,,C:\DOS\COUNTRY.SYS), and KEYB GR the German keyboard;
Ctrl+Alt+F1 switches to the US keyboard and Ctrl+Alt+F2 back. There are 23
countries and 17 keyboard layouts.

DISPLAY.SYS switches the code page of an EGA or VGA screen (or a PC
Convertible's LCD), with the fonts of EGA.CPI (LCD.CPI): code pages 437,
850, 860, 863 and 865. For example, in CONFIG.SYS:

  DEVICE=C:\DOS\DISPLAY.SYS CON=(EGA,437,1)

and then:

  MODE CON CP PREPARE=((850) C:\DOS\EGA.CPI)
  MODE CON CP SELECT=850

KEYB follows the screen's code page, and CHCP, with NLSFUNC loaded,
changes DOS's and the screen's together. Without DISPLAY.SYS, use code
page 437 where the keyboard layout has it, as the screen's characters are
code page 437's.

PRINTER.SYS does the same for an IBM printer on LPT1 to LPT3: the 4201
Proprinter, whose fonts it downloads from 4201.CPI, the 4208 Proprinter
X24 and XL24 (4208.CPI) and the 5202 Quietwriter III (5202.CPI). For
example, in CONFIG.SYS:

  DEVICE=C:\DOS\PRINTER.SYS LPT1=(4201,437,1)

and then:

  MODE LPT1 CP PREPARE=((850) C:\DOS\4201.CPI)
  MODE LPT1 CP SELECT=850

Prepare a code page before selecting one: on a 4208 or 5202, PRINTER.SYS'
own escape sequence for the printer's code page, before anything is
prepared, has the code page in the wrong place. PRINT prints files in the
background, and GRAPHICS prints a graphics screen with Shift+PrtSc, with
the printer types of GRAPHICS.PRO; neither needs PRINTER.SYS.

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
  BIN\FC.EXE       compares two files
  BIN\DEBUG.COM    the debugger
  BIN\MEM.EXE      shows the memory in use
  BIN\MODE.COM     sets up the screen, serial and parallel ports
  BIN\TICO.EXE     a text editor, from tico16
  BIN\APPEND.EXE   lets programs open files in other directories
  BIN\ASSIGN.COM   sends a drive's requests to another drive
  BIN\COMP.COM     compares files, byte by byte
  BIN\DISKCOMP.COM compares two disks of the same format
  BIN\EDLIN.COM    the line editor
  BIN\EXE2BIN.EXE  converts an .EXE file to a .COM or binary file
  BIN\FASTOPEN.EXE remembers where files are on a hard disk
  BIN\GRAFTABL.COM loads the graphics characters of a code page
  BIN\GRAPHICS.COM prints the graphics screen with Print Screen
  BIN\IFSFUNC.EXE  installable file system support
  BIN\KEYB.COM     loads a keyboard layout from KEYBOARD.SYS
  BIN\LABEL.COM    sets a disk's volume label
  BIN\NLSFUNC.EXE  national language support for CHCP, from COUNTRY.SYS
  BIN\PRINT.COM    prints files in the background
  BIN\RECOVER.COM  recovers the readable part of files with bad sectors
  BIN\SHARE.EXE    file sharing and locking
  BIN\SORT.EXE     sorts its input
  BIN\TREE.COM     shows the directory tree
  BIN\XCOPY.EXE    copies files and directory trees
  BIN\JOIN.EXE     makes a drive appear as a directory of another drive
  BIN\SUBST.EXE    makes a drive letter a name for a directory
  BIN\BACKUP.COM   backs up files to floppies or another disk
  BIN\RESTORE.COM  restores files that BACKUP backed up
  BIN\FILESYS.EXE  lists, attaches and detaches IFSFUNC's drives and devices
  BIN\REPLACE.EXE  replaces files with newer copies, or adds new ones
  BIN\GRAPHICS.PRO GRAPHICS's printer profile
  BIN\COUNTRY.SYS  country information, for COUNTRY= in CONFIG.SYS
  BIN\KEYBOARD.SYS keyboard layouts, for KEYB
  BIN\DISPLAY.SYS  code page switching for the screen, for CONFIG.SYS
  BIN\EGA.CPI      EGA and VGA fonts of five code pages, for MODE
  BIN\LCD.CPI      the PC Convertible's LCD fonts, for MODE
  BIN\PRINTER.SYS  code page switching for IBM printers, for CONFIG.SYS
  BIN\4201.CPI     IBM 4201 Proprinter fonts of five code pages, for MODE
  BIN\4208.CPI     IBM 4208 Proprinter X24 and XL24 code pages, for MODE
  BIN\5202.CPI     IBM 5202 Quietwriter III code pages, for MODE
  BIN\GRVER.EXE    shows the GR-DOS release version, from the kernel
  BIN\MOVE.EXE     moves files and renames directories, as MS-DOS 6.22's
  BIN\HELP.EXE     GR-DOS's command help: HELP, or HELP and a topic
  BIN\GRDOS.HLP    HELP's topics, for every command and CONFIG.SYS
@DIST16@
  BIN\AUTOEXEC.BAT sets the prompt and PATH A:\
  BUILDINFO        the commit and the tool versions it was built with
  SHA256SUMS       SHA-256 checksums of the other files in this archive
  LOGS\make.log    the build log
  LOGS\test.log    the QEMU test log: each image booted, and the utilities

The utilities are built from the MS-DOS 4.00 source. ATTRIB.EXE, MEM.EXE,
FDISK.EXE and FC.EXE are compiled with Open Watcom C, where Microsoft's were
compiled with Microsoft C 5.1, and linked with libc16, a C runtime for DOS
programs. GRVER.EXE, MOVE.EXE and HELP.EXE are GR-DOS's own, built the same way. FIND.EXE, EXE2BIN.EXE and IFSFUNC.EXE are not EXEPACKed, as
Microsoft's were: the EXEPACK loader fails with "Packed file is corrupt"
when a program is loaded in the first 64 KB of memory, as it is on
GR-DOS. TICO.EXE and the programs listed after GRDOS.HLP are the
releases of the GitHub projects named, unchanged: the ones whose names
end in 16 in the gr-dos organization (https://github.com/gr-dos), tico16
(https://github.com/tico-edit/tico16), and SPROCKET
(https://github.com/plicease/sprocket), with SPROCKET.LIC, its license
notice. They are on no floppy but TICO.EXE. Each is under its own
project's license, named in the list above, with its text at the end of
this file.

Booting
-------

Boot an image in QEMU:

  qemu-system-i386 -drive file=gr-dos-@VERSION@-1440k.img,if=floppy,format=raw -boot a

or, for the 360 KB image:

  qemu-system-i386 -drive file=gr-dos-@VERSION@-360k.img,if=floppy,format=raw -boot a

The DOS version reported to programs is 4.00. GRVER shows GR-DOS's own
version (@VERSION@), which programs get from INT 21h AX=3347h, BX=4752h
(docs/grver.md in the source). The boot sector loads IO.SYS
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

Copying files over a serial line
--------------------------------

A hard disk or CF install has SPROCKET.EXE in C:\DOS, from
https://github.com/plicease/sprocket: it copies files, and images disks,
between this computer and another over a serial line. Connect a COM port
to the other computer with a null-modem cable (a USB serial adapter on
its side does if it has no COM port), and run sprocket for Linux or
Windows, from the same project, there. At the same speed on both ends:

  SPROCKET CLIENT COM1 38400
    with "sprocket serve --port /dev/ttyUSB0 --baud 38400 --root DIR"
    on the other computer, to browse DIR and get and put files;
  SPROCKET SERVER COM1 38400 C:\SHARE /W
    with "sprocket client --port /dev/ttyUSB0 --baud 38400" there, to
    share C:\SHARE, and let it send files to it;
  SPROCKET SERVER COM1 38400 /D
    with "sprocket image ... --list" there, to image this computer's
    disks, read-only.

The line is 8N1 with no flow control; a 4.77 MHz 8088 keeps up with 38400
baud. HELP SPROCKET has more. It is on no floppy.

Checking the downloads
----------------------

The release's SHA256SUMS covers the four images and this archive:

  sha256sum -c SHA256SUMS

and, once unpacked, this archive's own SHA256SUMS covers its files:

  cd gr-dos-@VERSION@ && sha256sum -c SHA256SUMS

@DIST16_SOURCES@
Licenses
--------

GR-DOS is an aggregation of separately licensed programs, not one
MIT-licensed work, and it relicenses none of them. GR-DOS's own work is
MIT licensed. The MS-DOS 4.00 source it is built from keeps its own MIT
license. MS-DOS is a trademark of Microsoft. GR-DOS is an independent
project, not endorsed by Microsoft or IBM. ATTRIB.EXE, MEM.EXE, FDISK.EXE,
FC.EXE, JOIN.EXE, SUBST.EXE, BACKUP.COM, RESTORE.COM, FILESYS.EXE, REPLACE.EXE, GRVER.EXE, MOVE.EXE and HELP.EXE are compiled
with Open Watcom C,
but contain no Open Watcom code: their C runtime is libc16
(https://github.com/gr-dos/libc16), under its MIT license. TICO.EXE and the other programs from GitHub
projects are each under their project's license, as named in Contents
above. A license that requires the program's source, the GNU GPL version
2 or later or version 1 or later, is met as "Corresponding source" above
says, and the program's own license text is kept as its project gives it. The licenses follow: GR-DOS's,
the MS-DOS 4.00 source's, each GitHub project's, with any further notice
and the license of any library linked into it, and libc16's.
