# MOVE (issue #106)

GR-DOS's `MOVE.EXE` is MS-DOS 6.22's MOVE: it moves files, and renames
directories, with 6.22's syntax, messages, questions and errorlevels. It
is GR-DOS's own C (`move/move.c`), built with Open Watcom C and libc16 like
GRVER ([grver.md](grver.md)), for the 8086, with no DOS extender. It is in
`C:\DOS` and the release ZIP, and on no floppy ([Floppies](#floppies)).
MS-DOS 4.00 has no MOVE, and Microsoft has not published 6.22's source:
MOVE was written from 6.22's behaviour, which `make test-move` checks it
against, on MS-DOS 6.22 itself ([Tests](#tests)).

```
MOVE [/Y | /-Y] [drive:][path]filename[,...] destination
MOVE [/Y | /-Y] [drive:][path]dirname newname
```

```
D:\LETTERS>MOVE ED.TXT,SIGRID.TXT C:\LETTERS
d:\letters\ed.txt => c:\letters\ed.txt [ok]
d:\letters\sigrid.txt => c:\letters\sigrid.txt [ok]
```

## What MOVE does

- **Switches** come first: `/Y` replaces without asking, `/-Y` asks, `/?`
  shows a short help (GR-DOS's own text). `-Y` is `/Y`. Any other is
  `Invalid switch - X`. A switch after a file name is a file name.
- **Sources:** one argument, or several joined by commas. `A.TXT,B.TXT`,
  `A.TXT, B.TXT` and `A.TXT ,B.TXT` are the same; two arguments without a
  comma between them are `Too many parameters - NAME`. Each source may have
  wildcards: it is searched for with the hidden, system and directory
  attributes (INT 21h 4Eh), so a wildcard finds directories too, and hidden
  and system files, which are then not moved (`Cannot move NAME -
  Permission denied`). A source that matches nothing is `Cannot move NAME -
  No such file or directory`, and MOVE goes on with the next one.
- **The destination** is the last argument, made a full path: its drive,
  that drive's current directory if it is relative, `.` and `..` taken out,
  in lower case, as every name MOVE shows is. A `\` at its end is dropped.
  If it is a directory (a root is one), each file goes into it with its own
  name. If it is not there:
  - for one source file it is the file's new name: `MOVE C.TXT NEWC\`
    renames C.TXT to `NEWC`;
  - for several (a comma, or a wildcard that matches more than one entry)
    MOVE makes the directory, and any it is in, after asking `Make
    directory "NAME"? [yn]` when it asks at all. No, or a directory it
    cannot make, is `Cannot move multiple files to a single file`, as are
    several files and an existing file.
- **Each file** is shown as `SOURCE => DESTINATION `, then `[ok]`, or why
  it was not moved in brackets (`[Unable to create destination]`). A file
  onto itself is `Source and destination are the same, NAME`.
- **Replacing:** when the destination exists and MOVE asks, it asks
  `Overwrite NAME (Yes/No/All)?`. All stops the questions; No skips the
  file. A read-only destination is not replaced (`[Unable to create
  destination]`). A directory given as the new name of another replaces a
  file of that name, as 6.22's does.
- **Questions** take Y or N (and A for All), in either case, then Enter;
  the key is shown, and other keys are ignored. Ctrl-Z is No. Ctrl-C ends
  MOVE through DOS (`Terminate batch job (Y/N)?` in a batch file). Keys
  typed before the question are thrown away.

### When MOVE asks

MOVE asks before replacing a file, and before making a directory for
several files, only when it is typed at the prompt. From a batch file it
does neither, as earlier DOS versions' COPY did. It decides as 6.22's does,
in order:

1. If `COPYCMD` is set, MOVE asks unless the character after its first
   `/` is `Y` or `y`: `SET COPYCMD=/Y` stops the questions, anything else
   (`/-Y`, `/A /Y`, `junk`) asks, from a batch file too.
2. Otherwise it asks only if its parent is the primary COMMAND.COM (its own
   parent PSP) and that COMMAND.COM is not running a batch file. MOVE is an
   external program: it finds COMMAND.COM's batch segment as 6.22's does,
   by the bytes `cox` that 6.22's COMMAND.COM puts before it, in the first
   4 KB of COMMAND.COM's memory. GR-DOS's COMMAND.COM has them too
   (`patches/utilities/0004-batch-mark.patch`), so MOVE, and 6.22's own
   MOVE.EXE, can tell. A secondary COMMAND.COM started at the prompt is
   its own parent too, and MOVE asks there, as on 6.22. Under `COMMAND
   /C` 6.22's MOVE does not ask, where 4.00's COMMAND.COM looks just like
   a shell at its prompt: GR-DOS's COMMAND.COM also marks its SINGLECOM
   word, nonzero while a `/C` command runs, with `grdos/c`, and GR-DOS's
   MOVE does not ask while it is set. (Microsoft's MOVE.EXE, which does
   not know this mark, asks under GR-DOS's `COMMAND /C`.) With a
   COMMAND.COM without the `cox` mark, MOVE does not ask.
3. `/Y` and `/-Y` on the command line override both, the last one given.

### Moving a file

Within a drive MOVE renames the file (INT 21h 56h), which moves no data.
If that fails because the destination exists, it deletes the destination
(unless it is read-only) and renames again. If the rename still fails, as
it does from one drive to another, MOVE copies the file:

1. It opens the source, and creates the destination (INT 21h 3Ch), which
   replaces any file of that name.
2. It copies the data through a 10 KB buffer (1 KB if memory is short). A
   write that writes fewer bytes than it was given, a full disk, is
   `[Unable to write destination]`; a read error, `[Unable to read
   source]`.
3. It gives the copy the source's date and time (INT 21h 5700h, 5701h)
   and attributes (4300h, 4301h), and checks that the copy, closed, is the
   size of the source.
4. Only then does it delete the source (its attributes cleared first, so
   that a read-only source can be deleted).

If any step fails, the copy is deleted and the source kept, so a move
never loses the only whole copy of a file. A source MOVE cannot delete,
on a write-protected disk for example, stays where it is, and the move is
still `[ok]`, as 6.22's is: then there are two copies.

Where MOVE goes beyond 6.22's, for safety:

- **The same file under two names.** 6.22's MOVE compares names as they
  are written, so `MOVE A.TXT E:\A.TXT`, with E: a SUBST of the current
  directory, deletes the destination, which is the source, and then
  cannot copy it. GR-DOS's MOVE also compares DOS's own names (TRUENAME,
  INT 21h 60h), and says `Source and destination are the same`.
- **The copy's size** is checked before the source is deleted.
- **An empty source** between commas (`MOVE ,A.TXT B`) is skipped; 6.22's
  changes to a directory from memory it never set.

### Renaming a directory

A directory is renamed with INT 21h 56h, which DOS allows only within its
parent directory: `MOVE C:\THISYEAR C:\LASTYEAR`. Moving one to another
directory, or another drive, is not supported, as in 6.22, where it fails
as a copy would: `[Unable to open source]`. MOVE does not copy directory
trees. It also refuses, with `Permission denied`, to put a directory into
itself or under itself, and a new name that would make some path in it
longer than DOS's 66 characters.

### Errorlevels

| Errorlevel | |
|---:|---|
| 0 | every file moved, or left where it was when the answer was No |
| 1 | a file not moved, or a parameter error (`Required parameter missing`, `Invalid switch`, `Too many parameters`, `Cannot move multiple files to a single file`, an invalid destination drive) |

`MOVE /?` is 0. Ctrl-C at a question ends MOVE as DOS ends a program.

## MS-DOS 6.22's kernel, and GR-DOS's

MOVE runs on GR-DOS's kernel, MS-DOS 4.00's, which answers two calls
differently from 6.22's. MOVE gives 6.22's answers itself:

- INT 21h 4300h, the attributes of a root directory (`A:\`), gives a
  directory on 6.22, and not on 4.00. With 4.00's answer, 6.22's own
  MOVE.EXE, run on GR-DOS, takes `A:\` for a file name, and cannot move
  files to it.
- INT 21h 4Eh finds `.` and `..` by the directory's own name on 6.22, and
  as `.` and `..` on 4.00. `MOVE . SUB` names the directory, which is not
  in itself: `Cannot move T19 - No such file or directory`, as on 6.22.

## Tests

`make test-move` (`scripts/move-test`) runs `tests/move/mv.bat` on a
512 MB CF install, with an empty 1.44 MB floppy in A: and a write-protected
one in B:, and then types `tests/move/typed.txt`'s commands at the prompt,
which MOVE asks about. It answers MOVE's, DOS's and COMMAND.COM's
questions, and checks:

- that COM1's output is `tests/move/expect.log`, byte for byte: MOVE's
  output, the errorlevels, the questions and their answers;
- that D:\M's, A:'s and B:'s files are `tests/move/files.txt`'s: each
  file's attributes, date and time, size and SHA-256, and each directory;
- that D: and A: pass `fsck.fat`.

On GR-DOS it then also types `tests/move/grdos.txt`'s commands, whose
output must be `tests/move/expect-grdos.log`: a file under two names
through SUBST, which 6.22's MOVE gets wrong (and 6.22's SUBST.EXE is not
on the install), so it is GR-DOS's own reference, not 6.22's. Nothing
there changes a file.

The cases: the parameters; renames and moves into directories; replacing,
with and without questions; wildcards; commas; several files to a file,
and to a directory that is not there, made with or without asking; a file
onto itself; missing files, paths and drives, and devices; read-only,
hidden and system files; directories; another drive, a full floppy and a
write-protected one (with DOS's `Abort, Retry, Fail?`); COPYCMD; relative
and drive-relative paths; two sources of the same name; Yes, No and All,
Ctrl-C, Ctrl-Z and Enter alone; wildcards and `..` in the destination; `.`
and `..` as the source; 66-character paths; and, at the prompt, the
questions, `/Y`, COPYCMD=/Y, `COMMAND /C` and a secondary COMMAND.COM.

`mv.bat` uses only COMMAND.COM's own commands (ECHO, SET, IF ERRORLEVEL,
COPY, MD), whose output is the same on GR-DOS and on MS-DOS 6.22, so the
same files run on both. `expect.log` and `files.txt` are MS-DOS 6.22's:
`make move-expect MSDOS622=DIR` runs the test on MS-DOS 6.22 itself, from
the 6.22 Upgrade's three 3.5" disks in DIR (`Disk1.img` to `Disk3.img`).
C: gets 6.22's boot sector code, IO.SYS, MSDOS.SYS and COMMAND.COM, and its
AUTOEXEC.BAT expands Disk 2's MOVE.EX_ into `C:\DOS\MOVE.EXE` with Disk
1's EXPAND.EXE. No file of Microsoft's is in this repository, and `MOVE
/?`'s output, which is GR-DOS's own text and not 6.22's, goes to NUL.

## Size

`MOVE.EXE` is 7,994 bytes (MS-DOS 6.22's is 18,319). It needs 14,832
bytes loaded, a 4 KB stack included, and its 10 KB copy buffer, allocated
only to copy a file to another drive: some 25 KB in all.

## Floppies

MOVE.EXE is on no floppy. The 360 KB floppy is frozen (issue #17). The
others have room for it (the 720 KB floppy has 48,128 bytes free), but
they have no MOVE now: a floppy is for installing GR-DOS and repairing a
system, where COPY and DEL do.
