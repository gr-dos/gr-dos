/*
 * MORE: GR-DOS's MORE filter, in C (issue #16).
 *
 * It does what MS-DOS 4.00's MORE.COM does (v4.0/src/CMD/MORE/MORE.ASM,
 * MIT, from which the behaviour, the DOS calls and the structures below
 * are taken): it copies standard input to standard output a character at
 * a time, and after each screenful writes "-- More --" to standard error
 * and waits for a key. It is a .COM program (src/lib/comstart.asm), and
 * its messages are MORE.SKL's (MORE.H, from scripts/msgh).
 *
 * The screen is MAXROW rows (25, or what the display driver reports for a
 * text mode, through generic IOCTL 440Ch on standard error, which needs
 * ANSI.SYS) of MAXCOL columns (the BIOS's, INT 10h function 0Fh). MORE
 * counts rows and columns as MORE.ASM does, in bytes, so they wrap at 256
 * as its do: CR goes to column 1, LF to the next row, BS back a column
 * (not past column 1), TAB to the next tab stop (which may be past the
 * last column: only a character that is printed wraps), BEL does not
 * move, and every other character, control characters too, moves a
 * column, wrapping to the next row past the last. ^Z ends the input.
 *
 * Standard input is duplicated, and handle 0 becomes a duplicate of
 * standard error, so the keys come from the console even when the input
 * is redirected. As in MORE.ASM, a code page set on the input file
 * (extended attribute "CP") is set on standard output when code page
 * switching is active.
 *
 * GR-DOS's MORE stops at an error reading its input; MORE.ASM took the
 * error code for the number of bytes read (docs/more.md).
 */

#include <dos.h>

#include "MORE.H"

#define STDIN   0
#define STDOUT  1
#define STDERR  2

#define EXPECTED_VERSION 0x0004   /* DOS 4.00: AL = 4, AH = 0 */

/* Generic IOCTL 440Ch, CX = 037Fh: get display information (MORE.INC's
 * ANSI_STR). */
struct ansi_str {
    unsigned char level;
    unsigned char reserved1;
    unsigned      length;
    unsigned      flags;
    unsigned char mode;
    unsigned char reserved2;
    unsigned      colors;
    unsigned      pixel_cols;
    unsigned      pixel_rows;
    unsigned      cols;
    unsigned      rows;
};
#define TEXT_MODE 1

/* Extended attributes: the query list and the get/set list for the code
 * page attribute "CP" (MORE.ASM's cp_qlist and cp_list). */
struct ea_query {
    unsigned      count;
    unsigned char type;
    unsigned      flags;
    unsigned char namelen;
    char          name[8];
};

struct ea_list {
    unsigned      count;
    unsigned char type;
    unsigned      flags;
    unsigned char rc;
    unsigned char namelen;
    unsigned      valuelen;
    char          name[2];
    unsigned      cp;
};

#define EAISBINARY 0x02
#define EASYSTEM   0x8000

static struct ansi_str ansi_buf = { 0, 0, 14 };
static struct ea_query cp_qlist = { 1, EAISBINARY, EASYSTEM, 2, "CP      " };
static struct ea_list  cp_list  = { 1, EAISBINARY, EASYSTEM, 0, 2, 2, "CP" };

static const char crlf[]  = "\r\n";
static const char crlf2[] = "\r\n\r\n";
static const char msg_version[] = MSG_A_1;
static const char msg_more[]    = MSG_A_2;

static unsigned char maxrow = 25;
static unsigned char maxcol = 80;
static unsigned char currow = 1;
static unsigned char curcol = 1;

static unsigned char buffer[4096];

/* INT 21h function 40h. */
static void dos_write(unsigned handle, const void *data, unsigned length)
{
    union REGS r;

    r.h.ah = 0x40;
    r.x.bx = handle;
    r.x.cx = length;
    r.x.dx = (unsigned)data;
    intdos(&r, &r);
}

static void dos_exit(unsigned char code)
{
    bdos(0x4C, 0, code);
}

/* "Incorrect DOS version", as the message retriever's SYSLOADMSG and
 * MORE.ASM give it: on standard error, and errorlevel 1, from DOS 2.0;
 * before, through the console, and the program ends with function 0. */
