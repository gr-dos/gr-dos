@ECHO OFF
REM FILESYS tests (make test-filesys), run from C:\ of a CF install:
REM D:\AUTOEXEC.BAT starts it. CTTY AUX sends the output to COM1; after
REM each command, EL.BAT (in C:\DOS) reports the errorlevel, or ELU.BAT
REM where Microsoft's FILESYS leaves it undefined: scripts/filesys-test
REM requires 0 there. The cases run
REM twice: without IFSFUNC, and with it, which stays resident. There is no
REM installable file system driver, so nothing can be attached. The
REM expected output, expect.log, is Microsoft's FILESYS.EXE's (make
REM filesys-expect).
IF "%1"=="CASES" GOTO CASES
CTTY AUX
ECHO GRDOS-TEST-BEGIN
ECHO ==== without IFSFUNC
CALL C:\FS CASES
ECHO ==== IFSFUNC
C:\DOS\IFSFUNC
CALL EL
ECHO ==== with IFSFUNC
CALL C:\FS CASES
ECHO GRDOS-TEST-END
GOTO END

:CASES
ECHO == the list
FILESYS
CALL ELU
ECHO == one drive, and one device
FILESYS E:
CALL ELU
FILESYS LPT1
CALL ELU
ECHO == attach a drive, and a device with parameters
FILESYS E: NOSUCHFS
CALL ELU
FILESYS LPT1 NOSUCHFS ONE TWO
CALL ELU
ECHO == detach
FILESYS E: /D
CALL ELU
FILESYS C: /D
CALL ELU
FILESYS LPT1 /D
CALL ELU
ECHO == bad parameters
FILESYS /D
CALL EL
FILESYS E: NOSUCHFS /D
CALL EL
FILESYS /X
CALL EL
FILESYS E: ONE TWO THREE FOUR
CALL EL
FILESYS E: /D /D
CALL EL
:END
