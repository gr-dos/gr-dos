# Printers and graphics printing (issue #25)

GR-DOS builds MS-DOS 4.00's printer support from the published source.
PRINTER.SYS and 5202.CPI are byte for byte as Microsoft's build makes them
(`make check`), and 4201.CPI and 4208.CPI are copied as the source has them:

- **`PRINTER.SYS`** is the driver for LPT1 to LPT3 (and PRN) that
  `CONFIG.SYS` loads. It switches the code page of an IBM printer: it sends
  the printer a font, or the escape sequence that selects one;
- **`4201.CPI`** has fonts for the IBM 4201 Proprinter, to download:
  code pages 437, 850, 860, 863 and 865;
- **`4208.CPI`** has escape sequences for the IBM 4208 Proprinter X24 and
  XL24, whose code pages are in the printer;
- **`5202.CPI`** has escape sequences for the IBM 5202 Quietwriter III,
  whose code pages are in its font cartridges.

PRINT (the background print queue), GRAPHICS (printing graphics screens
with Print Screen) with its printer profile `GRAPHICS.PRO`, and MODE's
`LPTn` commands have been built since issues #4 and #17
([m5-utilities.md](m5-utilities.md)). The display side of code page
switching, DISPLAY.SYS, is issue #24's ([codepage.md](codepage.md)).

## What the source has

| Source | What it is | GR-DOS |
|---|---|---|
| `DEV/PRINTER` | PRINTER.SYS: `CPSPM10.ASM` (the driver and its printer descriptions), `CPSFONT3.ASM` (font file parsing and downloads), `PRTINT2F.ASM` (INT 2Fh), `CPSPI07.ASM` (initialization) and `PARSER.ASM` (the `LPTn=` parameters), linked by `PRINTER.LNK` | built: `PRINTER.SYS` |
| `DEV/PRINTER/5202` | `5202.ASM`, the font file as source | built: `5202.CPI` |
| `DEV/PRINTER/4201`, `4208` | `4201.CPI` and `4208.CPI` as binary files, each with `4201.INC` or `4208.INC`, the same bytes as `DB` lines; their makefiles (`4201.MAK`) only check that the file is there, and `CPY.BAT` copies it | copied: `4201.CPI`, `4208.CPI` |
| `DEV/PRINTER` | `CPSPI.ASM`, `CPSFONT.ASM`, `PARSE4E.ASM` and `PTRMSG.ASM`, which neither the makefile nor `PRINTER.LNK` uses | not used |
| `CMD/PRINT` | PRINT, the background print queue | built since issue #17 |
| `CMD/GRAPHICS` | GRAPHICS, the Print Screen (INT 5) handler for graphics modes, and `GRAPHICS.PRO`, the printer profile | built since issue #17 |
| `CMD/MODE` | `MODE LPTn` (columns, lines per inch, retry), `MODE LPTn=COMm`, and `MODE LPTn CP ...` for PRINTER.SYS (`MODECP.ASM`) | built since issue #4 |

Everything GR-DOS uses here is in Microsoft's MIT-licensed `v4.0` tree.
The build copies 4201.CPI and 4208.CPI as they are in the source tree.
Their `.INC` files hold the same bytes (checked when this was written), but
no makefile assembles them, and the source has no other form of the fonts.
No retail MS-DOS file, and no `.CPI` file from anywhere else, is used or
distributed. Nothing PRINT, GRAPHICS or PRINTER.SYS needs is missing from
the published source, and nothing needed `libc16`: all of it is assembly.

## Building

- **`PRINTER.SYS`**: `CPSPM10`, `CPSFONT3`, `PRTINT2F`, `CPSPI07` and
  `PARSER`, linked in `PRINTER.LNK`'s order and converted with EXE2BIN
  with base segment 0 (`ZERO.DAT`), as for DISPLAY.SYS. Its messages are
  `PRINTER.SKL`'s, built with `scripts/buildmsg`.
- **`5202.CPI`**: `5202.ASM`, linked and converted with EXE2BIN.
- **`4201.CPI` and `4208.CPI`** are copied from the prepared tree, which
  leaves `.CPI` files unchanged (`scripts/prepare-dos-tree`).

The modules have a variable named `INVOKE`, which is a JWasm keyword but
not MASM 5's. `CPSPEQU.INC`, which every module includes first, disables
the keyword for JWasm (`OPTION NOKEYWORD:<INVOKE>` under `IFDEF
__JWASM__`), as KEYBOARD.SYS' tables do for theirs. MASM ignores it.

