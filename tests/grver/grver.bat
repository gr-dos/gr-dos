@ECHO OFF
REM GRVER's tests (make test-grver, tests/grver): its output and exit
REM status, from the kernel on the disk (GR-DOS's, or MS-DOS 4.00's for
REM test-grver-msdos), and with FAKEID's imitations of the kernel's answer
REM (tests/grver/fakeid.asm). RC.BAT prints the exit status.
CTTY AUX
ECHO GRDOS-TEST-BEGIN
ECHO == GRVER
GRVER
CALL RC
ECHO == GRVER /?
GRVER /?
CALL RC
ECHO == GRVER /X
GRVER /X
CALL RC
ECHO == GRVER A B
GRVER A B
CALL RC
FOR %%M IN (U D S C M R G) DO CALL FAKE %%M
ECHO GRDOS-TEST-END
CTTY CON
