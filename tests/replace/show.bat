@ECHO OFF
REM Shows directory %1 for tests/replace/rp.bat: its files, with their
REM sizes, dates and times (not its subdirectories', which are when mtools
REM made them), their attributes, hidden files too, and their contents.
DIR %1 | FIND ":" | FIND /V "<DIR>"
ATTRIB %1\*.*
FOR %%F IN (%1\*.*) DO TYPE %%F
