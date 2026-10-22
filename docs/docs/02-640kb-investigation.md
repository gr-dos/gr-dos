# GR-DOS — Investigation: Conventional-Memory Footprint (640 KB)

**Status:** Deferred investigation, post-MVP. No optimization presumed.

## Question

Why does DOS 4 have a reputation for consuming more conventional memory than DOS 3.x, and which resident allocations could safely be reduced?

## Method

1. Define identical 86Box configurations: 640 KB RAM, same disk geometry, no TSRs, minimal `CONFIG.SYS` and `AUTOEXEC.BAT`.
2. Measure free conventional memory on legally available DOS 3.3, stock DOS 4, and GR-DOS. Record versions, `FILES`, `BUFFERS`, device drivers and measurement method.
3. Distinguish disk executable size from **resident** conventional-memory use.
4. Map memory-control blocks and resident kernel data/code, then locate allocations in source.
5. Examine buffer sizing, per-drive tables, initialization-only data, internal stacks, and optional features as **hypotheses**, not established defects.
6. Prototype one change at a time and rerun functional/performance tests.

## Risks

Additional DOS 4 functionality may legitimately require memory. Shrinking buffers can degrade performance or break large-disk handling. Memory diagnostics can themselves affect measurements.

## Deliverables

- Reproducible measurement harness and before/after numbers.
- Source-level resident allocation map.
- Ranked optimization candidates with estimated savings and compatibility risk.
- Optional patches only where results justify them.

## Success

Demonstrable conventional-memory savings with no regression in file I/O, drivers, or 8086 compatibility—or a documented conclusion that particular overhead is justified.
