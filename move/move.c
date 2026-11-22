/*
 * MOVE: move files, and rename directories, as MS-DOS 6.22's MOVE does
 * (issue #106, docs/move.md).
 *
 *   MOVE [/Y | /-Y] [drive:][path]filename[,...] destination
 *
 * Each source, which may have wildcards, is renamed into the destination
 * (INT 21h 56h); where DOS cannot rename it (another drive, or a
 * directory to another parent) it is copied, with its date, time and
 * attributes, and deleted once the copy is complete. A directory is
 * renamed only within its parent. The output, questions and errorlevels
 * are those of MS-DOS 6.22's MOVE.EXE, against which tests/move checks it,
 * and so are the order and kind of its DOS calls, so that DOS's
 * "Abort, Retry, Fail?" comes when 6.22's does. Unlike 6.22's, MOVE never
 * deletes or replaces a file that is the source under another name (SUBST,
 * JOIN), and deletes a copied source only when the copy is its size.
 *
 * Exit status: 0, every file moved (or not replaced, when asked); 1,
 * otherwise, or a parameter error.
 *
 * Built with Open Watcom C and libc16, like GRVER (Makefile). libc16 has
 * no printf (its decision 3): the messages are put together with fputs.
 */

#include <conio.h>
#include <ctype.h>
#include <dos.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define PATHLEN 260
#define MAXPATH 66                  /* DOS's longest path, for directories */

#define E_NOENT  2                  /* Microsoft C's errno values */
#define E_ACCES  13
#define E_DRIVE  19

static int prompt = 1;              /* ask before replacing or creating */
static int failed;                  /* files not moved */
static int dest_attr;               /* the destination's attributes */
static char dest[PATHLEN];          /* the destination, in full */
static char src[PATHLEN];           /* the source being moved, in full */
static char target[PATHLEN];        /* where it goes */
static char scratch[PATHLEN];
static char found[PATHLEN];         /* a source found by a wildcard */
static char sources[512];           /* the sources, separated by commas */
static int err;                     /* the error of the last DOS call */

static void say(const char *s)
{
    fputs(s, stdout);
}

static void ask_out(const char *s)
{
    fputs(s, stderr);
}

static int is_slash(int c)
{
    return c == '\\' || c == '/';
}

static const char *strerr(int e)
{
    switch (e) {
    case E_NOENT: return "No such file or directory";
    case E_ACCES: return "Permission denied";
    case E_DRIVE: return "Invalid Drive";
    default:      return "Unknown error";
    }
}

/* Microsoft C's errno for a DOS error code. */
static void dos_error(unsigned code)
{
    if (code == 2 || code == 3 || code == 15 || code == 18)
        err = E_NOENT;
    else
        err = E_ACCES;
}

/* "Cannot move NAME - REASON" */
static void cannot(const char *name, int e)
{
    say("Cannot move ");
    say(name);
    say(" - ");
    say(strerr(e));
    say("\n");
    failed++;
}

static void usage_error(const char *msg, const char *arg)
{
    say(msg);
    if (arg) {
        say(" - ");
        say(arg);
    }
    say("\n");
    exit(1);
}

static void help(void)
{
    say("Moves files, and renames directories.\n"
        "\n"
        "MOVE [/Y | /-Y] [drive:][path]filename[,...] destination\n"
        "MOVE [/Y | /-Y] [drive:][path]dirname newname\n"
        "\n"
        "  filename     The file or files to move. Wildcards (* and ?) may be\n"
        "               used, and several names separated by commas.\n"
        "  destination  A drive, a directory or both, where the files go; for\n"
        "               one file, a new name too. Several files need a\n"
        "               directory, which MOVE offers to create.\n"
        "  dirname      A directory to rename, in its own parent directory.\n"
        "  /Y           Replaces files and creates directories without asking.\n"
        "  /-Y          Asks first, as MOVE does at the prompt.\n"
        "\n"
        "From a batch file MOVE replaces files without asking, and so it does\n"
        "with /Y in the COPYCMD environment variable; /-Y asks again.\n");
}

/* ---- DOS calls, each as Microsoft C's MOVE.EXE makes it ---- */

/* INT 21h 06h with DL = FFh: a waiting character in AL, and the flags in
 * AH, whose zero flag (40h) is set when there was none. */
extern unsigned dos_direct_input(void);
#pragma aux dos_direct_input = \
    "mov ah,6" "mov dl,0ffh" "int 21h" "mov dl,al" "lahf" "mov al,dl" \
    value [ax] modify [dx];

