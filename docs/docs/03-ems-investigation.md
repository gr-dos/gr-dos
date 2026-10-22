# GR-DOS — Investigation: EMS Disk-Buffer Compatibility

**Status:** Deferred investigation, post-MVP. Presence of bug in published source **unverified**.

## Question

Does the published DOS 4 source contain the historical expanded-memory disk-buffer defect reported on some EMS implementations, and can we reproduce it reliably?

## Research plan

1. Identify EMS detection, allocation, mapping, disk-buffer and cleanup code in DOS 4 source.
2. Gather primary historical bug reports/patch notes; distinguish Microsoft vs IBM revisions and EMS 3.2 vs 4.0 behavior.
3. Determine whether the published source already incorporates the historical correction.
4. Test emulator configurations with no EMS, limited EMS pages, different page frames and failure conditions where supported.
5. Exercise reads/writes with disk buffers enabled; validate file contents and sector hashes.
6. If reproducible, isolate cause: unsupported assumptions, insufficient allocation, mapping failure, missed cleanup, or other mechanism.
7. Implement smallest verified fix and add regression tests.

## Safety

Use disposable disk images only. Compare checksums before/after; do not test suspected corruption on valuable media.

## Deliverables

- Source references and historical evidence with affected versions.
- Minimal failing case **or** evidence that published source is unaffected.
- Trace/checksum-based regression test.
- Fix only if a defect is demonstrated.

## Success

Verified correction of a reproduced defect, or a documented negative finding. Historical reputation alone is not grounds for a patch.
