# HELP and GRDOS.HLP (issue #27)

GR-DOS has offline command help: `HELP` shows a topic from `GRDOS.HLP`,
a text file. Both are in `C:\DOS` and on the 720 KB, 1.2 MB and 1.44 MB
floppies. The 360 KB floppy's files are frozen (issue #17), so it has
neither.

```
A:\>HELP
GR-DOS help: type HELP and a topic, such as HELP START or HELP XCOPY.
...
A:\>HELP XCOPY
A:\>HELP COPY
A:\>HELP FILES
A:\>HELP START
```

- `HELP` lists the topics, by group: guides, programs, COMMAND.COM's
  built-in commands, CONFIG.SYS, and device drivers and data files. A `*`
  marks a topic of GR-DOS's own; the others are MS-DOS 4.00's.
- `HELP topic` shows one topic. A topic is a command, a CONFIG.SYS command
  (`FILES`, `BUFFERS`), a driver (`DISPLAY.SYS`) or a guide (`START`,
  `FLOPPY`, `HARDDISK`, `CONFIG`, `CODEPAGE`, `BATCH`, `GRDOS`). Case does
  not matter, and an extension does not either: `HELP XCOPY.EXE` is
  `HELP XCOPY`. Aliases name the same topic: `CHDIR` is `CD`, `ERASE` is
  `DEL`.