static int dos_path_call(unsigned ax, const char *path, unsigned cx)
{
    union REGS r;

    r.x.ax = ax;
    r.x.cx = cx;
    r.x.dx = (unsigned)path;
    intdos(&r, &r);
    if (r.x.cflag) {
        dos_error(r.x.ax);
        return -1;
    }
    return (int)r.x.cx;
}

/* The attributes of PATH (INT 21h 4300h), or -1. */
static int get_attr(const char *path)
{
    return dos_path_call(0x4300, path, 0);
}

static int get_dcwd(int drive, char *out);

/*
 * The destination's attributes: a root directory ("x:\") is one, as MS-DOS
 * 6.22's INT 21h 4300h says, where MS-DOS 4.00's (and GR-DOS's) does not.
 */
static int dest_attributes(const char *path)
{
    if (strlen(path) == 3 && path[1] == ':' && is_slash(path[2])
        && get_dcwd(tolower((unsigned char)path[0]) - 'a' + 1, scratch) == 0)
        return _A_SUBDIR;
    return get_attr(path);
}

static int set_attr(const char *path, unsigned attr)
{
    return dos_path_call(0x4301, path, attr) < 0 ? -1 : 0;
}

static int dos_remove(const char *path)
{
    return dos_path_call(0x4100, path, 0) < 0 ? -1 : 0;
}

static int dos_mkdir(const char *path)
{
    return dos_path_call(0x3900, path, 0) < 0 ? -1 : 0;
}

static int dos_rename(const char *from, const char *to)
{
    union REGS r;
    struct SREGS s;

    segread(&s);
    s.es = s.ds;
    r.h.ah = 0x56;
    r.x.dx = (unsigned)from;
    r.x.di = (unsigned)to;
    intdosx(&r, &r, &s);
    if (r.x.cflag) {
        dos_error(r.x.ax);
        return -1;
    }
    return 0;
}

/* The current directory of DRIVE (1 = A:), as "x:\path", in lower case. */
static int get_dcwd(int drive, char *out)
{
    union REGS r;

    if (drive == 0) {
        r.h.ah = 0x19;
        intdos(&r, &r);
        drive = r.h.al + 1;
    }
    out[0] = (char)('a' - 1 + drive);
    out[1] = ':';
    out[2] = '\\';
    r.h.ah = 0x47;
    r.h.dl = (unsigned char)drive;
    r.x.si = (unsigned)(out + 3);
    intdos(&r, &r);
    if (r.x.cflag) {
        err = E_DRIVE;
        return -1;
    }
    strlwr(out + 3);
    return 0;
}

/* DOS's own name for PATH (INT 21h 60h), which sees through SUBST and JOIN. */
static int truename(const char *path, char *out)
{
    union REGS r;
    struct SREGS s;

    segread(&s);
    s.es = s.ds;
    r.h.ah = 0x60;
    r.x.si = (unsigned)path;
    r.x.di = (unsigned)out;
    intdosx(&r, &r, &s);
    return r.x.cflag ? -1 : 0;
}

/* ---- names ---- */

/*
 * PATH in full: its drive, the current directory of that drive if it is
 * relative, and . and .. taken out, in lower case; 0, or -1 for a drive
 * DOS does not have or a .. above the root. PATH's own drive letter is
 * made lower case too, as 6.22's MOVE does, and shows so in its messages.
 */
static int full_path(char *path, char *out)
{
    char *in = path, *start, *w, *r, *sep, c;
    int drive = 0;

    if (in[0] && in[1] == ':') {
        if (isupper((unsigned char)in[0]))
            in[0] = (char)(in[0] + 32);
        drive = in[0] - 'a' + 1;
        in += 2;
    }
    if (is_slash(in[0]) && is_slash(in[1])) {
        if (strlen(in) >= PATHLEN) {
            err = E_NOENT;
            return -1;
        }
        strcpy(out, in);
        start = out;
    } else {
        if (get_dcwd(drive, out) < 0)
            return -1;
        start = out + 2;
        if (in[0] == '.' && (in[1] == '\0' || (is_slash(in[1]) && in[2] == '\0')))
            return 0;
        if (strlen(start) + strlen(in) + 2 >= PATHLEN) {
            err = E_NOENT;
            return -1;
        }
        if (is_slash(in[0]))
            strcpy(start, in);
        else {
            if (!is_slash(start[strlen(start) - 1]))
                strcat(start, "\\");
            strcat(start, in);
        }
    }

    /* Each part of the path, copied back over itself without . and .. */
    w = r = start;
    for (;;) {
        sep = strpbrk(r, "\\/");
        if (sep == NULL)
            sep = r + strlen(r);
        c = *sep;
        *sep = '\0';
        if (strcmp(r, ".") == 0 || strcmp(r, "..") == 0) {
            int back = r[1] == '.' ? 2 : 1;
            while (back--) {
                do {
                    if (--w < start)
                        return -1;
                } while (!is_slash(*w));
            }
        } else {
            memmove(w, r, strlen(r));
            w += strlen(r);
        }
        r = sep + 1;
        *w++ = is_slash(c) ? '\\' : c;
        if (c == '\0')
            break;
    }
    if (strlen(out) == 2)
        strcat(out, "\\");
    strlwr(out);
    return 0;
}

