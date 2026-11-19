/*
 * HELP: show GR-DOS's command help, from GRDOS.HLP (issue #27,
 * docs/help.md).
 *
 *   HELP           the list of topics
 *   HELP topic     one topic: a command (XCOPY, XCOPY.EXE, DIR), a
 *                  CONFIG.SYS command (FILES), or a guide (START)
 *   /P             on the screen, HELP's own pager, not LESS
 *
 * GRDOS.HLP is made by scripts/mkhelp from help/topics. Each topic starts
 * with a line "@@NAME ALIAS...", and runs to the next one; INDEX is the
 * list of topics. HELP looks for GRDOS.HLP in its own directory (from the
 * program name DOS puts after the environment), then in the current
 * directory, then in each directory of PATH.
 *
 * On the screen, HELP shows the topic with LESS.EXE (gr-dos/less16 0.02
 * or later), found as DOS finds a command: in the current directory, then
 * in each directory of PATH (issue #86). LESS is given GRDOS.HLP's path and
 * the byte range of the topic's text (--start, --end), so it shows that
 * topic and nothing else, scrolling both ways, with no file written. If
 * there is no LESS, it cannot be run (too little memory, say), or it ends
 * with an error (1 or 2: a LESS without --start, or a range it refuses),
 * HELP shows the topic itself, as with /P: it stops after each screenful,
 * any key goes on, Q or Esc stops. Redirected (HELP XCOPY >PRN, HELP DIR |
 * FIND "/W") it neither runs LESS nor stops.
 *
 * Exit status: 0, shown; 1, no such topic; 2, no GRDOS.HLP; 3, a bad
 * parameter.
 *
 * Built with Open Watcom C and libc16, like GRVER (Makefile), for the 8086.
 */

#include <ctype.h>
#include <dos.h>
#include <process.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { SHOWN = 0, NO_TOPIC = 1, NO_FILE = 2, BAD_PARAMETER = 3 };

#define HELP_FILE   "GRDOS.HLP"
#define LINE_MAX    256
#define PATH_MAX    128
#define SCREEN_ROWS 25
#define SCREEN_COLS 80
#define LESS        "LESS.EXE"

/* The GRDOS.HLP open_help found, for LESS. */
static char help_path[PATH_MAX + sizeof HELP_FILE];

static void say(const char *s)
{
    fputs(s, stdout);
}

static void err(const char *s)
{
    fputs(s, stderr);
}

/* Whether handle 1 is the console (INT 21h 4400h: a device, the console
   output). */
static int to_console(void)
{
    union REGS r;

    r.x.ax = 0x4400;
    r.x.bx = 1;
    intdos(&r, &r);
    return !r.x.cflag && (r.x.dx & 0x82) == 0x82;
}

/* A key from the keyboard, without echo (INT 21h 08h); an extended key's
   second byte is read too. */
static int key(void)
{
    int c = bdos(0x08, 0, 0) & 0xFF;

    if (c == 0)
        bdos(0x08, 0, 0);
    return c;
}

static int paging, rows;

/* Writes a line, and on the screen stops when it is full. Returns 0 to go
   on, 1 to stop. */
static int show(const char *line)
{
    unsigned len = strlen(line);
    int c;

    say(line);
    if (!paging)
        return 0;
    /* The line's rows on an 80-column screen; its \n is not one. */
    if (len > 0 && line[len - 1] == '\n')
        len--;
    rows += len == 0 ? 1 : (len + SCREEN_COLS - 1) / SCREEN_COLS;
    if (rows < SCREEN_ROWS - 1)
        return 0;
    say("-- More: any key, Q or Esc to stop --");
    c = key();
    say("\r                                     \r");
    rows = 0;
    return c == 'q' || c == 'Q' || c == 0x1B;
}

/* The directory of this program, from the name DOS gives it after the
   environment (DOS 3.0 and later), into dir, with its trailing \. Empty if
   there is none. */
static void own_directory(char *dir)
{
    unsigned envseg = *(unsigned __far *)MK_FP(_psp, 0x2C);
    const char __far *p = (const char __far *)MK_FP(envseg, 0);
    unsigned i, last = 0;

    dir[0] = '\0';
    if (envseg == 0)
        return;
    /* The variables, each ended by a 0, then another 0 */
    while (*p) {
        while (*p)
            p++;
        p++;
    }
    p++;
    /* A word, the count of strings that follow (1), then the name */
    if (p[0] != 1 || p[1] != 0)
        return;
    p += 2;
    for (i = 0; p[i] && i < PATH_MAX - 1; i++) {
        dir[i] = p[i];
        if (p[i] == '\\' || p[i] == ':')
            last = i + 1;
    }
    dir[last] = '\0';
}

/* Opens dir + GRDOS.HLP, dir being empty or ending in \ or :. */
static FILE *open_in(const char *dir)
{
    char path[PATH_MAX + sizeof HELP_FILE];
    unsigned n = strlen(dir);
    FILE *fp;

    if (n >= PATH_MAX)
        return NULL;
    strcpy(path, dir);
    if (n > 0 && path[n - 1] != '\\' && path[n - 1] != ':')
        strcat(path, "\\");
    strcat(path, HELP_FILE);
    fp = fopen(path, "r");
    if (fp)
        strcpy(help_path, path);
    return fp;
}

