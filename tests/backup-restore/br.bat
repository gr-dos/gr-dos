@ECHO OFF
REM BACKUP and RESTORE tests (make test-backup-restore), run from C:\ of a
REM CF install with a 1.44 MB A:: D:\AUTOEXEC.BAT starts it. CTTY AUX sends
REM the output to COM1, and takes the keys from it; after each command,
REM EL.BAT (in C:\DOS) reports the errorlevel. "== set NAME" tells
REM scripts/backup-restore-test which floppies to put in A: when asked.
REM The expected output, expect.log, is Microsoft's BACKUP.COM's and
REM RESTORE.COM's (make backup-restore-expect).
CTTY AUX
ECHO GRDOS-TEST-BEGIN
REM The answer to DEL's question; scripts/backup-restore-test answers
REM RESTORE /P's
ECHO Y>C:\Y.TXT
D:
CD \BR
ECHO == the files
REM The directories' own dates are when mtools made them: not shown.
DIR SRC | FIND ":" | FIND /V "<DIR>"
DIR SRC\SUB | FIND ":" | FIND /V "<DIR>"
DIR SRC\SUB\DEEP | FIND ":" | FIND /V "<DIR>"
DIR SRC\DOC | FIND ":" | FIND /V "<DIR>"
ATTRIB SRC\*.*
COPY SRC\SUB\DEEP\BIG1.BIN ORIG1.BIN >NUL
COPY SRC\SUB\DEEP\BIG2.BIN ORIG2.BIN >NUL

ECHO == BACKUP: bad parameters
BACKUP SRC A: /Z
CALL EL
BACKUP D:\BR\SRC D:
CALL EL
BACKUP
CALL EL

ECHO == set EMPTY
ECHO == BACKUP: nothing to back up
BACKUP D:\BR\SRC\*.XYZ A:
CALL EL

ECHO == set SPAN
ECHO == BACKUP /S, onto three disks, with a log
BACKUP D:\BR\SRC A: /S /L:D:\BR\BACKUP.LOG
CALL EL
FIND "\" BACKUP.LOG
ECHO == the archive bits BACKUP cleared
ATTRIB SRC\*.*

ECHO == RESTORE: bad parameters
RESTORE A:
CALL EL
RESTORE A: D:\BR\SRC /Z
CALL EL
RESTORE A: A:\X
CALL EL
ECHO == RESTORE: nothing to restore
RESTORE A: D:\BR\SRC\*.XYZ
CALL EL

ECHO == all gone
ATTRIB -R SRC\READONLY.TXT
REM DEL leaves HIDDEN.TXT, which DOS 4.00's ATTRIB cannot unhide.
DEL SRC\SUB\DEEP\*.*  <C:\Y.TXT
RD SRC\SUB\DEEP
DEL SRC\SUB\*.* <C:\Y.TXT
RD SRC\SUB
DEL SRC\DOC\*.* <C:\Y.TXT
RD SRC\DOC
DEL SRC\*.* <C:\Y.TXT
DIR SRC | FIND ":" | FIND /V "<DIR>"

ECHO == RESTORE /S: everything, the directories made again
RESTORE A: D:\BR\SRC\*.* /S
CALL EL
DIR SRC | FIND ":" | FIND /V "<DIR>"
DIR SRC\SUB | FIND ":" | FIND /V "<DIR>"
DIR SRC\SUB\DEEP | FIND ":" | FIND /V "<DIR>"
DIR SRC\DOC | FIND ":" | FIND /V "<DIR>"
ATTRIB SRC\*.*
TYPE SRC\A.TXT
TYPE SRC\SUB\DEEP\C.TXT
FC /B ORIG1.BIN SRC\SUB\DEEP\BIG1.BIN
FC /B ORIG2.BIN SRC\SUB\DEEP\BIG2.BIN

ECHO == RESTORE a wildcard, without /S
DEL SRC\DOC\*.* <C:\Y.TXT
DEL SRC\A.TXT
RESTORE A: D:\BR\SRC\DOC\*.DOC
CALL EL
DIR SRC\DOC | FIND ":" | FIND /V "<DIR>"
IF NOT EXIST SRC\A.TXT ECHO SRC\A.TXT was not restored

ECHO == RESTORE /N: only what is not there
DEL SRC\SUB\B.TXT
RESTORE A: D:\BR\SRC\*.* /S /N
CALL EL
TYPE SRC\SUB\B.TXT

ECHO == RESTORE /P: a read-only file
ATTRIB +R SRC\READONLY.TXT
RESTORE A: D:\BR\SRC\READONLY.TXT /P
CALL EL

ECHO == set INC
ECHO == BACKUP /M: what changed
ECHO changed>SRC\SUB\B.TXT
BACKUP D:\BR\SRC A: /S /M
CALL EL
ECHO == BACKUP /A: added to it
ECHO new>SRC\DOC\NEW.DOC
BACKUP D:\BR\SRC\DOC\*.DOC A: /A /M
CALL EL
ECHO == RESTORE what was added
DEL SRC\DOC\NEW.DOC
DEL SRC\SUB\B.TXT
RESTORE A: D:\BR\SRC\*.* /S
CALL EL
TYPE SRC\SUB\B.TXT
TYPE SRC\DOC\NEW.DOC

ECHO == set RAWF
ECHO == BACKUP /F: a blank disk, which FORMAT formats
BACKUP D:\BR\SRC\DOC A: /F
CALL EL
DEL SRC\DOC\*.* <C:\Y.TXT
RESTORE A: D:\BR\SRC\DOC\*.*
CALL EL
REM NEW.DOC is from this run: its time is not shown.
DIR SRC\DOC | FIND ":" | FIND /V "<DIR>" | FIND /V "NEW"
IF EXIST SRC\DOC\NEW.DOC ECHO SRC\DOC\NEW.DOC was restored

ECHO == set MSSET
ECHO == RESTORE what Microsoft's BACKUP wrote
DEL SRC\SUB\DEEP\*.* <C:\Y.TXT
RD SRC\SUB\DEEP
RESTORE A: D:\BR\SRC\SUB\DEEP\*.*
CALL EL
FC /B ORIG1.BIN SRC\SUB\DEEP\BIG1.BIN
FC /B ORIG2.BIN SRC\SUB\DEEP\BIG2.BIN
DIR SRC\SUB\DEEP | FIND ":" | FIND /V "<DIR>"
ECHO GRDOS-TEST-END
