# Code page switching (issue #24)

GR-DOS builds MS-DOS 4.00's code page switching for the screen from the
published source, byte for byte as Microsoft's build makes it (`make
check`):

- **`DISPLAY.SYS`**, the CON device driver that `CONFIG.SYS` loads. It
  keeps the fonts of the code pages MODE prepares, and loads the selected
  one into an EGA, VGA or PC Convertible LCD;
- **`EGA.CPI`**, the fonts for EGA and VGA: code pages 437, 850, 860, 863
  and 865, each in 8×16, 8×14 and 8×8;
- **`LCD.CPI`**, the same five code pages in 8×8, for the IBM PC
  Convertible's LCD.

With them, MODE's `CP` commands, CHCP, KEYB and NLSFUNC, all built since
issues #4 and #17, switch the screen's characters as on MS-DOS 4.00. The
country and keyboard data, `COUNTRY.SYS` and `KEYBOARD.SYS`, are issue
#23's ([country-keyboard.md](country-keyboard.md)).

## What the source has

| Source | What it is | GR-DOS |
|---|---|---|
| `DEV/DISPLAY` | DISPLAY.SYS: `DISPLAY.ASM` (the driver, with the `.INC` files for INT 10h, INT 2Fh, the generic IOCTL calls and the font file parser), `INIT.ASM` and `PARSER.ASM` (the `CON=` parameters and the display detection) | built: `DISPLAY.SYS` |
| `DEV/DISPLAY/EGA` | `CPI-HEAD.ASM`, the file header, and `437-CPI.ASM` to `865-CPI.ASM`, each including its three fonts (`437-8X16.ASM` and so on), with `COPYRIGH.ASM` | built: `EGA.CPI` |
| `DEV/DISPLAY/LCD` | `FONT-R3.ASM`, the header, and `437-CPI.ASM` to `865-CPI.ASM`, an 8×8 font each | built: `LCD.CPI` |
| `CMD/MODE` | `MODE CON CP PREPARE`, `SELECT`, `REFRESH` and `/STATUS` (`MODECP.ASM`) | built since issue #4 |
| `CMD/COMMAND` | CHCP | in COMMAND.COM |
| `CMD/NLSFUNC`, `CMD/KEYB` | CHCP's code page change for the devices, and KEYB's tables by code page | built since issue #17 |
| `CMD/GRAFTABL` | the upper 128 characters for CGA graphics modes (INT 1Fh), in code pages 437, 850, 860, 863 and 865 | built since issue #17 |
| `DEV/PRINTER` | PRINTER.SYS, `4201.CPI`, `4208.CPI` and `5202.CPI`, for IBM printers | built since issue #25: [printer.md](printer.md) |
| `DEV/ANSI` | ANSI.SYS, which asks DISPLAY.SYS before `MODE CON LINES=43` or `50` | not built: issue #26 |

Everything GR-DOS uses here is in Microsoft's MIT-licensed `v4.0` tree:
the fonts are source too, `DB` lines written by IBM's MULTIFON tool. No
retail MS-DOS file, and no `.CPI` file from anywhere else, is used or
distributed. Nothing is missing for the screen. `DEV/DISPLAY/INT10COM.INC`
is one of the files whose CP437 bytes the upstream conversion damaged; the
tree has the restoration of hharte `1f50610`
([provenance.md](provenance.md)), and `make check`'s match with
Microsoft's build of that tree shows the build is right, not that the
restored comments are.

Printer code pages, PRINTER.SYS and its `.CPI` files, are issue #25's
([printer.md](printer.md)). Without PRINTER.SYS, `MODE LPT1 CP ...` says
"Code page operation not supported on this device", and CHCP changes no
printer.

## Building

- **`DISPLAY.SYS`**: `DISPLAY.OBJ`, `INIT.OBJ` and `PARSER.OBJ`, linked in
  `DISPLAY.LNK`'s order and converted with EXE2BIN. Its segment references
  (`SEG CODE`) are relocations, which EXE2BIN asks for a base segment for;
  `DEV/DISPLAY/MAKEFILE` answers 0 from `ZERO.DAT`, and `scripts/exe2bin`
  is given `--base 0`. Its messages are `DISPLAY.SKL`'s, built with
  `scripts/buildmsg` as every utility's.
- **`EGA.CPI` and `LCD.CPI`**: linked from `EGA.LNK` and `LCD.LNK` and
  converted with EXE2BIN; the header module comes first, and each code
  page's entry points to the next.

`CPS-FUNC.INC` uses `TYPE FTBLK` before `F-PARSER.INC` defines the `FTBLK`
structure. In pass one MASM 5 takes `TYPE` of a symbol it has not seen as
the constant 0, so `ADD DI,TYPE FTBLK` is the three-byte, sign-extended
form. JWasm took the symbol for a near label, and the instruction for a
forward reference, and wrote the four-byte form, which moved everything
after it. JWasm patch `0022-Zj-type-of-forward-reference`
([m2-jwasm.md](m2-jwasm.md#jwasm-patches)) makes `-Zj` do as MASM 5 does. No
source file is changed.

`make check` compares `DISPLAY.SYS`, `EGA.CPI`, `LCD.CPI` and DISPLAY's
message files with the M1 reference build.

### 8086

DISPLAY.SYS is 8086 code: no source file selects a later processor
(`.186` or `.286`), and both MASM 5 and JWasm refuse later instructions
without one. It reads and writes EGA and VGA registers through the BIOS
(INT 10h) and the ports the EGA defines, and runs on whatever processor
the machine has.

## Where they are

| | `DISPLAY.SYS` | `EGA.CPI` | `LCD.CPI` |
|---|:-:|:-:|:-:|
| 360 KB, 720 KB floppies | | | |
| 1.2 MB, 1.44 MB floppies | ✓ | ✓ | |
| CF install (`C:\DOS`), release ZIP (`BIN`) | ✓ | ✓ | ✓ |

The 360 KB floppy's files are frozen (issue #17). DISPLAY.SYS and EGA.CPI
are 64 KB on a floppy, which the 1.2 MB and 1.44 MB disks have room for
(578 KB and 821 KB are left): those are the drives of the AT-class
machines that have an EGA or VGA. The 720 KB disk keeps its room for
data: the 8088 machines that boot from it mostly have a CGA or MDA, which
DISPLAY.SYS cannot change the characters of. LCD.CPI is only for the PC
Convertible, so it is on C: and in the ZIP alone. On a floppy the files
are in the root.

## How it works

From the source (`DEV/DISPLAY`, `CMD/MODE/MODECP.ASM`):

- **DISPLAY.SYS** is a character device named `CON`, loaded after the
  BIOS's CON, so DOS uses it for CON. It hooks INT 10h, and loads the
  selected code page's font after every video mode set (INT 10h AH=00h),
  in the size the mode uses, so a program that sets the mode keeps the
  characters; INT 2Fh (AH=ADh), through which KEYB asks for CON's code
  page and is told when it changes (AX=AD81h); and, for graphics modes,
  INT 1Fh and INT 43h (and INT 44h on the LCD), unless GRAFTABL or another
  program already has INT 1Fh.
- **The hardware code page** (437 in `CON=(EGA,437,...)`) is the one the
  adapter's ROM has. Selecting it gives back the ROM's font: it is never
  loaded from a `.CPI` file.
- **MODE CON CP PREPARE=((cp,...) file)** opens the font file, starts a
  prepare (generic IOCTL 440Ch, CON category 03h, function 4Ch), writes the
  whole file to CON with IOCTL write (function 4403h), and ends it
  (function 4Dh). DISPLAY.SYS picks out the code pages asked for, in the
  fonts its display uses, from the entries for its type (`EGA` or `LCD`).
- **SELECT=cp** is function 4Ah. **REFRESH** is a prepare with no file
  (4Ch, then 4Dh), on which DISPLAY.SYS loads the active code page's font
  again from its copy, after a program has changed the characters.
  **/STATUS** asks for the active code page (6Ah) and the prepared ones
  (6Bh).
- **CHCP cp**, with NLSFUNC loaded, reads the country's tables for `cp`
  from COUNTRY.SYS, then selects `cp` on every device that has code page
  switching (CON, here); it fails ("Invalid code page") if COUNTRY.SYS has
  no data for that code page for the current country.
- **KEYB** asks CON for its code page when it loads, and DISPLAY.SYS tells
  it when another is selected; KEYB then uses its table for that code page
  ("Current keyboard does not support this code page" if it has none).

### Displays

`CON=(type,...)` names the display. DOS 4.00 has no `VGA` type: a VGA is
an `EGA`.

| Type | Display | Fonts | Code pages it can prepare |
|---|---|---|---|
| `EGA` | EGA or VGA. A VGA's BIOS reports its fonts (INT 10h AH=1Bh). On an EGA, whose BIOS cannot, DISPLAY.SYS reads the monitor from its switches (AH=12h) and keeps only the fonts it can use: 8×8 for a 5153 colour display, 8×14 and 8×8 for a 5154 enhanced colour display or a 5151 monochrome display | those the display uses of 8×16, 8×14 and 8×8, from `EGA.CPI` | any of `EGA.CPI`'s |
| `LCD` | the IBM PC Convertible's LCD | 8×8 from `LCD.CPI` | any of `LCD.CPI`'s |
| `CGA`, `MONO` | CGA or MDA, which cannot load characters | none | none: accepted, so that one `CONFIG.SYS` works on any display, but MODE's PREPARE fails |
| none (`CON=(,437,1)`) | found by DISPLAY.SYS: a VGA (INT 10h AH=1Bh) or EGA (AH=12h) is `EGA`, a Convertible's LCD (INT 15h model F9h) is `LCD`; on anything else DISPLAY.SYS is not loaded, silently | | |

GRAFTABL is for the CGA's graphics modes, where DISPLAY.SYS does nothing:
it loads the upper 128 characters of one of the five code pages for INT
1Fh. On an EGA or VGA with DISPLAY.SYS, it is not needed.

## Using them

### CONFIG.SYS

```
DEVICE=C:\DOS\DISPLAY.SYS CON=(EGA,437,1)
DEVICE=C:\DOS\DISPLAY.SYS CON=(EGA,437,2)
DEVICE=C:\DOS\DISPLAY.SYS CON=(EGA,437,(2,1))
DEVICE=C:\DOS\DISPLAY.SYS CON=(,437,1)
DEVICE=C:\DOS\DISPLAY.SYS CON=(LCD,437,1)
```

The syntax is `DEVICE=[d:][path]DISPLAY.SYS CON[:]=(type[,[hwcp][,n|(n,m)]])`:

- `type`: `EGA`, `LCD`, `CGA` or `MONO`, or nothing for DISPLAY.SYS to
  find the display (above);
- `hwcp`: the hardware code page, normally 437; only one;
- `n`: how many code pages MODE can prepare, up to 12; `m`: how many font
  sizes to keep of each (by default, all the display uses: 3 on a VGA).

Every prepared code page takes memory, all the time, for each of its fonts:
DISPLAY.SYS keeps 8.4 KB, and each code page adds 4.0 KB for its 8×16
font, 3.5 KB for 8×14 and 2.0 KB for 8×8. Measured with MEM in QEMU, on
its VGA:

| `CON=` | Memory DISPLAY.SYS takes |
|---|---:|
| `(EGA,437,(1,1))` | 12,528 bytes |
| `(EGA,437,1)` | 18,176 bytes |
| `(EGA,437,(2,2))` | 23,808 bytes |
| `(EGA,437,2)` | 27,920 bytes |

On an error DISPLAY.SYS is not loaded, and says so at boot:

| Line | Message |
|---|---|
| an unknown type, `CON=(XYZ,437,1)` | `CON code page driver cannot be initialized` |
| no parameters, a device other than `CON`, two hardware code pages, a missing parenthesis | `Invalid syntax on DISPLAY.SYS code page driver` |

The first message names `CON`, not the type, as Microsoft's build does.

**On a CF install**, `scripts/deploy-cf` writes `C:\CONFIG.SYS` again at
every update ([deploy-cf.md](deploy-cf.md)), so a `DEVICE=` line added to
it is lost at the next update (issue #48).

### MODE and CHCP

```
MODE CON CP PREPARE=((850) C:\DOS\EGA.CPI)
MODE CON CP PREPARE=((850,865) C:\DOS\EGA.CPI)
MODE CON CP SELECT=850
MODE CON CP REFRESH
MODE CON CP /STATUS
```

`CODEPAGE` may be `CP`, `PREPARE` `PREP`, `SELECT` `SEL`, `REFRESH` `REF`
and `/STATUS` `/STA`. Only prepared code pages, and the hardware one, can
be selected. MODE's messages, from `CMD/MODE/MODE.SKL`:

| Case | Message |
|---|---|
| no DISPLAY.SYS | `Code page operation not supported on this device` (SELECT: `Device error during select`) |
| SELECT of a code page not prepared | `Code page not prepared` |
| a code page the file does not have, or a file with no fonts for the display (`LCD.CPI` for an `EGA`, any file for a `CGA`) | `Font file contents invalid`, then `Device error during prepare` |
| the file is missing | `Failure to access code page font file` |
| KEYB's layout has no table for the code page selected | `Current keyboard does not support this code page`; CON changes, KEYB keeps its table |

With NLSFUNC loaded, CHCP changes DOS's code page (the tables of
COUNTRY.SYS) and CON's together, so a later CHCP is all that is needed:

```
NLSFUNC C:\DOS\COUNTRY.SYS
CHCP 850
```

### A German setup

On a CF install, with `C:\CONFIG.SYS`:

```
COUNTRY=049,850,C:\DOS\COUNTRY.SYS
DEVICE=C:\DOS\DISPLAY.SYS CON=(EGA,437,1)
INSTALL=C:\DOS\NLSFUNC.EXE C:\DOS\COUNTRY.SYS
```

and in `D:\AUTOEXEC.BAT`:

```
MODE CON CP PREPARE=((850) C:\DOS\EGA.CPI)
MODE CON CP SELECT=850
KEYB GR
```

DOS's code page is 850 from boot, and the screen's and the keyboard's
after MODE: KEYB GR finds CON in 850 and uses its 850 table, so the dead
acute accent and a space give ´ (EFh), and Shift+3 gives § as F5h. `CHCP
437` then gives back the VGA's own font, and KEYB its 437 table; `CHCP
850` 850 again.

On a 1.2 MB or 1.44 MB floppy, the same with `A:\` for `C:\DOS\`:
DISPLAY.SYS, EGA.CPI, COUNTRY.SYS, KEYBOARD.SYS, NLSFUNC and KEYB are all
in its root. Put `CONFIG.SYS` on the floppy itself.

## Tests

- **`make test-codepage`** (`tests/codepage`) boots a 1.44 MB image once
  for each `tests/codepage/NAME/expect`, whose `CONFIG.SYS` is that
  directory's `config.sys`, with DISPLAY.SYS, both fonts, MODE, KEYB,
  NLSFUNC and their data. The scenarios are:
  - no DISPLAY.SYS (`none`);
  - `CON=(EGA,437,2)` (`ega`);
  - a German setup, `COUNTRY=049,850`, DISPLAY.SYS and NLSFUNC from
    `INSTALL=` (`049-850`).

  `tests/codepage/codepage.bat` prepares 850 and 865, selects 850, loads
  KEYB GR, changes the code page with CHCP 437 and 850, sets the video mode
  with `MODE CO80`, and then makes each of MODE's errors.
  `tests/codepage/cpinfo.asm`, built with Open Watcom like the smoke
  test's program, prints the code page CON reports (generic IOCTL 440Ch,
  function 6Ah) and characters 9Bh and D5h of the font in the display's
  memory, plane 2. These are o with a stroke and the dotless i in 850, so
  the test sees the font itself change, and compares it with EGA.CPI's
  source.
- **`make test-codepage-screen`** (`tests/codepage/screen`) reads the
  screen (`scripts/disk-test`): DISPLAY.SYS' messages for five bad
  `DEVICE=` lines at boot, then a sixth with no type, which finds QEMU's
  VGA; and KEYB GR typed in code page 850, then 437 after `MODE CON CP
  SELECT=437`: Shift+3, the dead acute accent and a space, and the dead
  grave accent and Shift+A. In 437, which has no À, KEYB beeps and gives
  the accent and A.
- **`make test-floppy-1200`** and **`-1440`** check that the disks have
  DISPLAY.SYS and EGA.CPI, and the 360 KB and 720 KB tests that theirs are
  unchanged.

The expected output is what GR-DOS does, which is MS-DOS 4.00's: these are
Microsoft's programs and data, byte for byte. Each recorded screen and line
was checked against the source: the fonts against `EGA/850-8X16.ASM` and
`865-8X16.ASM`, the keys against `DEV/KEYBOARD/KDFGE.ASM`, the messages
against `DISPLAY.SKL` and `MODE.SKL`.

### Limits found

- **Tested on QEMU's VGA only.** An EGA, with its 8×14 fonts and its
  monitor switches, and the PC Convertible's LCD with LCD.CPI are not
  tested in emulation: QEMU has neither. 86Box has both, and an 8088 or a
  V20 to run them on, and a real EGA machine is the test that matters
  (issue #7 tracks 8086-class hardware tests).
- **Code page 437 is the VGA BIOS's font.** It is the hardware code page,
  so DISPLAY.SYS never loads EGA.CPI's 437, which differs from QEMU's ROM
  font in a few characters (the cent sign is one). On an IBM EGA or VGA
  the ROM's font is IBM's.
- **No ANSI.SYS** (issue #26): `MODE CON LINES=43` and `50`, which need
  ANSI.SYS, are not available, so DISPLAY.SYS' check that an 8×8 font is
  prepared for them is not tested.
- **A code page EGA.CPI does not have** (999, say) is "Font file contents
  invalid", as for a file with no fonts for the display: DISPLAY.SYS
  reports both the same way, and MODE has no other message for them.
- **A CON=(CGA) or CON=(MONO) line loads DISPLAY.SYS**, resident,
  although it can prepare nothing. Leave the type out (`CON=(,437,1)`) to
  have DISPLAY.SYS load only where it is of use.
- **Double-byte code pages** (932 to 938, COUNTRY.SYS's Asian countries)
  have no fonts: DISPLAY.SYS and EGA.CPI are for the single-byte ones.