static FILE *open_help(void)
{
    char dir[PATH_MAX];
    const char *path;
    FILE *fp;

    own_directory(dir);
    if (dir[0] && (fp = open_in(dir)) != NULL)
        return fp;
    if ((fp = open_in("")) != NULL)
        return fp;
    path = getenv("PATH");
    while (path && *path) {
        unsigned n = 0;

        while (path[n] && path[n] != ';')
            n++;
        if (n > 0 && n < PATH_MAX) {
            memcpy(dir, path, n);
            dir[n] = '\0';
            if ((fp = open_in(dir)) != NULL)
                return fp;
        }
        path += n;
        if (*path == ';')
            path++;
    }
    return NULL;
}

/* Whether the topic line "@@NAME ALIAS..." names want (upper case). */
static int names(const char *line, const char *want)
{
    const char *p = line + 2;
    unsigned n = strlen(want);

    for (;;) {
        unsigned len = 0;

        while (*p == ' ')
            p++;
        while (p[len] && p[len] != ' ' && p[len] != '\n')
            len++;
        if (len == 0)
            return 0;
        if (len == n && strncmp(p, want, n) == 0)
            return 1;
        p += len;
    }
}

/* A topic's text: the file's bytes from start to end (exclusive), after
   its @@ line and up to the next one or the end of the file, and its name,
   the first on its @@ line. */
struct topic {
    long start, end;
    char name[16];
};

/* Finds the topic want, from the start of the file; 0 if it is not there,
   or the file cannot be read. ftell counts the file's bytes, in text mode
   too (libc16), so start and end are offsets in GRDOS.HLP. It is asked
   only within the topic, so the other topics are read as fast as before. */
static int find(FILE *fp, const char *want, struct topic *t)
{
    char line[LINE_MAX];
    int in = 0;

    if (fseek(fp, 0L, SEEK_SET) != 0)
        return 0;
    for (;;) {
        long here = in ? ftell(fp) : 0;

        if (here < 0)
            return 0;
        if (!fgets(line, sizeof line, fp) || (line[0] == '@' && line[1] == '@' && in)) {
            t->end = here;
            return in;
        }
        if (line[0] == '@' && line[1] == '@' && names(line, want)) {
            unsigned i;

            for (i = 0; i < sizeof t->name - 1 && line[2 + i] > ' '; i++)
                t->name[i] = line[2 + i];
            t->name[i] = '\0';
            if ((t->start = ftell(fp)) < 0)
                return 0;
            in = 1;
        }
    }
}

/* Shows the topic's text itself, a line at a time. */
static void page(FILE *fp, const struct topic *t)
{
    char line[LINE_MAX];

    if (fseek(fp, t->start, SEEK_SET) != 0)
        return;
    while (fgets(line, sizeof line, fp) && !(line[0] == '@' && line[1] == '@'))
        if (show(line))
            return;
}

/* option, then n in decimal, into buf. */
static char *number(char *buf, const char *option, long n)
{
    char digits[12];
    unsigned i = 0;

    do
        digits[i++] = (char)('0' + n % 10);
    while ((n /= 10) > 0);
    strcpy(buf, option);
    buf += strlen(buf);
    while (i > 0)
        *buf++ = digits[--i];
    *buf = '\0';
    return buf;
}

/* Shows the topic with LESS: 1 if LESS ran and ended normally (0), else 0,
   having shown nothing, for HELP to show it itself. The help file is
   closed while LESS runs, so LESS has a file handle of its own. */
static int less(const struct topic *t)
{
    char start[24], end[24], label[sizeof t->name + 8];
    char *argv[6];

    number(start, "--start=", t->start);
    number(end, "--end=", t->end);
    strcpy(label, "--label=");
    strcat(label, t->name);
    argv[0] = LESS;
    argv[1] = start;
    argv[2] = end;
    argv[3] = label;
    argv[4] = help_path;
    argv[5] = NULL;
    fflush(stdout);
    return spawnvp(P_WAIT, LESS, argv) == 0;
}

int main(int argc, char **argv)
{
    char want[PATH_MAX];
    const char *arg = "INDEX", *topic_arg = NULL;
    int own_pager = 0, n;
    struct topic t;
    char *dot;
    FILE *fp;
    unsigned i;

    /* /P, anywhere, and at most one topic */
    for (n = 1; n < argc; n++) {
        const char *a = argv[n];

        if (a[0] == '/' && (a[1] == 'P' || a[1] == 'p') && a[2] == '\0' && !own_pager)
            own_pager = 1;
        else if (a[0] != '/' && !topic_arg && strlen(a) < sizeof want)
            topic_arg = a;
        else {
            err("Usage: HELP [/P] [topic]\n");
            return BAD_PARAMETER;
        }
    }
    if (topic_arg)
        arg = topic_arg;
    for (i = 0; arg[i]; i++)
        want[i] = (char)toupper((unsigned char)arg[i]);
    want[i] = '\0';

    if ((fp = open_help()) == NULL) {
        err("Cannot find " HELP_FILE "\n");
        return NO_FILE;
    }
    if (!find(fp, want, &t)) {
        /* XCOPY.EXE is XCOPY; a topic may name its extension (CONFIG.SYS) */
        dot = strchr(want, '.');
        if (dot)
            *dot = '\0';
        if (!dot || !find(fp, want, &t)) {
            if (dot)
                *dot = '.';
            fclose(fp);
            err("No help for ");
            err(want);
            err(". Type HELP for the list of topics.\n");
            return NO_TOPIC;
        }
    }
    paging = to_console();
    if (paging && !own_pager) {
        fclose(fp);
        if (less(&t))
            return SHOWN;
        if ((fp = fopen(help_path, "r")) == NULL) {
            err("Cannot find " HELP_FILE "\n");
            return NO_FILE;
        }
    }
    page(fp, &t);
    fclose(fp);
    return SHOWN;
}
