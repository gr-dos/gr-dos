/*
 * HELP: show GR-DOS's command help, from GRDOS.HLP (issue #27,
 * docs/help.md).
 *
 *   HELP           the list of topics
 *   HELP topic     one topic: a command (XCOPY, XCOPY.EXE, DIR), a
 *                  CONFIG.SYS command (FILES), or a guide (START)
 *
 * GRDOS.HLP is made by scripts/mkhelp from help/topics. Each topic starts
 * with a line "@@NAME ALIAS...", and runs to the next one; INDEX is the
 * list of topics. HELP looks for GRDOS.HLP in its own directory (from the
 * program name DOS puts after the environment), then in the current
 * directory, then in each directory of PATH.
 *
 * On the screen, HELP stops after each screenful: any key goes on, Q or
 * Esc stops. Redirected (HELP XCOPY >PRN, HELP DIR | FIND "/W") it does
 * not stop.
 *
 * Exit status: 0, shown; 1, no such topic; 2, no GRDOS.HLP; 3, a bad
 * parameter.
 *
 * Built with Open Watcom C and libc16, like GRVER (Makefile), for the 8086.
 */

#include <ctype.h>
#include <dos.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

enum { SHOWN = 0, NO_TOPIC = 1, NO_FILE = 2, BAD_PARAMETER = 3 };

#define HELP_FILE   "GRDOS.HLP"
#define LINE_MAX    256
#define PATH_MAX    128
#define SCREEN_ROWS 25
#define SCREEN_COLS 80

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

    if (n >= PATH_MAX)
        return NULL;
    strcpy(path, dir);
    if (n > 0 && path[n - 1] != '\\' && path[n - 1] != ':')
        strcat(path, "\\");
    strcat(path, HELP_FILE);
    return fopen(path, "r");
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

/* Shows the topic want; 0 if it is not in the file. */
static int topic(FILE *fp, const char *want)
{
    char line[LINE_MAX];
    int in = 0;

    while (fgets(line, sizeof line, fp)) {
        if (line[0] == '@' && line[1] == '@') {
            if (in)
                return 1;
            in = names(line, want);
            continue;
        }
        if (in && show(line))
            return 1;
    }
    return in;
}

int main(int argc, char **argv)
{
    char want[PATH_MAX];
    const char *arg = argc > 1 ? argv[1] : "INDEX";
    char *dot;
    FILE *fp;
    unsigned i;

    if (argc > 2 || strlen(arg) >= sizeof want || arg[0] == '/') {
        err("Usage: HELP [topic]\n");
        return BAD_PARAMETER;
    }
    for (i = 0; arg[i]; i++)
        want[i] = (char)toupper((unsigned char)arg[i]);
    want[i] = '\0';

    if ((fp = open_help()) == NULL) {
        err("Cannot find " HELP_FILE "\n");
        return NO_FILE;
    }
    paging = to_console();
    if (topic(fp, want)) {
        fclose(fp);
        return SHOWN;
    }
    /* XCOPY.EXE is XCOPY; a topic may name its extension (CONFIG.SYS) */
    dot = strchr(want, '.');
    if (dot) {
        *dot = '\0';
        fseek(fp, 0L, SEEK_SET);
        if (topic(fp, want)) {
            fclose(fp);
            return SHOWN;
        }
        *dot = '.';
    }
    fclose(fp);
    err("No help for ");
    err(want);
    err(". Type HELP for the list of topics.\n");
    return NO_TOPIC;
}
