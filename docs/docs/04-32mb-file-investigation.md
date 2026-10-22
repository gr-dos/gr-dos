# GR-DOS — Investigation: 32 MB File-Size Boundary

**Status:** Deferred investigation, post-MVP. Exact affected builds and threshold **to verify**.

## Question

Do DOS 4 file operations mishandle files near or above 32 MiB, and does the published source already contain a fix?

## Historical lead

Historical accounts refer to DOS 4.00/4.01 large-file issues and a `PATCH32M.EXE` patch (often associated with Microsoft KB Q57550). Verify the original documentation and patch applicability before asserting this particular source snapshot is affected. Distinguish **file size**, **partition size**, and **32 KB cluster** issues.

## Test matrix

Use disposable FAT16 images with sufficient space. Test files at 32 MiB minus one byte, exactly 32 MiB, 32 MiB plus one byte, and beyond one additional cluster. Test create, write, seek, reopen, append, read, copy, directory-reported size and delete. Verify binary checksums, not only return codes.

## Investigation steps

1. Establish exact stock DOS 4/GR-DOS build versions and image geometry.
2. Validate historical documentation and reproduce against stock DOS 4 where possible.
3. Write a deterministic DOS test program with boundary conditions and integrity checks.
4. Trace file length/position arithmetic, FAT allocation and signed/unsigned conversions in source.
5. Compare patched behavior if a lawful reference binary is available.
6. Apply minimal source correction only if affected; add CI regression test.

## Pitfalls

A full disk is not evidence of a file-size bug. DOS file offsets, FAT16 cluster counts, and partition capacities have distinct limits. Test image cluster size may change behavior.

## Deliverables

- Historical evidence and exact affected versions.
- Reproducer, before/after test transcript and root-cause analysis.
- Minimal patch plus automated regression, **if needed**.

## Success

Correct file operations across the verified boundary, or proof that the released source is already corrected.
