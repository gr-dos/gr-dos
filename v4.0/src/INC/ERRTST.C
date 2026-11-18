/*  0  */
#include "comsub.h"
#include "dpb.h"
#include <dos.h>
#include "jointype.h"

#ifdef __WATCOMC__
/* libc16's declarations, __cdecl, of the C library functions ERRTST.C
   calls without including their headers */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#endif

extern unsigned char *com_substr() ;            /* ;AN000; DBCS enabled */
extern char getdrv() ;

#ifdef __WATCOMC__
/* JOIN's and SUBST's own: Microsoft C made the two definitions one
   communal variable, Watcom C would define it twice */
extern union REGS inregs, outregs;
#else
union REGS inregs, outregs;                     /* ;AN000; Regs for Int21 */
#endif
struct SREGS segregs;                           /* ;AN000; Segment regs for Int21 */

#define GET_DBCS_VEC   0x6300                   /* ;AN000; Int21 Get DBCS Vector */
#ifdef __WATCOMC__  /* the vector ends with a word of 0; (unsigned)"00" is the
                       string's address, which the loop looked for past the end */
#define DBLNULL        0
#else
#define DBLNULL        "00"                     /* ;AN000; */
#endif
#define NULL           0                        /* ;AN000; */

#define KANJI   TRUE

/* return FALSE if drive is valid AND the path is not a prefix of a non-root
 * current directory.
 */
char fPathErr(p)
char *p ;
{
        char buf[MAXARG] ;
        int d ;
#ifdef KANJI
        char *p1;
#endif

        if (p[1] == ':')
                d = *p-'A'+1 ;
        else
                d = 0 ;

        if (curdir(buf, d) == -1)       /* drive is invalid => error       */
                return(TRUE) ;

        if (strlen(buf) == 3)           /* current directory is root => OK */
                return(FALSE) ;

        if (strpre(p, buf)) {
#ifdef KANJI
                p1 = p;
                while (*p1 != NULL) {
                    if(testkanj(*p1 & 0xFF))
                        p1 += 2 ;
                    else
                        if((*p1++ == '\\') && (*p1 == NULL))
                                return(TRUE) ;
                }
#else
                if (p[strlen(p)-1] == '\\') /* prefix matched, prefix had...*/
                        return(TRUE) ;      /* ...trailing / => valid ...   */
                                           /* ...prefix => ERROR           */
#endif
                d = buf[strlen(p)] ;
                if (d == 0 || d == '\\') /* prefix matched,... */
                        return(TRUE) ;      /* ...prefix had no trailing /, */
                                           /* ...next char was / => ...    */
                                           /* ...valid prefix => ERROR     */
        } ;

        return(FALSE) ;    /* drive letter good and not valid prefix => OK  */
}


strpre(pre, tot)
        char    *pre;
        char    *tot;
{
        return(!strncmp(pre, tot, strlen(pre)));
}



Fatal(p)
char *p ;
{
#ifdef __WATCOMC__  /* libc16 has no printf */
        fputs(p, stdout) ;
        fputs("\n", stdout) ;
#else
        printf("%s\n", p) ;
#endif
        exit(1) ;
}




ffirst(pb, attr, pfbuf)
char *pb ;
int attr ;
struct findType *pfbuf ;
{
        union REGS regs ;

        /* set DMA to point to buffer */

        regs.h.ah = 0x1A ;
        regs.x.dx = (unsigned) pfbuf ;
        intdos (&regs, &regs) ;

        /* perform system call */

        regs.h.ah = 0x4E ;
        regs.x.cx = attr ;
        regs.x.dx = (unsigned) pb ;
        intdos (&regs, &regs) ;

        return (regs.x.cflag ? -1 : 0) ;
}

fnext (pfbuf)
struct findType *pfbuf;
{
    union REGS regs;

    /* set DMA to point to buffer */
    regs.h.ah = 0x1A;
    regs.x.dx = (unsigned) pfbuf;
    intdos (&regs, &regs);
    /* perform system call */
    regs.h.ah = 0x4F;
    intdos (&regs, &regs);
    return (regs.x.cflag ? -1 : 0) ;
}


char *strbscan(str, class)
char *str ;
char *class ;
{
        char *p ;

        p = com_substr(str, class) ;            /* :AN000; DBCS function */
        return((p == NULL) ? (str + strlen(str)) : p) ;
}





/* curdir.c - return text of current directory for a particular drive */


curdir (dst, drive)
char *dst ;
int drive ;
{
    union REGS regs ;

    *dst++ = PathChr ;
    regs.h.ah = 0x47 ;
    regs.h.dl = drive ;
    regs.x.si = (unsigned) dst ;
    intdos (&regs, &regs) ;
    return(regs.x.cflag ? -1 : 0) ;
}




/*
   rootpath
*/

/*** rootpath  --  convert a pathname argument to root based cannonical form
 *
 * rootpath determines the current directory, appends the path argument (which
 * may affect which disk the current directory is relative to), and qualifies
 * "." and ".." references.  The result is a complete, simple, path name with
 * drive specifier.
 *
 * If the relative path the user specifies does not include a drive spec., the
 * default drive will be used as the base.  (The default drive will never be
 * changed.)
 *
 *  entry: relpath  -- pointer to the pathname to be expanded
 *         fullpath -- must point to a working buffer, see warning
 *   exit: fullpath -- the full path which results
 * return: true if an error occurs, false otherwise
 *
 * calls: curdir, getdrv
 *
 * warning: fullpath must point to a working buffer large enough to hold the
 *          longest possible relative path argument plus the longest possible
 *          current directory path.
 *
 */
