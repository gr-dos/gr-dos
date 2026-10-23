# GR-DOS — MVP Design

**Status:** Proposed, not started  
**Name:** GR-DOS (*Graham DOS*)  
**Upstream:** Microsoft/IBM MS-DOS 4.00 source published by Microsoft under MIT  
**Target:** 8086-compatible, usable DOS built on Linux, with GitHub Actions CI

## Objective

Fork the legally published MS-DOS 4.00 source and produce a usable, bootable GR-DOS with a repeatable Linux build. Use community restoration/build projects as references, not as unexamined sources of code. Preserve the original DOS architecture and 8086 compatibility where possible.

## MVP scope

1. Import or fork the official DOS 4.00 tree while preserving provenance, copyright and MIT license notices.
2. Identify and apply necessary source repairs, including encoding fixes. Keep modifications documented and reviewable.
3. Reproduce a known-good historical/community build as a baseline before changing tools.
4. Implement a **Linux-hosted build**, ideally using Linux-native assembler/linker tools and scripts. A fully automated DOS-emulated toolchain may be a transitional step, but does not satisfy the preferred native-toolchain goal.
5. Produce a bootable disk image using legally redistributable inputs. Do not silently bundle retail DOS binaries or proprietary tools.
6. Boot to a command prompt, use basic filesystem commands, and run an independently built DOS executable.
7. Run build and boot smoke tests in **GitHub Actions** on Linux; publish build artifacts, checksums and logs.
8. Document tool versions, reproducible steps, known limitations, source provenance and licenses.

A *usable DOS* need not contain every DOS 4 retail utility. Missing components must be identified explicitly. Byte-identical builds are a useful reference, not a prerequisite.

## Architecture and workflow

```text
Official MIT DOS 4 source
         + documented restoration patches
                     |
             Linux build scripts
                     |
        assembler / OMF linker / utilities
                     |
            DOS system binaries
                     |
       image creation + smoke-test runner
                     |
          bootable image + CI artifacts
```

Investigate MASM-compatible assemblers (JWasm/UASM, Open Watcom components) and appropriate OMF linkers; verify compatibility experimentally. Avoid wholesale assembly syntax conversion until the original build is understood. Keep CP437/line-ending transformations deterministic.

## Toolchain candidates

**Preferred: Open Watcom 2.0.** Linux-native (x64 and x86) and covers most of the build:

- `wasm`: MASM-compatible assembler.
- `wlink`: OMF linker producing DOS EXE/COM.
- `ms2wlink`: converts Microsoft LINK command lines/response files, as used by the DOS 4 makefiles.
- `exe2bin`: replaces the historical EXE2BIN step.
- `wcc`/`wcl`/`owcc`: 16-bit C compiler with DOS libraries (`lib286`) for the C-based components.
- `wlib`, `wdis`: librarian and disassembler for comparing objects against the M1 reference build.

Open questions to resolve experimentally:

- **MASM dialect.** DOS 4 sources target MASM 4/5; `wasm` differs in places (e.g. `%OUT`, segment ordering, implicit `ASSUME`). Test against real sources before committing.
- **C portability.** DOS 4 C utilities assume Microsoft C 5.x pragmas, calling conventions and runtime. Treat them as "missing until ported" rather than assumed buildable.
- **Version pinning.** OW 2.0 is a rolling beta. CI must fetch a specific dated snapshot from the open-watcom-v2 GitHub releases and verify its hash; record the snapshot used locally.
- **License.** Open Watcom Public License is acceptable for a build tool. If Watcom runtime code is linked into image components, document it.

**Fallback: JWasm/UASM** as assembler, paired with `wlink`, if `wasm` proves incompatible with the DOS 4 sources.

## Decisions