static void wrong_version(unsigned char major)
{
    const char *p;

    if (major >= 2) {
        dos_write(STDERR, msg_version, sizeof msg_version - 1);
        dos_exit(1);
    }
    for (p = msg_version; *p; p++)
        bdos(0x02, (unsigned char)*p, 0);
    bdos(0x00, 0, 0);
}

/* The screen's size, the handles and the code page, as MORE.ASM sets them
 * up; returns the input's new handle. */
static unsigned setup(void)
{
    union REGS r;
    struct SREGS s;
    unsigned in;

    /* The rows of a text mode, if the display driver gives them. */
    r.x.ax = 0x440C;
    r.x.bx = STDERR;
    r.x.cx = 0x037F;
    r.x.dx = (unsigned)&ansi_buf;
    intdos(&r, &r);
    if (!r.x.cflag && ansi_buf.mode == TEXT_MODE)
        maxrow = (unsigned char)ansi_buf.rows;

    r.h.ah = 0x0F;
    int86(0x10, &r, &r);
    maxcol = r.h.ah;

    /* The input on a new handle, and the console's on handle 0. */
    r.h.ah = 0x45;
    r.x.bx = STDIN;
    intdos(&r, &r);
    in = r.x.ax;
    r.h.ah = 0x3E;
    r.x.bx = STDIN;
    intdos(&r, &r);
    r.h.ah = 0x45;
    r.x.bx = STDERR;
    intdos(&r, &r);

    /* The input's code page on the output, if code page switching is on. */
    r.x.ax = 0x3303;
    intdos(&r, &r);
    if (!r.x.cflag && r.h.dl != 0) {
        segread(&s);
        s.es = s.ds;
        r.x.ax = 0x5702;
        r.x.bx = in;
        r.x.si = (unsigned)&cp_qlist;
        r.x.cx = sizeof cp_list;
        r.x.di = (unsigned)&cp_list;
        intdosx(&r, &r, &s);
        if (!r.x.cflag) {
            r.x.ax = 0x5704;
            r.x.bx = STDOUT;
            r.x.di = (unsigned)&cp_list;
            intdosx(&r, &r, &s);
        }
    }

    return in;
}

/* After a screenful: the prompt, a key (the second byte too of an
 * extended key), and a blank line. */
static void ask_more(void)
{
    dos_write(STDERR, msg_more, sizeof msg_more - 1);
    if ((unsigned char)bdos(0x0C, 0, 0x08) == 0)
        bdos(0x08, 0, 0);
    dos_write(STDERR, crlf2, sizeof crlf2 - 1);
    curcol = 1;
    currow = 1;
}

/* The row and column after the character c. */
static void advance(unsigned char c)
{
    switch (c) {
    case '\r':
        curcol = 1;
        break;
    case '\n':
        currow++;
        break;
    case '\b':
        if (curcol != 1)
            curcol--;
        break;
    case '\t':
        curcol = (unsigned char)(((unsigned char)(curcol + 7) & 0xF8) + 1);
        break;
    case 7:
        break;
    default:
        curcol++;
        if (curcol > maxcol) {
            currow++;
            curcol = 1;
        }
        break;
    }
}

int com_main(void)
{
    union REGS r;
    unsigned in, n, i;
    unsigned char c;

    r.h.ah = 0x30;
    intdos(&r, &r);
    if (r.x.ax != EXPECTED_VERSION)
        wrong_version(r.h.al);

    in = setup();

    dos_write(STDOUT, crlf, sizeof crlf - 1);
    for (;;) {
        r.h.ah = 0x3F;
        r.x.bx = in;
        r.x.cx = sizeof buffer;
        r.x.dx = (unsigned)buffer;
        intdos(&r, &r);
        n = r.x.ax;
        if (r.x.cflag || n == 0)
            return 0;
        for (i = 0; i < n; i++) {
            c = buffer[i];
            if (c == 0x1A)
                return 0;
            advance(c);
            bdos(0x02, c, 0);
            if (currow >= maxrow)
                ask_more();
        }
    }
}
