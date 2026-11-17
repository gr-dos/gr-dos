@ECHO OFF
REM LPT1 without PRINTER.SYS: MODE has no code pages for it, and COPY,
REM TYPE, GRAPHICS (a screen dump of CGA graphics, which DEBUG draws with
REM GDUMP.IN) and PRINT send the printer their data as it is. PRINT prints
REM in the background when DOS is idle, which it never is in a batch file:
REM DEBUG calls INT 28h, DOS idle, with IDLE.IN. Each == line on COM1 is
REM also on LPT1, between what each step sends to the printer
REM (tests/printer/check-lpt).
CTTY AUX
ECHO GRDOS-TEST-BEGIN
ECHO == STATUS
ECHO == STATUS>LPT1
MODE LPT1 CP /STATUS
MODE LPT1 CP PREPARE=((850) A:\4201.CPI)
ECHO == TEXT
ECHO == TEXT>LPT1
COPY A:\HELLO.TXT LPT1
TYPE A:\HELLO.TXT>PRN
ECHO == GRAPHICS
ECHO == GRAPHICS>LPT1
GRAPHICS
DEBUG <A:\GDUMP.IN
ECHO == PRINT
ECHO == PRINT>LPT1
PRINT /D:LPT1 A:\HELLO.TXT
DEBUG <A:\IDLE.IN >NUL
PRINT
ECHO == END>LPT1
ECHO GRDOS-TEST-END
CTTY CON