- On the screen it shows the topic with `LESS.EXE`, when there is one,
  so it scrolls both ways ([HELP and LESS](#help-and-less)). Otherwise,
  or with `HELP /P`, it stops after each screenful itself: any key goes
  on, `Q` or `Esc` stops. Redirected (`HELP MODE >PRN`,
  `HELP DIR | FIND "/W"`), it neither runs LESS nor stops.
- It looks for `GRDOS.HLP` in its own directory (from the program's path,
  which DOS puts after the environment), then in the current directory,
  then in each directory of `PATH`.
- **Exit status:** 0, shown; 1, no such topic; 2, no `GRDOS.HLP`; 3, a bad
  parameter (two topics, or a switch other than `/P`).

No MS-DOS 4.00 `HELP` exists, and no help text: Microsoft's published
source has none for the commands (the only help files are SELECT's
installer screens, `SELECT/USA.TXT`, and Microsoft C's `TOOLS/CL.HLP`).
Every topic is GR-DOS's own text, written from the 4.00 source (each
program's parser tables and messages) and GR-DOS's documents. Nothing is
copied from the retail MS-DOS manuals or from a later DOS's help.

## HELP.EXE

`help/help.c` is GR-DOS's own C, built with Open Watcom C and libc16 like
GRVER ([grver.md](grver.md)), for the 8086. It reads the file a line at a
time with `fgets`, so it needs a few KB of memory, whatever the file's
size. HELP.EXE is 5,846 bytes, and GRDOS.HLP about 100 KB, of 83 topics. `scripts/check-runtime` checks its link
map.

### HELP and LESS

On the screen (standard output is the console, INT 21h 4400h), HELP shows
the topic with gr-dos/less16's `LESS.EXE`, 0.02 or later, which is in
`C:\DOS` (issue #86). The floppies do not have LESS, so there HELP pages
the topic itself, as before.

- **Finding the topic first.** HELP finds the topic (with its aliases,
  and the extension dropped if need be) before it looks for LESS, so an
  unknown topic is reported as before and LESS is never started for it.
  It notes where the topic's text is in `GRDOS.HLP`: from the line after
  its `@@` line, up to the next `@@` line or the end of the file. libc16's
  `ftell` counts the file's bytes in text mode too, so these are offsets
  in the file.
- **Running LESS.** HELP closes `GRDOS.HLP` and runs
  `LESS.EXE --start=S --end=E --label=NAME PATH`, with `PATH` the
  `GRDOS.HLP` it opened, through libc16's `spawnvp`: `LESS.EXE` in the
  current directory, then in each directory of `PATH`, as COMMAND.COM
  finds a command, with its extension given, so no `LESS.COM` or other
  program is run. LESS views that byte range as if it were the whole
  file, so no other topic's `@@` line or text can be scrolled to, and
  nothing is written: no temporary file, no `TEMP`, no writable disk.
  `--label` puts the topic's name in LESS's status line.
- **Memory.** libc16's startup shrinks HELP's memory block to the top of
  its stack, and HELP takes no heap, so LESS gets all the memory above
  HELP's few KB.
- **Falling back.** If LESS is not found, cannot be run (too little
  memory, say), or ends with an errorlevel other than 0 (1 for an option
  it does not know, as LESS 0.01 does with `--start`, or a malformed
  range; 2 for a range outside the file), HELP opens `GRDOS.HLP` again and
  pages the topic itself. LESS shows nothing before such an error, so the
  topic is shown once. LESS ended with `Q` (errorlevel 0) is the end of
  HELP; HELP's errorlevel is 0 either way.
- **`/P`** makes HELP page the topic itself even when LESS is there. It
  may come before or after the topic. Any other switch is still a bad
  parameter (3).

## GRDOS.HLP

`scripts/mkhelp` makes it from `help/topics/*.txt`, one file a topic. Each
starts with a header:

```
Topic: XCOPY
Summary: Copies files, and directories with their subdirectories
Origin: MS-DOS 4.00
Group: command
Files: XCOPY.EXE
```

then a blank line and the text: `Syntax`, a table of the parameters,
`Examples`, `Exit status` where the source gives one, and `Notes`, with
the safety notes of the commands that change disks. `Aliases:` lists other
names for the topic.

`GRDOS.HLP` is CRLF text. Each topic is a line `@@NAME ALIAS...`, then
the topic: its name and summary, its origin and where its files are, for
example `XCOPY.EXE: in C:\DOS and the 720 KB, 1.2 MB and 1.44 MB
floppies.`, and the text. The first topic is `INDEX`, made from the
summaries.

### Kept in step with the distribution

`make` runs `scripts/mkhelp` with the names of the CF install's files
(`ALL_FILES`), each floppy's list (`image/files-*k.txt`), and the `*16`
programs (`dist16/lock`). It fails unless:

- every program and data file distributed is in some topic's `Files:`,
  but the kernel's files, `COMMAND.COM` (whose commands are the `internal`
  topics), `AUTOEXEC.BAT` and the `*16` programs, which have their own
  `--help` (the `DIST16` topic lists them, and each is an alias of it);
- every file a topic names is distributed;
- every topic name and alias is unique and in upper case;
- the text is ASCII, in lines of at most 79 characters;
- the first word of each example is a command with a topic.

So a program added to the distribution without help, or help for a
program that is not distributed, fails the build, and the "where" lines
always match the floppies.

## Tests

`make test-floppy-720`, `test-floppy-1200` and `test-floppy-1440` run
HELP from A: (`tests/floppy/floppy.bat`): `HELP XCOPY.EXE` and the alias
`HELP CHDIR`, through `FIND`, and the errorlevels of an unknown topic (1)
and a switch (3). On 360 KB, HELP is a bad command or file name.

`make test-help-less` (`tests/help-less`) drives HELP on the screen in
QEMU (`scripts/disk-test`), from a 1.44 MB disk with HELP, `GRDOS.HLP`,
the lock's `LESS.EXE` and FIND. For the first topic (`INDEX`), one between
two others (`COPY`) and the last (`XCOPY`, reached as `XCOPY.EXE`), the
screens LESS shows at the start and the end of the topic, with Home, End,
PgUp, PgDn, Up and Down, hold that topic and nothing of the ones around
it. Redirected, HELP runs no LESS. `HELP /P`, HELP with LESS renamed
away, and HELP with a `LESS.EXE` that only exits with errorlevel 1 each
show the topic once with HELP's own pager.