/* The last part of PATH, after its drive and directories. */
static const char *base_name(const char *path)
{
    const char *p, *b = path;

    for (p = path; *p; p++)
        if (*p == '\\' || *p == '/' || *p == ':')
            b = p + 1;
    return b;
}

/* The longest path in directory PATH and its subdirectories (PATH is
 * extended in place, and given back as it was). */
static int depth(char *path)
{
    struct find_t f;
    size_t n = strlen(path);
    int best = (int)n, d;

    if (n + 14 >= PATHLEN)
        return best;
    strcat(path, "\\*.*");
    if (_dos_findfirst(path, _A_HIDDEN | _A_SYSTEM | _A_SUBDIR, &f) == 0) {
        do {
            if ((f.attrib & _A_SUBDIR) && strcmp(f.name, ".") != 0 && strcmp(f.name, "..") != 0) {
                path[n] = '\0';
                strcat(path, "\\");
                strcat(path, strlwr(f.name));
                d = depth(path);
                if (d > best)
                    best = d;
            }
        } while (_dos_findnext(&f) == 0);
    }
    path[n] = '\0';
    return best;
}

/* ---- the questions ---- */

/*
 * Asks until Y or N (or A, with ALL) is followed by Enter, and returns it
 * in lower case: the key shown, and the cursor kept on it. Ctrl-Z is N;
 * Ctrl-C, through DOS, ends MOVE. Keys already typed are thrown away.
 */
static int answer(int all)
{
    int c, a = 0;
    char echo[3];

    while (!(dos_direct_input() & 0x4000))
        ;
    for (;;) {
        c = getch();
        if (isupper(c))
            c = tolower(c);
        if (c == '\r' && (a == 'y' || a == 'n' || (all && a == 'a'))) {
            ask_out("\n");
            return a;
        }
        if (c == 3 || c == 0x1A)
            return 'n';
        if (c == 'y' || c == 'n' || (all && c == 'a')) {
            echo[0] = (char)c;
            echo[1] = '\b';
            echo[2] = '\0';
            ask_out(echo);
            a = c;
        }
    }
}

/* Makes directory PATH, and those it is in, as needed. */
static int make_dirs(char *path)
{
    int a = get_attr(path);
    char *p, c;

    if (a >= 0)
        return (a & _A_SUBDIR) ? 0 : -1;
    if (dos_mkdir(path) == 0)
        return 0;
    p = NULL;
    {
        char *q;
        for (q = path; *q; q++)
            if (is_slash(*q))
                p = q;
    }
    if (p == NULL)
        return -1;
    c = *p;
    *p = '\0';
    if (make_dirs(path) != 0) {
        *p = c;
        return -1;
    }
    *p = c;
    if (p[1] == '\0')
        return 0;
    return dos_mkdir(path);
}

/* ---- moving ---- */

static int dos_handle_call(unsigned ax, int handle, union REGS *r)
{
    r->x.ax = ax;
    r->x.bx = (unsigned)handle;
    intdos(r, r);
    return r->x.cflag ? -1 : 0;
}

/* The size of the file open as HANDLE, or -1. */
static long file_size(int handle)
{
    union REGS r;
    long size;

    r.x.cx = 0;
    r.x.dx = 0;
    if (dos_handle_call(0x4202, handle, &r) < 0)
        return -1;
    size = ((long)r.x.dx << 16) | r.x.ax;
    r.x.cx = 0;
    r.x.dx = 0;
    dos_handle_call(0x4200, handle, &r);
    return size;
}

/*
 * Copies FROM to TO, with its date, time and attributes: NULL, or why not.
 * The copy is checked to be the size of the source. If it fails, what it
 * created is deleted; a TO it did not create is left alone.
 */
