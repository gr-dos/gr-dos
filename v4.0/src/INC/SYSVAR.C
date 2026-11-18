/* return the system variables in sysVars */

#include "sysvar.h"
#include <dos.h>
#include "jointype.h"

GetVars(pSVars)
struct sysVarsType *pSVars ;
{
        struct sysVarsType far *vptr ;
        int i ;

        union REGS ir ;
        register union REGS *iregs = &ir ;      /* Used for DOS calls      */
        struct SREGS syssegs ;

        iregs->h.ah = GETVARS ;                 /* Function 0x52           */
        intdosx(iregs, iregs, &syssegs) ;

        *(long *)(&vptr) = (((long)syssegs.es) << 16)+(iregs->x.bx & 0xffffL) ;

#ifdef __WATCOMC__  /* <= copied one byte past the structure, and past SysVars */
        for (i=0 ; i < sizeof(*pSVars) ; i++)
#else
        for (i=0 ; i <= sizeof(*pSVars) ; i++)
#endif
                *((char *)pSVars+i) = *((char far *)vptr+i) ;

}




PutVars(pSVars)
struct sysVarsType *pSVars ;
{
        struct sysVarsType far *vptr ;
        int i ;

        union REGS ir ;
        register union REGS *iregs = &ir ;      /* Used for DOS calls      */
        struct SREGS syssegs ;

        iregs->h.ah = GETVARS ;                 /* Function 0x52           */
        intdosx(iregs, iregs, &syssegs) ;

        *(long *)(&vptr) = (((long)syssegs.es) << 16)+(iregs->x.bx & 0xffffL) ;

#ifdef __WATCOMC__  /* <= copied one byte past the structure, and past SysVars */
        for (i=0 ; i < sizeof(*pSVars) ; i++)
#else
        for (i=0 ; i <= sizeof(*pSVars) ; i++)
#endif
                *((char far *)vptr+i) = *((char *)pSVars+i) ;

}
