/*
 * Microsoft C 5.1 compatibility for Open Watcom C, included before each C
 * source of the DOS tree (wcc -fi). The headers are GR-DOS's, compat/include,
 * for its C runtime, compat/crt: their functions use the C calling
 * convention, as Microsoft C's did, whether the programs declare them or not.
 */
#include <dos.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <conio.h>
#include <io.h>
/*
 * The programs take ES for intdosx() from segread(), which works because
 * Microsoft C keeps ES equal to DS; Watcom C does not.
 */
#define segread(s) (segread(s), (s)->es = (s)->ds)
