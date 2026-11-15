@ECHO OFF
REM MORE tests (make test-more). CTTY AUX sends MORE's output and its
REM prompts to COM1, and it takes its keys from there too: scripts/smoke-test
REM answers each "-- More --" with the next key of tests/more/answers. After
REM each command, EL.BAT reports the errorlevel. The expected output,
REM expect.log, is MS-DOS 4.00's MORE.COM's (make more-expect).
CTTY AUX
ECHO GRDOS-TEST-BEGIN
ECHO == short
MORE <SHORT.TXT
CALL EL
ECHO == empty
MORE <EMPTY.TXT
CALL EL
ECHO == 23, 24 and 25 lines
MORE <L23.TXT
CALL EL
MORE <L24.TXT
CALL EL
MORE <L25.TXT
CALL EL
ECHO == pages
MORE <LONG.TXT
CALL EL
ECHO == no end of line, LF only
MORE <NOEOL.TXT
CALL EL
MORE <LF.TXT
CALL EL
ECHO == wide lines
MORE <WIDE.TXT
CALL EL
ECHO == tabs
MORE <TABS.TXT
CALL EL
ECHO == control characters
MORE <CTRL.TXT
CALL EL
ECHO == every byte
MORE <BYTES.BIN
CALL EL
ECHO == ^Z
MORE <EOF.TXT
CALL EL
ECHO == larger than the buffer
MORE <BIG.TXT
CALL EL
MORE <BIGEOF.TXT
CALL EL
MORE <EDGE.TXT
CALL EL
ECHO == pipe
TYPE LONG.TXT | MORE
CALL EL
TYPE EOF.TXT | MORE
CALL EL
ECHO == arguments, which MORE ignores
MORE /X NOFILE.TXT <SHORT.TXT
CALL EL
ECHO == output to a file: the prompts still on standard error
MORE <L25.TXT >OUT.TXT
CALL EL
TYPE OUT.TXT
ECHO == no input file
MORE <NOFILE.TXT
CALL EL
ECHO GRDOS-TEST-END
CTTY CON
