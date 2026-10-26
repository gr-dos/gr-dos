/*
 * GR-DOS C runtime (compat/crt): <dos.h> for ATTRIB and MEM.
 *
 * The register structures are laid out as Microsoft C 5.1's, which the
 * programs and their assembly modules assume. FP_SEG() and FP_OFF() can be
 * assigned to, as Microsoft C's can.
 */
#ifndef GRCRT_DOS_H
#define GRCRT_DOS_H

struct WORDREGS {
    unsigned int ax, bx, cx, dx, si, di, cflag;
};
struct BYTEREGS {
    unsigned char al, ah, bl, bh, cl, ch, dl, dh;
};
union REGS {
    struct WORDREGS x;
    struct BYTEREGS h;
};
struct SREGS {
    unsigned int es, cs, ss, ds;
};

#define FP_SEG(fp)      (*((unsigned *)&(fp) + 1))
#define FP_OFF(fp)      (*((unsigned *)&(fp)))
#define MK_FP(seg, off) ((void far *)(((unsigned long)(seg) << 16) | (unsigned)(off)))

int  __cdecl bdos(int fn, unsigned int dx, unsigned int al);
int  __cdecl int86(int intno, union REGS *in, union REGS *out);
int  __cdecl int86x(int intno, union REGS *in, union REGS *out, struct SREGS *seg);
int  __cdecl intdos(union REGS *in, union REGS *out);
int  __cdecl intdosx(union REGS *in, union REGS *out, struct SREGS *seg);
void __cdecl segread(struct SREGS *seg);

#endif
