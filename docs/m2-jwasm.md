# M2: JWasm and wlink, byte-identical to MASM and LINK

Decision 19 requires the boot sector, IO.SYS, MSDOS.SYS and COMMAND.COM
built with JWasm and `wlink` to be byte-identical to the M1 reference build
(MASM 5.10, LINK 3.65, EXE2BIN). This records what that took. All four are
identical as of 2026-10-23:

| File | sha256 |
| --- | --- |
| `BOOT/MSBOOT.BIN` | `a6d6bd5708f74c074deb239d2b8d3c42266b282dc5612103272c3f8c00aa4332` |
| `BIOS/IO.SYS` | `755c79c16d3db5280b5286f1032a4f77bb8556b79f0c22f9c9f85556c7b69e39` |
| `DOS/MSDOS.SYS` | `573626782a3c45f0d9e5f00af1bd0f52a7de44bea96d2a2d3d660e9ae06158d5` |
| `CMD/COMMAND/COMMAND.COM` | `19ebe2e5a8e18ca5d447a3d1fc42c42e4942ff5f3ef50e39ab01374bb01d8ea9` |

The message intermediates (`.CL?`, `.CTL`, `.IDX`, `BOOT.INC`) were still
taken from the M1 build at this point; their Perl replacements are separate
work.

## Source edits

The JWasm compatibility edits to `v4.0` are separate commits. Each one keeps
the MASM build identical to `docs/m1/reference-build.sha256`
(`scripts/check-reference`).

## JWasm patches

`scripts/fetch-jwasm` applies the patches in `patches/jwasm` to the pinned
commit.

**`0001-equate-variable-asmpass.patch`** fixes a JWasm bug. An
assembly-time variable (`=`) holding a label address was treated in pass two
as a label not yet defined, so `ret_l = x` / `jc ret_l` became a jump to
itself. The DOS `retc`/`retz`/... macros depend on this.

**`0002-Zj-masm5-code-generation.patch`** adds `-Zj`. MASM 5 is a two-pass
assembler: pass one fixes the size of every instruction, and pass two never
shrinks one. `-Zj` reproduces the code that results:

- **Forward `JMP`.** A forward `JMP` reserves 3 bytes, and becomes `EB xx 90`
  when the target turns out to be within short range.
- **Pass-one sizes.** The pass-one size of every instruction is recorded,
  and later passes pad a shorter instruction with NOPs.
- **Forward operands.** A forward-referenced second operand of an
  instruction with a register destination is assumed to be memory
  (`MOV CX,fwd` is sized as `8B 0E`, so `B9 xxxx 90`). A forward-referenced
  variable is assumed to be a WORD. The 80/83 arithmetic group keeps the
  short form when the immediate fits in a byte (`CMP fwd,0FFh` is 5 bytes,
  `MOV fwd,0` is 6).
- **Forward displacements.** A forward reference in a displacement keeps a
  16-bit displacement (`MOV AL,ES:[BX.field]` with the structure defined
  later is `26 8A 87 0000`).
- **Accumulator form.** `AX, imm` uses the accumulator form (`3D FFFF`), not
  opcode 83.
- **Alignment padding.** `EVEN`/`ALIGN` pad with `90h` in a segment that
  contains instructions anywhere in the module, and with zeros otherwise.
  The padding is always written, even after uninitialised data.
- **Structure names.** A structure name used as an operand of `+` or `-` is
  0 (`LENGTH_INIT EQU IFSR_RESSIZE-IFSRH+2`).
- **Typed sums.** `number + struct field` has the type of the field
  (`MOV DS:(SEC9+DISK_SPECIFY_1),0DFh` is a byte store).
- **Explicit frames.** Fixups always carry an explicit frame. JWasm otherwise
  writes F5 ("frame of target"), which `wlink` resolves differently for
  segment bases.

Some differences remain in the objects and are harmless. JWasm leaves
uninitialised data (`?`) as a gap where MASM writes zeros. JWasm also
resolves intra-segment displacements that MASM leaves to the linker.

## Linking

`wlink` lays segments out differently from Microsoft LINK, which aligns
every public segment contribution, including zero-length ones. The DOS
modules declare every segment of their group in every module, so this
matters. `scripts/mslink-layout` reads the objects and prints a `wlink`
`ORDER` directive that places each segment at Microsoft LINK's paragraph
(`SEGADDR`, which is also its relocation frame) and offset. It also prints
the image size: the end of the last non-empty segment. Microsoft LINK
includes trailing uninitialised data in the image, because MASM wrote it as
zeros.

`scripts/exe2bin` replaces EXE2BIN. Open Watcom's `exe2bin` loses the carry
when adding the base segment to a relocated word: IO.SYS is converted with
base `70` and got `0357` for `03E7`. The script pads to the size from
`mslink-layout` and drops the PSP area of a `.COM` program.

## Comparing objects

`scripts/omfdiff` compares segment images and fixup locations of two
objects. The M2 harness also compared images with every fixup location
masked out, and the assembled code of all 102 modules matched MASM's.
