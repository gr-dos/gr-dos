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
- Community DOS restoration/build tree to inspect: https://github.com/chasonr/MS-DOS
- Source restoration discussion: https://felsqualle.com/posts/2024/05/the-broken-source-code-for-ms-dos-4-has-been-restored/

Audit reference-project licenses and patch provenance before copying. MIT permission does not grant Microsoft/IBM trademark rights. GR-DOS is an independent working name; avoid suggesting endorsement.

**Stop at MVP:** a buildable, bootable, CI-tested DOS. Do not make historical bug repair a prerequisite.
