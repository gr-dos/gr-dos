# Country and keyboard data (issue #23)

GR-DOS builds MS-DOS 4.00's two national language data files from the
published source, byte for byte as Microsoft's build makes them (`make
check`):

- **`COUNTRY.SYS`**, the country information that `COUNTRY=` in
  `CONFIG.SYS`, NLSFUNC and CHCP read: date, time, number and currency
  formats, and the case mapping, collating and file name tables, for 23
  countries in 46 country and code page combinations;
- **`KEYBOARD.SYS`**, KEYB's 17 keyboard layouts.

With them, `COUNTRY=`, NLSFUNC, CHCP and KEYB, built since issue #17
([M5](m5-utilities.md)), work as on MS-DOS 4.00.

## What the source has

| Source | What it is | GR-DOS |
|---|---|---|
| `DEV/COUNTRY` | `MKCNTRY.ASM` and `MKCNTRY.INC`: a program that holds `COUNTRY.SYS` and writes it | built: `COUNTRY.SYS` |
| `DEV/KEYBOARD` | `KDF*.ASM`, the layouts' tables, with `KEYBMAC.INC` and `KEYBSHAR.INC` | built: `KEYBOARD.SYS` |
| `CMD/KEYB`, `CMD/NLSFUNC` | the programs | built since issue #17 |
| `BIOS/SYSINIT*.ASM` | `COUNTRY=`, which loads a country from `COUNTRY.SYS` at boot | in IO.SYS |
| `CMD/COMMAND` | `DATE`, `TIME`, `DIR` and `CHCP`, which use the country's formats | in COMMAND.COM |
| `DEV/DISPLAY` | code page switching for the screen: DISPLAY.SYS and its EGA and LCD fonts | built since issue #24: [codepage.md](codepage.md) |
| `DEV/PRINTER` | code page switching for printers: PRINTER.SYS and the 4201, 4208 and 5202 `.CPI` files | not built: issue #25 |

Everything GR-DOS uses here is in Microsoft's MIT-licensed `v4.0` tree.
No retail MS-DOS file is used or distributed. `KEYBOARD.LNK` links 20 of
`DEV/KEYBOARD`'s 25 `.ASM` files. The others are not part of
`KEYBOARD.SYS`. `KDF.ASM`, `KDFFR.ASM`, `KDFIT.ASM` and `KDFUK.ASM` are
older tables. `KDFSU.ASM` is Finland's, which uses Sweden's table
instead (`KDFNOW.ASM`).

## Building

- **`KEYBOARD.SYS`**: the tables are assembled with JWasm, linked in
  `KEYBOARD.LNK`'s order and converted with EXE2BIN
  (`DEV/KEYBOARD/MAKEFILE`). The tables use macros named `GOTO` and
  `OPTION`, with a parameter `MASK`, which are JWasm keywords but not
  MASM 5's. So `DEV/KEYBOARD/KEYBMAC.INC` has the same `IFDEF __JWASM__`
  `OPTION NOKEYWORD:<MASK,OPTION,GOTO>` as KEYB's copy of the file
  ([M5](m5-utilities.md#source-edits)). MASM's build is unchanged
  (`scripts/check-reference`).
- **`COUNTRY.SYS`**: `DEV/COUNTRY/MAKEFILE` links `MKCNTRY.EXE` and runs
  it, and the program writes the country data it holds to `COUNTRY.SYS`.
  `scripts/mkcntry` writes the same bytes without running it. It finds the
  data segment from the program's first instruction, and the offset and
  length from its DOS write call (INT 21h function 40h). It fails if the
  program is not the shape it expects.

`make check` compares `MKCNTRY.EXE`, `COUNTRY.SYS` and `KEYBOARD.SYS`
with the M1 reference build.

## Where they are

| | `KEYB.COM` | `NLSFUNC.EXE` | `COUNTRY.SYS`, `KEYBOARD.SYS` |
|---|:-:|:-:|:-:|
| 360 KB floppy | | | |
| 720 KB floppy | ✓ | | ✓ |
| 1.2 MB, 1.44 MB floppies | ✓ | ✓ | ✓ |
| CF install (`C:\DOS`), release ZIP (`BIN`) | ✓ | ✓ | ✓ |

The 360 KB floppy's files are frozen (issue #17). A keyboard layout is
the most useful of these on a floppy for a two-drive machine, so 720 KB
gets KEYB and both data files, about 50 KB of its 282 KB free. NLSFUNC
matters only for CHCP, so it is on 1.2 MB and 1.44 MB. On a floppy the
data files are in the root, where `COUNTRY=` and KEYB look for them by
default.

## Using them

### COUNTRY= in CONFIG.SYS

```
COUNTRY=049
COUNTRY=044,850
COUNTRY=049,,C:\DOS\COUNTRY.SYS
```

The syntax is `COUNTRY=code[,[code page][,[d:][path]COUNTRY.SYS]]`. The
default file is `\COUNTRY.SYS` on the boot drive. The default code page is
the first that `COUNTRY.SYS` lists for the country (the table below). If
the country, or the country with that code page, is not in the file, or
the file is missing, DOS says so at boot and keeps its built-in United
States settings.

The country sets the formats of `DATE`, `TIME` and `DIR` (DATE always
shows a four-digit year, and its prompt always uses dashes, whatever the
separator), and what programs get from INT 21h function 38h. It also sets
the case mapping and the collating sequence of function 65h: SORT
sorts by that sequence, and `FC /C` folds case with DOS's case map.

**On a CF install**, `scripts/deploy-cf` writes `C:\CONFIG.SYS` again at
every update ([deploy-cf.md](deploy-cf.md)), so a `COUNTRY=` line added to
it is lost at the next update. `D:\AUTOEXEC.BAT` cannot set the country,
because only `CONFIG.SYS` can.

### NLSFUNC and CHCP

```
NLSFUNC C:\DOS\COUNTRY.SYS
CHCP 850
```

NLSFUNC loads resident and reads `COUNTRY.SYS` when CHCP asks for another
code page. CHCP can choose only a code page that `COUNTRY.SYS` has for
the current country, or it says "Invalid code page". The change applies
only to DOS's tables, unless DISPLAY.SYS is loaded and MODE's `CP PREPARE`
has given it the code page: then CHCP changes the screen's font too
([codepage.md](codepage.md)). Otherwise the font stays the hardware's,
normally code page 437.

### KEYB

```
KEYB GR
KEYB FR,437
KEYB UK,,C:\DOS\KEYBOARD.SYS
```

The syntax is `KEYB [code[,[code page][,[d:][path]KEYBOARD.SYS]]][/ID:id]`.
Without a path, KEYB tries `KEYBOARD.SYS` in the current directory, then
in KEYB's own directory, then `\KEYBOARD.SYS`. So `C:\DOS\KEYB GR` finds
`C:\DOS\KEYBOARD.SYS`. KEYB alone reports the layout in use.

Once loaded:
- Ctrl+Alt+F1 switches to the US layout, and Ctrl+Alt+F2 back.
- Running KEYB again with another code loads that layout in place of the
  first.
- On an enhanced keyboard, AltGr (right Alt) gives the third characters,
  such as Germany's `@`, `{` and `}`.

On a CF install, put it in `D:\AUTOEXEC.BAT`, for example `KEYB GR`, as
`PATH` includes `C:\DOS`.

KEYB loads a layout for one code page. Without DISPLAY.SYS, CON cannot
report its code page ("Active code page not available from CON device").
KEYB then takes the code page given, or the layout's first. Use code page
437, which matches the screen's font, for every layout that has it. PO,
DK, NO and CF do not, so their characters appear as code page 437's
glyphs for the same bytes. With DISPLAY.SYS, KEYB takes CON's code page,
and follows it when MODE or CHCP selects another; on an EGA or VGA,
EGA.CPI's 850, 860, 863 and 865 give PO, DK, NO and CF their characters
([codepage.md](codepage.md)).

## Supported countries

From `COUNTRY.SYS` (the data is `DEV/COUNTRY/MKCNTRY.ASM`'s). The formats
are those of the first code page, the default. A country's other code
page has the same formats, except where noted below.

| Code | Country | Code pages | Date | Time | Thousands, decimal | Currency |
|---:|---|---|---|---|---|---|
| 001 | United States | 437, 850 | `mm-dd-yy` | 12h, `:` | `,` `.` | `$` |
| 044 | United Kingdom | 437, 850 | `dd-mm-yy` | 12h, `:` | `,` `.` | £ (9Ch) |
| 033 | France | 437, 850 | `dd/mm/yy` | 24h, `:` | space `,` | `F` |
| 049 | Germany | 437, 850 | `dd.mm.yy` | 24h, `.` | `.` `,` | `DM` |
| 034 | Spain | 850, 437 | `dd/mm/yy` | 24h, `:` | `.` `,` | `Pts` |
| 039 | Italy | 437, 850 | `dd/mm/yy` | 24h, `:` | `.` `,` | `L.` |
| 046 | Sweden | 437, 850 | `yy-mm-dd` | 24h, `.` | `.` `,` | `SEK` |
| 045 | Denmark | 850, 865 | `dd-mm-yy` | 24h, `.` | `.` `,` | `kr` |
| 041 | Switzerland | 850, 437 | `dd.mm.yy` | 24h, `.` | `'` `.` | `Fr` |
| 047 | Norway | 850, 865 | `dd.mm.yy` | 24h, `.` | `.` `,` | `Kr` |
| 031 | Netherlands | 437, 850 | `dd-mm-yy` | 24h, `:` | `.` `,` | ƒ (9Fh) |
| 032 | Belgium | 850, 437 | `dd/mm/yy` | 24h, `:` | `.` `,` | `BEF` |
| 358 | Finland | 850, 437 | `dd.mm.yy` | 24h, `.` | space `,` | `mk` |
| 972 | Israel | 862, 850 | `dd mm yy` | 24h, `:` | `,` `.` | ש (99h) |
| 002 | Canada (French) | 863, 850 | `yy-mm-dd` | 24h, `:` | space `,` | `$` |
| 785 | Arab states | 864, 850 | `dd/mm/yy` | 12h, `:` | `.` `,` | ¤ (A4h) |
| 351 | Portugal | 850, 860 | `dd/mm/yy` | 24h, `:` | `.` `,` | `$` |
| 003 | Latin America | 850, 437 | `dd/mm/yy` | 24h, `:` | `,` `.` | `$` |
| 061 | International English | 437, 850 | `dd-mm-yy` | 12h, `:` | `,` `.` | `$` |
| 081 | Japan | 932, 437 | `yy-mm-dd` | 24h, `:` | `,` `.` | `\` (yen, 5Ch) |
| 082 | Korea | 934, 437 | `yy-mm-dd` | 24h, `:` | `,` `.` | `\` (won, 5Ch) |
| 086 | China (PRC) | 936, 437 | `yy-mm-dd` | 24h, `:` | `,` `.` | `\` (yuan, 5Ch) |
| 088 | Taiwan | 938, 437 | `mm-dd-yy` | 24h, `:` | `,` `.` | `NT$` |

Some second code pages differ from the first:

- Spain in code page 437 has the peseta sign ₧ (9Eh).
- The Arab states in code page 850 have ¤ as CFh.
- Japan, Korea, China and Taiwan in code page 437 are the United
  States's record, country code 001 included, so `COUNTRY=081,437` reports
  country 001 with US formats.
- The uppercase tables also differ by code page. In code page 850, the
  United States's and the United Kingdom's map ä to A, where Germany's
  keeps Ä.

Code pages 932 to 938 are double-byte. COUNTRY.SYS has their lead byte
tables, but showing their characters needs DBCS display support, which
GR-DOS does not provide.

## Keyboard layouts

From `KEYBOARD.SYS`. The first code page is the default. The keyboard IDs
are for `/ID:`, and where a layout has two, the first is its default.

| Code | Layout | IDs | Code pages |
|---|---|---|---|
| US | United States | 103 | 437, 850, 860, 863, 865 |
| GR | Germany | 129 | 437, 850 |
| FR | France | 189, 120 | 437, 850 |
| IT | Italy | 141, 142 | 437, 850 |
| UK | United Kingdom | 166, 168 | 437, 850 |
| SP | Spain | 172 | 850, 437 |
| PO | Portugal | 163 | 850, 860 |
| DK | Denmark | 159 | 850, 865 |
| NO | Norway | 155 | 850, 865 |
| SG | Swiss German | 000 | 850, 437 |
| SF | Swiss French | 150 | 850, 437 |
| BE | Belgium | 120 | 850, 437 |
| NL | Netherlands | 143 | 437, 850 |
| SV | Sweden | 153 | 437, 850 |
| SU | Finland (Sweden's table) | | 850, 437 |
| CF | Canada (French) | 058 | 863, 850 |
| LA | Latin America | 171 | 850, 437 |

## Tests

- **`make test-country`** (`tests/country`) boots a 1.44 MB image once
  for each `tests/country/NAME/config.sys`. Each image has that file as
  `CONFIG.SYS`, plus COUNTRY.SYS and NLSFUNC. The scenarios are:
  - no `COUNTRY=`;
  - Germany from the default `\COUNTRY.SYS`;
  - the United Kingdom in code page 850 from a path;
  - Japan, in code page 932;
  - a missing file;
  - an unknown country.

  `tests/country/nlsinfo.asm`, built with Open Watcom like the smoke
  test's program, prints the country, code page and uppercase mapping DOS
  reports. The test also checks `DATE`, `TIME` and `DIR`, then loads
  NLSFUNC and changes the code page with `CHCP 850`, which Japan refuses.
- **`make test-keyb`** (`tests/keyb`) types at the 1.44 MB release image's
  prompt through QEMU's keyboard and compares the screens. It checks:
  - KEYB's errors;
  - Germany's swapped keys, umlauts, AltGr characters and dead accents;
  - Ctrl+Alt+F1 and F2;
  - France's AZERTY keys and dead circumflex;
  - the United Kingdom's £ and #.
- **`make test-floppy-720`** (and `-1200`, `-1440`) loads KEYB GR from the
  floppy, and NLSFUNC on 1.2 MB and 1.44 MB. The 360 KB test checks that
  neither is there.
- **`make test-extras`** loads KEYB UK and checks that MEM lists it.

The expected output is what GR-DOS does, which is MS-DOS 4.00's: these are
Microsoft's programs and data. Each recorded screen and line was checked
against the source's tables.

### Limits found

- **Code page switching was not part of issue #23.** Without DISPLAY.SYS,
  CHCP changes only DOS's tables, KEYB cannot learn the screen's code page,
  and MODE's `CP` commands have nothing to work with. DISPLAY.SYS and its
  fonts are built since issue #24 ([codepage.md](codepage.md)); printer
  code pages, PRINTER.SYS, are issue #25's.
- **Germany's code page 437 data uses `.` as the time separator.**
  `TIME` shows `4.37.19,29`.
- **The key left of 1 is not a dead key in the German layout.** It is
  `^` (`KDFGE.ASM`). Only the key right of ß is dead: an acute accent,
  and a grave accent with Shift.
- **KEYB PO, DK, NO and CF load in a code page other than 437**, for
  example "Current keyboard code: PO  code page: 850".
- **Untested on real hardware.** The data and the programs are tested in
  QEMU only, not on an 8088 or V20 in 86Box or on a real machine. KEYB's
  INT 9 handler is 8086 code, as is the rest of MS-DOS 4.00.