static const char *copy_file(const char *from, const char *to)
{
    static const char no_memory[] = "not enough memory";
    const char *why = no_memory;
    unsigned size = 0x2800, n, written, cx, dx, attr;
    char *buf;
    int in = -1, out = -1, a, created = 0, attr_set = 0;
    long total = 0, expect;
    union REGS r;

    buf = malloc(size);
    if (buf == NULL) {
        size = 0x400;
        buf = malloc(size);
        if (buf == NULL)
            return why;
    }
    why = "Unable to open source";
    if (_dos_open(from, 0x40, &in) != 0) {
        in = -1;
        goto done;
    }
    why = "Unable to create destination";
    if (_dos_creat(to, _A_NORMAL, &out) != 0) {
        out = -1;
        goto done;
    }
    created = 1;
    expect = file_size(in);
    why = "Unable to write destination";
    for (;;) {
        if (_dos_read(in, buf, size, &n) != 0) {
            why = "Unable to read source";
            goto done;
        }
        if (n == 0)
            break;
        if (_dos_write(out, buf, n, &written) != 0 || written != n)
            goto done;
        total += n;
    }
    if (total != expect)
        goto done;
    why = "Unable to get source modification time";
    if (dos_handle_call(0x5700, in, &r) < 0)
        goto done;
    cx = r.x.cx;
    dx = r.x.dx;
    _dos_close(in);
    in = -1;
    why = "Unable to set destination modification time";
    r.x.cx = cx;
    r.x.dx = dx;
    if (dos_handle_call(0x5701, out, &r) < 0)
        goto done;
    _dos_close(out);
    out = -1;
    why = "Unable to get source attributes";
    a = get_attr(from);
    if (a < 0)
        goto done;
    attr = (unsigned)a;
    why = "Unable to set destination attributes";
    if (set_attr(to, attr) < 0)
        goto done;
    attr_set = 1;
    /* The copy, closed, must be the source's size: if not, it is deleted,
     * and the source kept. */
    why = "Unable to write destination";
    if (_dos_open(to, 0x40, &out) != 0) {
        out = -1;
        goto done;
    }
    if (file_size(out) != total)
        goto done;
    _dos_close(out);
    out = -1;
    why = NULL;
done:
    free(buf);
    if (in >= 0)
        _dos_close(in);
    if (out >= 0)
        _dos_close(out);
    if (why != NULL && created) {
        if (attr_set)
            set_attr(to, 0);
        dos_remove(to);
    }
    return why;
}

/* True if PATH, which exists, is a character device (INT 21h 4400h). */
static int is_device(const char *path)
{
    union REGS r;
    int h, dev;

    if (_dos_open(path, 0x40, &h) != 0)
        return 0;
    dev = dos_handle_call(0x4400, h, &r) == 0 && (r.x.dx & 0x80);
    _dos_close(h);
    return dev;
}

/*
 * Renames the file TO, which is to be replaced, aside in its directory, as
 * ~MOVEnnn.$$$, into ASIDE: 0, or -1.
 */
static int set_aside(const char *to, char *aside)
{
    char *name;
    unsigned i;

    strcpy(aside, to);
    name = aside + strlen(aside);
    while (name > aside && !is_slash(name[-1]) && name[-1] != ':')
        name--;
    for (i = 0; i < 1000; i++) {
        name[0] = '~';
        strcpy(name + 1, "MOVE");
        name[5] = (char)('0' + i / 100);
        name[6] = (char)('0' + i / 10 % 10);
        name[7] = (char)('0' + i % 10);
        strcpy(name + 8, ".$$$");
        if (get_attr(aside) >= 0)
            continue;
        return dos_rename(to, aside);
    }
    return -1;
}

/*
 * Moves FROM to TO: NULL, or why not. A file TO replaces is renamed aside
 * first, and deleted only once FROM is in its place; if the move fails, it
 * is renamed back. A copy is kept only once its source is deleted. (MS-DOS
 * 6.22's MOVE deletes the file it replaces first, and reports [ok] when it
 * copies a file it then cannot delete.)
 */
