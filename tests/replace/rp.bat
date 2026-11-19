@ECHO OFF
REM REPLACE tests (make test-replace), run from C:\ of a CF install with a
REM 1.44 MB A:: D:\AUTOEXEC.BAT starts it. CTTY AUX sends the output to
REM COM1, and takes the keys from it; after each command, EL.BAT (in
REM C:\DOS) reports the errorlevel, and SHOW.BAT (C:\SHOW.BAT) a
REM directory's files, attributes and contents. "== keys KEYS" gives
REM scripts/replace-test the answers to the (Y/N) questions that follow.
REM D:\R's files are put there by scripts/replace-test: SRC the source,
REM T1 to T9 the same targets, one for each case; A: is empty, and B:,
REM write-protected, has A.TXT and a read-only RO.TXT. The
REM expected output, expect.log, is Microsoft's REPLACE.EXE's (make
REM replace-expect).
CTTY AUX
ECHO GRDOS-TEST-BEGIN
D:
CD \R
ECHO == the source, and a target
CALL C:\SHOW SRC
CALL C:\SHOW T1
CALL C:\SHOW T1\SUB
CALL C:\SHOW T1\SUB\DEEP

ECHO == replace: up to RO.TXT, which is read-only
REPLACE D:\R\SRC\*.TXT D:\R\T1
CALL EL
CALL C:\SHOW T1
ECHO == /R: read-only files too
REPLACE SRC\*.TXT T2 /R
CALL EL
CALL C:\SHOW T2
ECHO == /U /R: only those older than the source
REPLACE SRC\*.TXT T3 /U /R
CALL EL
CALL C:\SHOW T3
ECHO == /S /R: in the subdirectories too
REPLACE SRC\*.TXT T4 /S /R
CALL EL
CALL C:\SHOW T4
CALL C:\SHOW T4\SUB
CALL C:\SHOW T4\SUB\DEEP
ECHO == /S /U: newer only, in the subdirectories too
REPLACE SRC\*.TXT T9 /U /S
CALL EL
CALL C:\SHOW T9
CALL C:\SHOW T9\SUB
CALL C:\SHOW T9\SUB\DEEP
ECHO == /A: those not in the target, up to H.TXT, which is hidden there
REPLACE SRC\*.TXT T5 /A
CALL EL
CALL C:\SHOW T5
ECHO == /P /R: yes, no, a wrong key and yes, no, yes
ECHO == keys YNXYNY
REPLACE SRC\*.TXT T6 /P /R
CALL EL
CALL C:\SHOW T6
ECHO == /A /P: no
ECHO == keys N
REPLACE SRC\NEW.TXT T6 /A /P
CALL EL
ECHO == /A /P: yes
ECHO == keys Y
REPLACE SRC\NEW.TXT T6 /A /P
CALL EL
CALL C:\SHOW T6
ECHO == /W: a key first
REPLACE SRC\A.TXT T7 /W
CALL EL
CALL C:\SHOW T7

ECHO == the target, the current directory
CD T8
REPLACE ..\SRC\A.TXT
CALL EL
ECHO == the target, ..
CD SUB
REPLACE D:\R\SRC\B.TXT ..
CALL EL
ECHO == the target, the current directory of D:
CD \R\T8\SUB
REPLACE \R\SRC\A.TXT D:
CALL EL
CD \R
CALL C:\SHOW T8
CALL C:\SHOW T8\SUB
ECHO == a source and target in other directories than the current
CD \
REPLACE R\SRC\E.TXT R\T7\
CALL EL
CD \R
CALL C:\SHOW T7
ECHO == from another drive
C:
REPLACE D:\R\SRC\C.TXT D:\R\T7
CALL EL
D:
CALL C:\SHOW T7
ECHO == names that differ first in C and A
REPLACE C\A.TXT A
CALL EL
CALL C:\SHOW A
ECHO == a file onto itself
REPLACE T1\A.TXT T1
CALL EL
REPLACE T1\*.TXT T1 /A
CALL EL

ECHO == FAT12: add to A:, then replace
REPLACE SRC\*.TXT A:\ /A
CALL EL
REPLACE T2\*.TXT A:
CALL EL
CALL C:\SHOW A:
ECHO == A: full
REPLACE BIG\BIG.BIN A: /A
CALL EL
CALL C:\SHOW A:

ECHO == B:, write-protected: DOS's question, answered abort, then fail
ECHO == keys AF
REPLACE SRC\RO.TXT B:\ /R
CALL EL
REPLACE SRC\RO.TXT B:\ /R
CALL EL
ECHO == Ctrl-C at the question
ECHO == keys ^C
REPLACE SRC\A.TXT T7 /P
CALL EL

ECHO == nothing to do
REPLACE SRC\*.XYZ T1
CALL EL
REPLACE SRC\NEW.TXT T1
CALL EL
REPLACE SRC\A.TXT T1 /A
CALL EL
ECHO == bad paths
REPLACE SRC\*.TXT NOSUCH
CALL EL
REPLACE NOSUCH\*.TXT T1
CALL EL
REPLACE Q:\*.TXT T1
CALL EL
REPLACE SRC\*.TXT Q:\
CALL EL
ECHO == bad parameters
REPLACE
CALL EL
REPLACE SRC\*.TXT T1 /A /S
CALL EL
REPLACE SRC\*.TXT T1 /A /U
CALL EL
REPLACE SRC\*.TXT T1 /X
CALL EL
REPLACE SRC\*.TXT T1 /R /R
CALL EL
REPLACE SRC\*.TXT T1 EXTRA
CALL EL
REPLACE SRC\*.TXT T1 /R:X
CALL EL
REPLACE SRC\*.TXT T1 /A /R:X
CALL EL
REPLACE SRC\*.TXT T1 /A/S/U
CALL EL
ECHO GRDOS-TEST-END