`make check` compares `PRINTER.SYS`, `5202.CPI` and PRINTER's message
files with the M1 reference build.

### 8086

PRINTER.SYS, PRINT and GRAPHICS are 8086 code: no source file selects a
later processor, and both MASM 5 and JWasm refuse later instructions
without one. They print through the BIOS (INT 17h), so they work with any
parallel port the BIOS knows.

## Where they are

| | `PRINTER.SYS` | `4201.CPI` | `4208.CPI` | `5202.CPI` | `PRINT.COM` | `GRAPHICS.COM`, `GRAPHICS.PRO` |
|---|:-:|:-:|:-:|:-:|:-:|:-:|
| 360 KB floppy | | | | | | |
| 720 KB floppy | | | | | ✓ | |
| 1.2 MB, 1.44 MB floppies | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| CF install (`C:\DOS`), release ZIP (`BIN`) | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |

The 360 KB floppy's files are frozen (issue #17). The 720 KB disk has PRINT,
which is useful on any printer; it keeps the rest of its room for data.
PRINTER.SYS and the three fonts take 26 KB, and are on the 1.2 MB and
1.44 MB disks next to DISPLAY.SYS and EGA.CPI, the other half of code page
switching: 551 KB and 795 KB are left. On a floppy the files are in the
root.

## How it works

From the source (`DEV/PRINTER`, `CMD/MODE/MODECP.ASM`):

- **PRINTER.SYS** is a character device for each of `LPT1` to `LPT3` (and
  `PRN`, which is LPT1) that it is given. It passes data through to the
  BIOS's printer driver, and takes the generic IOCTL calls (440Ch,
  category 05h) for code pages.
- **Its printer types** are in its own table (`CPSPM10.ASM`): `4201`,
  `4208` and `5202`; any other type is accepted, but the device gets no
  code pages. A **4201** downloads fonts: PRINTER.SYS keeps each prepared
  code page's font (3,392 bytes) and sends it to the printer when it is
  selected. A **4208** or **5202** only selects: each code page is an
  escape sequence, and a slot is a cartridge (5202) or a code page the
  printer has (4208).
- **The hardware code page** (437 in `LPT1=(4201,437,1)`) is the
  printer's own. On a 4201, selecting it sends `ESC I 0` `ESC 6` (4201.CPI's
  first sequence); a 4208 or 5202 has its own sequence for each
  (below).
- **MODE LPT1 CP PREPARE=((cp,...) file)** writes the font file to the
  device, as for CON. PRINTER.SYS keeps what it needs from the entries for
  its printer type, and sends nothing to the printer.
- **SELECT=cp** sends the printer what selects `cp`. On a 4201, for a
  downloaded code page, that is the font, then `ESC I 4` `ESC 6`, which
  selects the downloaded characters; the font is not sent again while the
  printer has it (until **REFRESH**, which sends it again).