static const char *move_file(const char *from, const char *to)
{
    static char aside[PATHLEN];
    const char *why = NULL;
    int a, staged = 0;

    if (dos_rename(from, to) == 0)
        return NULL;
    a = get_attr(to);
    if (a >= 0 && !(a & _A_SUBDIR) && !is_device(to)) {
        if (a & _A_RDONLY)
            return "Unable to create destination";
        if (set_aside(to, aside) < 0)
            return "Unable to create destination";
        staged = 1;
        if (dos_rename(from, to) == 0)
            goto moved;
    }
    why = copy_file(from, to);
    if (why == NULL) {
        a = get_attr(from);
        set_attr(from, 0);
        if (dos_remove(from) == 0)
            goto moved;
        /* The source is still there: the copy goes, not it. */
        why = "Unable to delete source";
        if (a > 0)
            set_attr(from, (unsigned)a);
        set_attr(to, 0);
        dos_remove(to);
    }
    if (staged)
        dos_rename(aside, to);
    return why;
moved:
    if (staged) {
        set_attr(aside, 0);
        dos_remove(aside);
    }
    return NULL;
}

/* True if FROM and TO are the same file to DOS, under different names. */
static int same_file(const char *from, const char *to)
{
    static char a[128], b[128];

    if (truename(from, a) < 0 || truename(to, b) < 0)
        return 0;
    return stricmp(a, b) == 0;
}

/* Moves PATH, a source as given or as a wildcard found it. */
static void move_one(char *path)
{
    const char *name = base_name(path), *why;
    int attr;

    if (strcmp(name, "..") == 0 || strcmp(name, ".") == 0)
        return;
    full_path(path, src);
    if (get_attr(path) < 0) {
        cannot(path, err);
        return;
    }
    attr = get_attr(src);
    if (attr & (_A_HIDDEN | _A_SYSTEM)) {
        cannot(path, E_ACCES);
        return;
    }
    if (attr == _A_SUBDIR) {
        /* A directory: no path in it may grow past DOS's longest, and it
         * cannot go into itself. */
        int grow = (int)strlen(base_name(dest)) - (int)strlen(name);
        size_t n;

        strcpy(scratch, src);
        if (grow > 0 && depth(scratch) + grow > MAXPATH) {
            cannot(path, E_ACCES);
            return;
        }
        n = strlen(src);
        if (strncmp(src, dest, n) == 0 && strpbrk(dest + n, "\\/") != NULL) {
            cannot(path, E_ACCES);
            return;
        }
    }
    strcpy(target, dest);
    if (dest_attr & _A_SUBDIR) {
        if (!is_slash(target[strlen(target) - 1]))
            strcat(target, "\\");
        strcat(target, base_name(src));
    }
    if (stricmp(src, target) == 0 || same_file(src, target)) {
        say("Source and destination are the same, ");
        say(src);
        say("\n");
        failed++;
        return;
    }
    if (prompt && get_attr(target) >= 0) {
        ask_out("Overwrite ");
        ask_out(target);
        ask_out(" (Yes/No/All)?");
        switch (answer(1)) {
        case 'a':
            prompt = 0;
            break;
        case 'n':
            return;
        }
    }
    say(src);
    say(" => ");
    say(target);
    say(" ");
    why = move_file(src, target);
    if (why != NULL) {
        failed++;
        say("[");
        say(why);
        say("]\n");
    } else
        say("[ok]\n");
}

/* Moves each file that ENTRY, which may have wildcards, names: 0 if none. */
static int move_matches(char *entry)
{
    struct find_t f;
    size_t dir = (size_t)(base_name(entry) - entry);

    if (dir + 13 >= PATHLEN)
        return 0;
    if (_dos_findfirst(entry, _A_HIDDEN | _A_SYSTEM | _A_SUBDIR, &f) != 0)
        return 0;
    do {
        const char *name = strlwr(f.name);

        /* MS-DOS 6.22 finds . and .. by the directory's own name, where
         * 4.00 (and GR-DOS) finds the entry: MOVE asks for it as 6.22's
         * would, a name that is not in the directory it is given in. */
        if ((strcmp(name, ".") == 0 || strcmp(name, "..") == 0) && strcmp(base_name(entry), name) == 0) {
            strcpy(scratch, entry);
            if (full_path(scratch, target) < 0 || *base_name(target) == '\0')
                return 0;
            name = base_name(target);
        }
        memcpy(found, entry, dir);
        strcpy(found + dir, name);
        move_one(found);
    } while (_dos_findnext(&f) == 0);
    return 1;
}

/* True if SOURCES name more than one file. */
static int several(void)
{
    struct find_t f;

    if (strchr(sources, ',') != NULL)
        return 1;
    if (_dos_findfirst(sources, 0x3F, &f) != 0)
        return 0;
    return _dos_findnext(&f) == 0;
}

/*
 * The word after MARK in the first 4 KB of the segment SHELL, or -1 when
 * MARK is not there.
 */
