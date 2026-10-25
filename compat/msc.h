/*
 * Microsoft C 5.1 compatibility for Open Watcom C, included before each C
 * source of the DOS tree (wcc -fi): ATTRIB and MEM assign to FP_SEG() and
 * FP_OFF(), which are lvalues in Microsoft C's <dos.h> and not in Watcom's,
 * and call runtime functions such as exit() without a prototype, which with
 * -ecc would not be the Watcom runtime's calling convention.
 */
#include <dos.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <conio.h>
#include <io.h>
#undef FP_SEG
#undef FP_OFF
#define FP_SEG(fp) (*((unsigned *)&(fp) + 1))
#define FP_OFF(fp) (*((unsigned *)&(fp)))
/*
 * The programs take ES for intdosx() from segread(), which works because
 * Microsoft C keeps ES equal to DS; Watcom C does not.
 */
#define segread(s) (segread(s), (s)->es = (s)->ds)
