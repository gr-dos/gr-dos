# GR-DOS — PoC Enhancement: Custom INT 21h Service

**Status:** Deferred proposal, post-MVP.

## Goal

Prove we can change the GR-DOS kernel and call the new functionality from an independent DOS executable, without breaking standard DOS behavior.

## Proposal

Add a read-only **GR-DOS identity/version query** through a carefully chosen INT 21h interface. Return a recognizable signature, API revision, and GR-DOS version/build identifier in documented registers. Write a tiny `.COM` or `.EXE` client (assembly or 16-bit C) that detects and displays the information.

**Do not choose the function number yet.** First audit documented and undocumented INT 21h allocations, vendor extensions, and multiplex conventions. A probe must fail safely under stock DOS 4/6.22.

## Steps

1. Establish passing MVP build and emulator smoke tests.
2. Identify an appropriate discovery mechanism and register convention.
3. Specify inputs, outputs, preserved registers/flags, unsupported behavior and API versioning.
4. Implement minimal kernel handler, preserving 8086 compatibility.
5. Build independent client from source.
6. Test on GR-DOS and on original DOS variants; ensure no regression in existing calls.

## Acceptance

- Client recognizes GR-DOS and prints correct version/build data.
- Same client exits safely on non-GR-DOS.
- No change to existing DOS API behavior; CI includes regression.
- Implementation and interface documented.

**Out of scope:** broad kernel API redesign or major new functionality.
