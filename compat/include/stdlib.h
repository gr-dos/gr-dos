/* GR-DOS C runtime (compat/crt): <stdlib.h> for ATTRIB and MEM. */
#ifndef GRCRT_STDLIB_H
#define GRCRT_STDLIB_H

/* The segment of the program's PSP, set by the startup code (c0.asm). */
extern unsigned int __cdecl _psp;

void __cdecl exit(int status);

#endif
