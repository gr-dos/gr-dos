@ECHO OFF
REM The distribution tests (make test-floppy-360 and so on): the files of
REM one floppy format in A:, but this AUTOEXEC.BAT, and a blank data disk in
REM B:, as on a two-drive machine. The commands are run from B: by name,
REM found on the PATH that the image's own AUTOEXEC.BAT sets, A:\. Those the
REM format leaves out are a bad command or file name.
CTTY AUX
ECHO GRDOS-TEST-BEGIN
PATH A:\
B:
ECHO zeta>DATA.TXT
ECHO alpha>>DATA.TXT
ECHO beta>>DATA.TXT
ECHO == BASE
FIND /C "a" DATA.TXT
ATTRIB +R DATA.TXT
ATTRIB DATA.TXT
MORE <DATA.TXT
MEM
CHKDSK
ECHO == FLOPPY-720
SORT <DATA.TXT >SORTED.TXT
TYPE SORTED.TXT
XCOPY DATA.TXT SUB\
TREE /F
COMP DATA.TXT SUB\DATA.TXT <A:\COMP.IN
LABEL GRDATA2
VOL
ECHO == FLOPPY-1200
SHARE
GRAFTABL 437
GRAPHICS
APPEND SUB
APPEND
ECHO == FILES
DIR A:\ /W
ECHO GRDOS-TEST-END
CTTY CON