- **CHCP cp**, with NLSFUNC loaded, selects `cp` on every character
  device in DOS's chain: CON with DISPLAY.SYS, and each LPTn with
  PRINTER.SYS. It fails for a printer that PRINT is printing on. (This is
  from NLSFUNC's source; it is not tested.)
- **PRINT** prints its queue in the background, a little at a time, when
  DOS is idle (INT 28h, as at the prompt) or on the timer when DOS is not
  busy. While a file is being printed, another program's output to the
  same printer fails with `Not ready writing device LPT1` (seen while
  writing the tests).
- **GRAPHICS** replaces Print Screen (INT 5, Shift+PrtSc). In a graphics
  mode it prints the screen with `GRAPHICS.PRO`'s escape sequences for the
  printer type it is given, `GRAPHICS` (the default) for IBM's black and
  white dot matrix printers. In a text mode, on a black and white printer
  it leaves the screen to the BIOS's own Print Screen.

### Printers

| Type | Printer | Code pages | `.CPI` |
|---|---|---|---|
| `4201` | IBM 4201 Proprinter (and compatible 9-pin printers) | 437 in the printer; 850, 860, 863 and 865 downloaded | `4201.CPI` |
| `4208` | IBM 4208 Proprinter X24 and XL24 | the printer's own: 4208.CPI has 437, 850, 851, 853, 855, 862, 863 and 864 | `4208.CPI` |
| `5202` | IBM 5202 Quietwriter III | 437 and 850, 860, 863, 865 in font cartridges | `5202.CPI` |

GRAPHICS.PRO's printer types (`GRAPHICS type`):

| Type | Printers (from GRAPHICS.PRO) |
|---|---|
| `GRAPHICS` (default), `THERMAL` | IBM 5152, 4201, 4202 and 5201-002 (8"), 5202, 3812, 4207, 4208, 5140 |
| `GRAPHICSWIDE` | IBM 4202 and 5201-002 at 13.5" |
| `COLOR1` | IBM 5182 Color Printer, black ribbon |
| `COLOR4` | IBM 5182, RGB ribbon |
| `COLOR8` | IBM 5182, CMY ribbon |

## Using them

### CONFIG.SYS

```
DEVICE=C:\DOS\PRINTER.SYS LPT1=(4201,437,1)
DEVICE=C:\DOS\PRINTER.SYS LPT1=(4201,437,2)
DEVICE=C:\DOS\PRINTER.SYS LPT1=(5202,437,1)
DEVICE=C:\DOS\PRINTER.SYS LPT1=(4201,437,1) LPT2=(4208,437,1)
```

The syntax is `DEVICE=[d:][path]PRINTER.SYS LPTn[:]=(type[,[hwcp][,n]])
[...]`, with `PRN` for `LPT1`:

- `type`: `4201`, `4208` or `5202`;
- `hwcp`: the printer's own code page, normally 437, or a list of them,
  such as `(437,850)`;
- `n`: how many code pages MODE can prepare.

The memory PRINTER.SYS takes, measured with MEM in QEMU:

| `DEVICE=PRINTER.SYS` | Memory |
|---|---:|
| `LPT1=(4201,437,1)` | 15,168 bytes |
| `LPT1=(4201,437,2)`, or `LPT1=(4201,437,1) LPT2=(4201,437,1)` | 18,560 bytes |
| `LPT1=(4208,437,1)` or `LPT1=(5202,437,1)` | 11,840 bytes |
| `LPT1=(9999,437,1)`, an unknown type | 11,776 bytes, and LPT1 has no code pages |

On an error PRINTER.SYS says so at boot, from `PRINTER.SKL`: `LPT1 code
page driver cannot be initialized` (with the device's name), or `Invalid
syntax on PRINTER.SYS code page driver`. A line it cannot parse, such as
`DEVICE=PRINTER.SYS XYZ`, loads nothing. These boot messages are not
tested.

**On a CF install**, `scripts/deploy-cf` writes `C:\CONFIG.SYS` again at
every update ([deploy-cf.md](deploy-cf.md)), so put the `DEVICE=` line in
`D:\CONFIG.SYS`, which `C:\CONFIG.SYS` includes with
`INCLUDEFILE=D:\CONFIG.SYS` (issue #68, [config-include.md](config-include.md)).

### MODE

```
MODE LPT1 CP PREPARE=((850) C:\DOS\4201.CPI)
MODE LPT1 CP SELECT=850
MODE LPT1 CP REFRESH
MODE LPT1 CP /STATUS
```

MODE's messages for the printer, as `make test-printer` sees them:

| Case | Message |
|---|---|
| no PRINTER.SYS | `Code page operation not supported on this device` |
| SELECT of a code page not prepared | `Code page not prepared` |
| more code pages than slots | `Device error during prepare`; the slots are then empty, and nothing is selected |
| a code page the file does not have, or another printer's file | `Device or code page missing from font file`; the slots are then empty |
| the file is missing | `Failure to access code page font file` |

MODE's other printer commands do not need PRINTER.SYS: `MODE LPT1:132,8`
(132 columns and 8 lines per inch, which MODE sets with escape sequences
for IBM printers), `MODE LPT1:,,P` (retry while the printer is busy) and
`MODE LPT1=COM1` (send LPT1's output to a serial printer).

### PRINT and GRAPHICS

```
PRINT /D:LPT1 REPORT.TXT
PRINT
GRAPHICS
GRAPHICS COLOR4 /R
```

PRINT's first run installs it resident, asking for the device unless
`/D:` gives it. GRAPHICS reads GRAPHICS.PRO from its own directory, or
from the path given after the type. Then Shift+PrtSc prints a CGA, EGA
or VGA graphics screen.

### A Portuguese Proprinter

On a CF install, with `D:\CONFIG.SYS`:

```
DEVICE=C:\DOS\PRINTER.SYS LPT1=(4201,437,1)
```

and in `D:\AUTOEXEC.BAT`:

```
MODE LPT1 CP PREPARE=((860) C:\DOS\4201.CPI)
MODE LPT1 CP SELECT=860
```

The printer prints text in code page 860. `MODE LPT1 CP SELECT=437` gives
back its own characters. A printer switched off and on loses the font;
`MODE LPT1 CP REFRESH` sends it again.

## Tests

- **`make test-printer`** (`tests/printer`) boots a 1.44 MB image once for
  each scenario, with QEMU's LPT1 written to a file
  (`scripts/smoke-test --parallel`). It checks the lines on COM1
  (`expect`), and every byte the printer received (`lpt`), with
  `tests/printer/check-lpt`, which takes the expected selection sequences
  and font downloads from the `.CPI` files themselves. Each step of the
  test's batch file writes a `== NAME` line to LPT1 too, so each byte is
  checked against the step that sent it. The scenarios are:
  - `4201`, `LPT1=(4201,437,1)`: prepare and select 850, which downloads
    4201.CPI's font; text; select 437; select 850 again, which does not
    download it again; REFRESH, which does; and MODE's errors;
  - `4208` and `5202`, `LPT1=(4208,437,1)` and `(5202,437,1)`: 437 before
    anything is prepared; prepare and select 850; text; 437; and the
    errors;
  - `none`, no PRINTER.SYS: MODE's error, COPY and TYPE to the printer,
    GRAPHICS printing a CGA graphics screen (mode 4) that DEBUG draws,
    byte for byte the rotated dump GRAPHICS.PRO describes, and PRINT.
- **`make test-extras`** checks GRAPHICS' and PRINT's messages, and that
  they stay resident ([m5-utilities.md](m5-utilities.md)).
- **`make test-floppy-1200`** and **`-1440`** check the files on the
  disks, and the 360 KB and 720 KB tests that theirs are unchanged.

The expected output is what GR-DOS does, which is MS-DOS 4.00's: these are
Microsoft's programs and data, byte for byte. Each recorded line and byte
sequence was checked against the source: the sequences against
`CPSPM10.ASM`, 5202.ASM and the `.CPI` files, the messages against
`MODE.SKL`, the graphics dump against `GRAPHICS.PRO`.

### Limits found

- **No printer has been tested, only QEMU's parallel port in a file.**
  What a 4201, 4208 or 5202 does with the bytes, and whether a
  compatible printer (an Epson, say, which has other escape sequences)
  does anything useful with them, needs real printers. PRINTER.SYS'
  types are IBM's printers only; other printers can still print text in
  their own code page, without PRINTER.SYS.
- **PRINTER.SYS' own sequence for a 4208's or 5202's hardware code page
  is wrong.** Before anything is prepared, selecting the hardware code
  page sends PRINTER.SYS' template for the printer, in which it put the
  code page at offset 8, low byte first, at boot (`CPSPI07.ASM`,
  `CTL5202_OFFS`). For the 5202 that gives `ESC [ T 5 0 0 0 B5h 01h 0 ESC
  6` for 437, where IBM's escape sequence (and 5202.CPI's) has the code
  page high byte first, `01h B5h`; for the 4208 the code page lands on
  the template's `ESC I 2`, giving `ESC I 10, ESC I 3, ESC B5h 01h, ESC 6`.
  Once a code page is prepared from the `.CPI` file, every selection,
  437's too, uses the file's sequences, which are right. So prepare
  before selecting. This is MS-DOS 4.00's PRINTER.SYS as published, and
  `make test-printer` records it; GR-DOS does not change it.
- **A failed PREPARE empties the slots.** After "Device error during
  prepare" or "Device or code page missing from font file", the code
  pages prepared before are gone, and none is selected, as MODE's
  `/STATUS` then shows.
- **An unknown printer type loads PRINTER.SYS anyway**, resident (11.5 KB),
  with no code pages for the device.
- **Text-mode Print Screen is the BIOS's.** GRAPHICS leaves text modes to
  the BIOS's INT 5 for a black and white printer, and QEMU's SeaBIOS has
  no Print Screen, so it is not tested; on an IBM PC or compatible, the
  BIOS prints the screen's text.
- **Only mode 4 (320×200, CGA) is tested** for GRAPHICS, with the default
  printer type. The other modes and types follow the same code with
  GRAPHICS.PRO's numbers, but are not compared with a printer.
- **PRINT prints only when DOS is idle or not busy.** In a batch file
  that never waits for a key, a queued file may not be printed until
  the batch file ends (the test calls INT 28h with DEBUG). At the
  prompt it prints as expected.
- **Only LPT1 is tested**: QEMU has one parallel port here. LPT2 and LPT3
  are the same code with another BIOS printer number.