1. **Source import.** Vendor only `v4.0` from microsoft/MS-DOS, unmodified, in a single commit recording the upstream commit hash. All repairs follow as separate, reviewable commits.
2. **Encoding.** Keep sources in the repository byte-for-byte as published (upstream ships LF line endings and raw CP437 bytes; see `docs/provenance.md`). Build scripts perform any transformation deterministically.
3. **Community restorations.** Take fixes only from sources with a verified license (currently the hharte, lotharsm and chasonr forks, MIT, for commits authored by the committer), recording commit hash and author per patch. Do not use the felsqualle archives or images. ecm's patches are not used: the repository is private and its license unverifiable. See `docs/provenance.md` for the restoration basis.
4. **Reference build tools.** If the original Microsoft build tools are not MIT-covered, M1 may run them under emulation locally only, documented, never in CI and never redistributed.
5. **Boot media.** Start with a 1.44 MB floppy image. Hard disk images come later.
6. **Minimum components.** IO.SYS, MSDOS.SYS, COMMAND.COM and whatever the smoke tests require. FORMAT, SYS and FDISK are deferred because the image is built on Linux. Other utilities are a fast follow after MVP.
7. **Branding.** Change the banner and `VER` output to GR-DOS. The DOS version reported to programs stays 4.00.
8. **License.** New GR-DOS scripts, patches and documentation are MIT.
9. **Hardware validation.** The 8086/V20 check in 86Box is a documented manual step, since many machine ROMs are not redistributable. CI uses QEMU only.
10. **Open Watcom version.** Pin open-watcom-v2 release `2026-10-01-Build`, locally and in CI. Use the Linux x64 C asset `open-watcom-2_0-c-linux-x64` (`sha256:a961f3e02ce27bcd88428345dc57483457a623b6e718b6cee52c48d24ab8065f`). The `ow-snapshot.tar.xz` asset (`sha256:e6aa1b1e40ac8bbf97658d2c70fff8a4242d6ca4a1c60806f2baa5317083d4fe`) may be evaluated in M0 as an installer-free alternative. Rolling `Current-build`/`Last-CI-build` tags are not used. Fallback if a regression is found: `2026-09-01-Build`.
11. **Build entry point.** `make` driving POSIX shell scripts. Replacements for the binary-only DOS build tools (`BUILDMSG`, `NOSRVBLD`, `DBOF` and others) are written in modern Perl 5.42, following the style of [OpenAPI::Humbug](https://github.com/uperl/OpenAPI-Humbug/blob/main/lib/OpenAPI/Humbug.pm): `use 5.042`, subroutine signatures, postfix dereference, POD documentation. Non-core module dependencies are pinned. CI installs a pinned Perl 5.42, since the runner image's system Perl is older.
12. **Image creation.** mtools writes the FAT12 image. A script verifies IO.SYS and MSDOS.SYS are the first directory entries and contiguous.
13. **Smoke tests.** Headless QEMU; a test batch file writes results to COM1 and a scripted runner with timeouts checks them. CI pins the runner image (`ubuntu-24.04`) and records the QEMU version in the logs.
14. **Test program.** Built with the pinned Open Watcom (`wasm`/`wlink`), independent of the DOS source tree.
15. **Build flavor.** MS-DOS, not IBM PC-DOS.
16. **Copyright notice.** The GR-DOS banner retains the Microsoft copyright line, satisfying the MIT notice requirement without suggesting endorsement.
17. **Versioning and releases.** The version lives in a top-level `VERSION` file, starting at `0.01`. When a merge to `main` changes `VERSION`, CI tags that merge commit `v<VERSION>` (first: `v0.01`), creates a GitHub Release and attaches the image, checksums and logs. Other builds publish Actions artifacts only.
18. **Workflow.** All changes reach `main` through pull requests. `main` is protected: pull requests required, CI status check `ci` must pass, and administrators are not exempt. The CI workflow's job must therefore be named `ci`.

## Proposed milestones

**M0: Provenance.** Inventory published sources, missing files, license notices, build scripts, historical tools and community patches.

**M1: Reference build.** Reproduce a documented successful DOS 4 build and boot, recording hashes and exact tools.

**M2: Linux build.** Replace interactive/historical steps with scripted Linux execution; aim for Linux-native cross-tools, clearly label any remaining emulation.

**M3: Boot image and tests.** Generate a bootable image; verify prompt, directory listing, file creation/copy/read, and a small DOS test program.

**M4: CI.** Build and smoke-test on GitHub Actions, preferably with headless QEMU for automation; separately validate in 86Box.

## Acceptance criteria

- [ ] Fresh Linux environment can run one documented build command without manually launching DOS/Windows.
- [ ] Required inputs have documented legal redistribution or acquisition paths.
- [ ] Output image boots to GR-DOS prompt in an emulator.
- [ ] Basic disk I/O and external program execution work.
- [ ] GitHub Actions builds, boots/tests and uploads artifacts.
- [ ] Build and test versions/hashes are pinned or recorded.
- [ ] 8086/V20 compatibility is preserved or deviations are documented.

## Non-goals

No new INT 21h services, conventional-memory optimization, EMS repairs, 32 MB file bug fixes, networking, FAT32, long filenames, or new installer in MVP. Those are separate proposals. Avoid scope creep into making an all-purpose FreeDOS competitor.

## References and licensing

- Official source and MIT license: https://github.com/microsoft/MS-DOS
- Community assembler adaptation to inspect: https://github.com/AndresTraks/MS-DOS-FASM
- Community DOS restoration/build tree to inspect: https://github.com/chasonr/MS-DOS (fork of microsoft/MS-DOS; upstream MIT `LICENSE` unchanged, no separate terms for fork changes)
- Restoration patch sources:
  - https://github.com/hharte/MS-DOS/commit/1f506100a818cb9b6c2b29aeda8d4d24d094c477 (fork of microsoft/MS-DOS; upstream MIT `LICENSE` unchanged)
  - https://github.com/lotharsm/MS-DOS/commits/dos-4.00-reconstructed/ (fork of microsoft/MS-DOS; upstream MIT `LICENSE` unchanged)
  - https://hg.pushbx.org/ecm/msdos4/rev/63a05668c5f3 (Mercurial; password-protected, license unverifiable, not used)
- Restoration discussion only: https://felsqualle.com/posts/2024/05/the-broken-source-code-for-ms-dos-4-has-been-restored/ (no license stated; do not use its archives or disk images, which include IBM PC-DOS binaries)

Audit reference-project licenses and patch provenance before copying. For fork commits, record the commit hash and author in provenance notes, since contributor terms are implied by the repository license rather than stated. MIT permission does not grant Microsoft/IBM trademark rights. GR-DOS is an independent working name; avoid suggesting endorsement.

**Stop at MVP:** a buildable, bootable, CI-tested DOS. Do not make historical bug repair a prerequisite.
