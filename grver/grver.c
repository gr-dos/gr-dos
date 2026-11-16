/*
 * GRVER: report the GR-DOS release version from the GR-DOS kernel
 * (issue #46, docs/grver.md).
 *
 * The kernel's identification call (patches/kernel):
 *
 *   in:  AX = 3347h, BX = 4752h ("GR"), DX = any value (a nonce)
 *   out: AX = 4752h, BH = major, BL = minor (0 to 99), CL = API revision,
 *        CH = 0 (reserved), DX = the nonce complemented
 *
 * Any other DOS treats AX=3347h as an unknown subfunction of function 33h:
 * MS-DOS returns AL = FFh and leaves the other registers as they were, DR
 * DOS sets the carry flag and AX = 0001h. The call is made twice, with two
 * nonces, so that registers left unchanged, or a handler that always
 * returns the same values, are not taken for GR-DOS.
 *
 * Exit status: 0, GR-DOS; 1, not GR-DOS; 2, an answer with the GR-DOS
 * signature that is not valid; 3, a bad parameter.
 *
 * Built with Open Watcom C and libc16, like MEM (Makefile). libc16 has no
 * printf (its decision 3): the version is written with libc16_ultoa.
 */

#include <dos.h>
#include <libc16.h>
#include <stdio.h>
#include <string.h>

#define GRDOS_ID_AX  0x3347u
#define GRDOS_ID_SIG 0x4752u

enum { FOUND = 0, NOT_FOUND = 1, INVALID = 2, BAD_PARAMETER = 3 };

struct grdos_id {
    unsigned major, minor, revision;
};

/* One identification call with the nonce given. */
static int ask(unsigned nonce, struct grdos_id *id)
{
    union REGS r;

    memset(&r, 0, sizeof r);
    r.x.ax = GRDOS_ID_AX;
    r.x.bx = GRDOS_ID_SIG;
    r.x.cx = 0;
    r.x.dx = nonce;
    intdos(&r, &r);
    if (r.x.ax != GRDOS_ID_SIG)
        return NOT_FOUND;
    if (r.x.dx != (unsigned)~nonce || r.h.cl == 0 || r.h.bl > 99)
        return INVALID;
    id->major = r.h.bh;
    id->minor = r.h.bl;
    id->revision = r.h.cl;
    return FOUND;
}

static int identify(struct grdos_id *id)
{
    struct grdos_id again;
    int status;

    status = ask(0x5A3Cu, id);
    if (status != FOUND)
        return status;
    status = ask(0xC3A5u, &again);
    if (status != FOUND)
        return status == NOT_FOUND ? INVALID : status;
    if (again.major != id->major || again.minor != id->minor || again.revision != id->revision)
        return INVALID;
    return FOUND;
}

static void say(const char *s)
{
    fputs(s, stdout);
}

static void help(void)
{
    say("Displays the GR-DOS release version, as the GR-DOS kernel reports it.\n"
         "\n"
         "GRVER [/?]\n"
         "\n"
         "Exit status: 0 GR-DOS, 1 not GR-DOS, 2 invalid response, 3 bad parameter.\n");
}

/* "GR-DOS n.nn": the minor version always two digits (%u.%02u). */
static void print_version(const struct grdos_id *id)
{
    char buf[34];

    say("GR-DOS ");
    say(libc16_ultoa(id->major, buf, 10));
    say(id->minor < 10 ? ".0" : ".");
    say(libc16_ultoa(id->minor, buf, 10));
    say("\n");
}

int main(int argc, char **argv)
{
    struct grdos_id id;
    int status;

    if (argc > 2 || (argc == 2 && strcmp(argv[1], "/?") != 0)) {
        say("Invalid parameter - ");
        say(argv[1]);
        say("\n");
        help();
        return BAD_PARAMETER;
    }
    if (argc == 2) {
        help();
        return FOUND;
    }

    status = identify(&id);
    switch (status) {
    case FOUND:
        print_version(&id);
        break;
    case NOT_FOUND:
        say("GR-DOS kernel not detected.\n");
        break;
    default:
        say("GR-DOS kernel response not valid.\n");
        break;
    }
    return status;
}
