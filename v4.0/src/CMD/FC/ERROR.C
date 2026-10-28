/* error.c - return text of error corresponding to the most recent DOS error */

#include "tools.h"

#ifdef __WATCOMC__  /* libc16 has strerror, with Microsoft C's texts */
#include <errno.h>
#else
extern int errno;
extern sys_nerr;
extern char *sys_errlist[];
#endif
extern char UnKnown[];

char *error ()
{
#ifdef __WATCOMC__
    return strerror(errno);
#else
    if (errno < 0 || errno >= sys_nerr)
	return UnKnown;
    else
	return sys_errlist[errno];
#endif
}