static long marked_word(unsigned char __far *shell, const char *mark)
{
    unsigned i, j, n = (unsigned)strlen(mark);

    for (i = 0; i + n + 2 <= 0x1000; i++) {
        for (j = 0; j < n && shell[i + j] == (unsigned char)mark[j]; j++)
            ;
        if (j == n)
            return *(unsigned __far *)(shell + i + n);
    }
    return -1;
}

/*
 * 0 when MOVE runs from a batch file: COMMAND.COM, if it is the primary
 * shell (its own parent), marks its batch segment with "cox", as MS-DOS
 * 6.22's does (and GR-DOS's, patches/utilities); a secondary shell, or one
 * without the mark, counts as a batch file, as it does to 6.22's MOVE.
 * GR-DOS's COMMAND also marks SINGLECOM with "grdos/c": under COMMAND /C,
 * which 6.22's MOVE does not ask under, MS-DOS 4.00's COMMAND is its own
 * parent too.
 */
static int at_prompt(void)
{
    unsigned parent = *(unsigned __far *)MK_FP(_psp, 0x16);
    unsigned char __far *shell = MK_FP(parent, 0);

    if (*(unsigned __far *)MK_FP(parent, 0x16) != parent)
        return 0;
    if (marked_word(shell, "cox") != 0)
        return 0;
    return marked_word(shell, "grdos/c") <= 0;
}

int main(int argc, char **argv)
{
    char *copycmd, *entry, *next;
    int i, last;

    copycmd = getenv("COPYCMD");
    if (copycmd != NULL) {
        char *slash = strchr(copycmd, '/');
        if (slash != NULL && (slash[1] == 'Y' || slash[1] == 'y'))
            prompt = 0;
    } else if (!at_prompt())
        prompt = 0;

    argc--;
    argv++;
    while (argc > 0 && (argv[0][0] == '/' || argv[0][0] == '-')) {
        char *opt = argv[0] + 1;
        if (stricmp(opt, "Y") == 0)
            prompt = 0;
        else if (stricmp(opt, "-Y") == 0)
            prompt = 1;
        else if (strcmp(opt, "?") == 0) {
            help();
            return 0;
        } else
            usage_error("Invalid switch", opt);
        argc--;
        argv++;
    }
    if (argc < 2)
        usage_error("Required parameter missing", NULL);

    /* The destination, without a \ at its end. */
    last = argc - 1;
    if (full_path(argv[last], dest) < 0) {
        cannot(argv[last], err);
        exit(1);
    }
    i = (int)strlen(dest);
    if (is_slash(dest[i - 1]) && i > 3)
        dest[i - 1] = '\0';

    /* The sources: one argument, or several joined by commas. */
    if (strlen(argv[0]) >= sizeof sources)
        usage_error("Too many parameters", argv[0]);
    strcpy(sources, argv[0]);
    for (i = 1; i < last; i++) {
        size_t n = strlen(argv[i - 1]);
        if (argv[i][0] != ',' && (n == 0 || argv[i - 1][n - 1] != ','))
            usage_error("Too many parameters", argv[i]);
        if (strlen(sources) + strlen(argv[i]) >= sizeof sources)
            usage_error("Too many parameters", argv[i]);
        strcat(sources, argv[i]);
    }
    {
        size_t n = strlen(argv[last - 1]);
        if (argv[last][0] == ',' || (n > 0 && argv[last - 1][n - 1] == ','))
            usage_error("Required parameter missing", NULL);
    }

    /* The destination is a directory, or one file. */
    dest_attr = dest_attributes(dest) & 0xFF;
    if (dest_attr == 0xFF) {
        if (several()) {
            int make = 1;
            if (prompt) {
                ask_out("Make directory \"");
                ask_out(dest);
                ask_out("\"? [yn] ");
                make = answer(0) == 'y';
            }
            if (!make || make_dirs(dest) != 0)
                usage_error("Cannot move multiple files to a single file", NULL);
            dest_attr |= _A_SUBDIR;
        } else
            dest_attr &= ~_A_SUBDIR;
    } else if (!(dest_attr & _A_SUBDIR) && several())
        usage_error("Cannot move multiple files to a single file", NULL);

    /* Each source; an empty one, between two commas, is none. */
    for (entry = sources; entry != NULL; entry = next) {
        next = strchr(entry, ',');
        if (next != NULL)
            *next++ = '\0';
        if (entry[0] == '\0')
            continue;
        if (!move_matches(entry))
            move_one(entry);
    }
    return failed ? 1 : 0;
}