int rootpath(relpath, fullpath)
char *relpath ;
char *fullpath ;
{
        int drivenum ;
        char tempchar;
        register char *lead, *follow ;
        char *p1, *p2;


        /* extract drive spec */
        drivenum = getdrv() ;
        if ((*relpath != NULL) && (relpath[1] == COLON)) {
                drivenum = relpath[0] - 'A' ;
                relpath += 2 ;
        }
        fullpath[0] = (char) ('A' + drivenum) ;
        fullpath[1] = COLON ;

        /* append relpath to fullpath/base */
        if (*relpath == PathChr) {
                /* relpath starts at base */
                strcpy(fullpath+2, relpath) ;
        }
        else {
                /* must get base path first */
                if (curdir(fullpath+2, drivenum+1))
                        return(TRUE) ;                  /* terrible error */
                if ((*relpath != ASCNULL) && (strlen(fullpath) > 3))
                        strcat(fullpath, "\\") ;
                strcat(fullpath, relpath) ;
        }


        /* convert path to cannonical form */
        lead = fullpath ;
        while(*lead != ASCNULL) {
                /* mark next path segment */
                follow = lead ;
                lead = (char *) com_substr(follow+1, "\\") ;    /* ;AC000; */
                if (lead == NULL)
                        lead = fullpath + strlen(fullpath) ;
                tempchar = *lead ;
                if (tempchar == PathChr)
                        tempchar = BACKSLASH ;   /* make breaks uniform */
                *lead = ASCNULL ;

                /* "." segment? */
                if (strcmp(follow+1, ".") == 0) {
                        *lead = tempchar ;
                        strcpy(follow, lead) ;  /* remove "." segment */
                        lead = follow ;
                }

                /* ".." segment? */
                else if (strcmp(follow+1, "..") == 0) {
                        *lead = tempchar ;
                        tempchar = *follow ;
                        *follow = NULL ;
                        p2 = fullpath - 1 ;
                        while(*(p2=strbscan(p1=p2+1,"\\")) != NULL) ;
                        /* p1 now points to the start of the previous element */
                        *follow = tempchar ;
                        if(p1 == fullpath)
                            return(TRUE) ;      /* tried to .. the root */
                        follow = p1 - 1 ;       /* follow points to path sep */
                        strcpy(follow, lead) ;         /* remove ".." segment */
                        lead = follow ;
                }

                /* normal segment */
                else
                        *lead = tempchar ;
        }
        if (strlen(fullpath) == 2)  /* 'D:' or some such */
                strcat(fullpath, "\\") ;

        return(FALSE) ;
}


/* getdrv - return current drive as a character */


char getdrv()
{
    union REGS regs ;

    regs.h.ah = CURDISK ;               /* Function 0x19 */
    intdos (&regs, &regs) ;
    return(regs.h.al) ;
}

testkanj(c)
unsigned char c;
{
  char   fix_es_reg[1];                         /* ;AN000; Fixes es reg after "far" */
  char far * fptr;                              /* ;AN000; Pts to DBCS vector */
  unsigned * ptr;                               /* ;AN000; Input to fptr */
  unsigned int got_dbcs;                        /* ;AN000; Flag */

  inregs.x.ax = GET_DBCS_VEC;                   /* ;AN000; 0x6300 */
  intdosx(&inregs,&outregs,&segregs);           /* ;AN000; Int21 */

  got_dbcs = FALSE;                             /* ;AN000; Initialize */

  ptr  = (unsigned *)&fptr;                     /* ;AN000; Int21 returns DS:SI */
  *ptr = outregs.x.si;                          /* ;AN000;   as ptr to DBCS    */
  ptr++;                                        /* ;AN000;   vector, now fill  */
  *ptr = segregs.ds;                            /* ;AN000;   in our pointer    */

  for (fptr; *(unsigned far *)fptr != (unsigned)DBLNULL; fptr += 2) /* ;AN000; */
  {                                             /* ;AN000; */
    if ( (c >= (char)*fptr) && (c <= (char)*(fptr+1)) ) /* ;AN000; Is char */
    {                                           /* ;AN000;  within the range? */
      got_dbcs = TRUE;                          /* ;AN000; Char is DBCS */
      break;                                    /* ;AN000; */
    }                                           /* ;AN000; */
  }                                             /* ;AN000; */

  strcpy(fix_es_reg,NULL);                      /* ;AN000; Repair ES reg */
  return(got_dbcs);                             /* ;AN000; */
}

#ifdef __WATCOMC__
/* com_substr, from COMSUBS.LIB, which is Microsoft C object code only:
 * the first occurrence of the string t in the string s, or NULL. A match
 * whose previous byte is a DBCS lead byte is the second half of a double
 * byte character, and is skipped. As COMSUBS.LIB's, it finds a substring,
 * not one of a set of characters: strbscan(p, "/\\") looks for "/\". */
unsigned char *com_substr(s, t)
unsigned char *s ;
unsigned char *t ;
{
        int ls = strlen((char *)s) ;
        int lt = strlen((char *)t) ;
        int i ;

        if (lt > ls)
                return(NULL) ;
        for (i = 0; i <= ls - lt; i++)
                if (s[i] == t[0] && (i == 0 || !testkanj(s[i-1])) &&
                    strncmp((char *)s+i, (char *)t, lt) == 0)
                        return(s+i) ;
        return(NULL) ;
}
#endif
