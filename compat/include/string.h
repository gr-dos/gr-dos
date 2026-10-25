/* GR-DOS C runtime (compat/crt): <string.h> for ATTRIB and MEM. */
#ifndef GRCRT_STRING_H
#define GRCRT_STRING_H

#ifndef GRCRT_SIZE_T
#define GRCRT_SIZE_T
typedef unsigned int size_t;
#endif

char  *__cdecl strcat(char *dst, const char *src);
int    __cdecl strcmp(const char *a, const char *b);
char  *__cdecl strcpy(char *dst, const char *src);
size_t __cdecl strlen(const char *s);

#endif
