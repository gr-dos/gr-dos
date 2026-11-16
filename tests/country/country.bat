@ECHO OFF
REM The country tests (make test-country-049 and so on): CONFIG.SYS's
REM COUNTRY= is each test's tests/country/NAME/config.sys. NLSINFO prints
REM what DOS reports of the country; DATE and TIME (ENTER.IN keeps them)
REM and DIR use its formats. NLSFUNC then lets CHCP change the code page.
CTTY AUX
ECHO GRDOS-TEST-BEGIN
ECHO == COUNTRY
NLSINFO
DATE <ENTER.IN
TIME <ENTER.IN
DIR NLSINFO.COM
ECHO == NLSFUNC
NLSFUNC A:\COUNTRY.SYS
CHCP
CHCP 850
CHCP
NLSINFO
ECHO GRDOS-TEST-END
CTTY CON
