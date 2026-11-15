# term16 — MVP Design

**Status:** Agreed design, implementation not started  
**Date:** 2026-11-15  
**Tracking:** [gr-dos/gr-dos#38](https://github.com/gr-dos/gr-dos/issues/38)  
**Repository:** \`term16\` will have its **own GitHub repository**, not live in the GR-DOS source tree. This file and issue are temporary design tracking; GR-DOS will eventually bundle the published executable.

## 1. Purpose

A lightweight 16-bit DOS serial terminal emulator, roughly Minicom without modem features. Intended for an 8088/8086 DOS machine connected by a null-modem cable to a Linux host, serial console, or museum-net gateway (e.g. twintwist/topspin). Priorities: small disk footprint, low conventional-memory use, reliable receive on slow CPUs, and a simple keyboard-driven interface.

## 2. Platform and implementation

- **Language:** Open Watcom C targeting 16-bit real-mode DOS; use small assembly routines only if required by measured performance/hardware needs.
- **Minimum:** 8088/8086-class machine, aiming for DOS 3.3+.
- **Display:** 80×25 DOS text mode, monochrome or color (MDA/CGA-compatible); no mouse.
- **Dependencies:** No TCP/IP, modem hardware/software, extended memory manager, or separately installed runtime.
- Keep UART/IRQ handling, configuration/CLI, keyboard/menu, terminal parser/rendering, and ZMODEM receiver in separate modules.
- Quantify actual executable size and conventional memory use; keeping both small is a goal, not a license to sacrifice correctness.

## 3. Serial communication

- COM1–COM4 where supported by installed hardware/port configuration.
- Configure baud rate, data bits, parity, stop bits (e.g. **9600 8N1**), and flow control (**none**, **RTS/CTS**, **XON/XOFF**).
- Full-duplex keyboard-to-port and port-to-screen operation over plain serial/null-modem wiring.
- Prefer UART interrupt-driven receive with a bounded ring buffer. Check UART compatibility (8250/16450/16550) and avoid holding interrupts disabled during display or disk I/O.
- Cleanly restore interrupt vectors and UART state on exit, errors, or cancellation.
- Opening the port reports **OPEN**, not **CONNECTED**; the program cannot assume a remote peer is present.

## 4. Command-line and text UI

Both modes are **required**:

1. Running \`term16\` with no arguments opens a simple configuration menu.
2. Arrow keys navigate fields, Enter changes/selects, and Esc backs out.
3. Menu settings: port, baud, bits/parity/stop, flow control, terminal mode if selectable, and **download directory**.
4. Command-line options supply the equivalent settings and can start a session directly, without menu interaction.
5. Provide discoverable local keyboard shortcuts to return to the menu and exit (proposed **Alt-M** / **Alt-X**, subject to testing). Do not send these local shortcuts to the remote host.
6. Interface remains usable on monochrome text displays without a full-screen UI library.

Provisional command syntax, to finalize during implementation:

\`\`\`dos
term16 -p COM1 -b 9600 --data 8 --parity none --stop 1 --flow none --download-dir C:\DOWNLOAD
\`\`\`

## 5. Terminal emulation

- Implement a compact ANSI/VT100-compatible subset for interactive text shells: printable characters, CR/LF, backspace, tabs, cursor movement/positioning, line/screen erase, and common attributes.
- Unsupported escape sequences should be handled safely without corrupting local UI.
- Use the first **24 rows** of an 80×25 display for remote terminal output, reserving the **25th row** for the local status bar.
- Clip remote scrolling, cursor placement, and clear-screen sequences to the 24-row viewport. Full-screen applications on the remote system may need TERM/size configured as 80×24.

## 6. Persistent bottom status bar

The bottom screen row should always show the **effective connection configuration needed to reproduce the session**, including:

- COM port (and custom base address only if supported in a later version)
- Baud rate
- Data bits, parity, stop bits (e.g. **8N1**)
- Flow control
- Terminal mode, if selectable
- State: **OPEN**, **CLOSED**, or **ERROR**
- Menu/exit key hints only if room remains

Example illustrative single-line layout:

\`\`\`text
COM1  9600  8N1  Flow:None  ANSI  OPEN          Alt-M Menu  Alt-X Exit
\`\`\`

Update the bar when settings or state change, regardless of whether settings came from CLI or menu. **Never show the download directory in the status bar**. Do not claim a connection is established merely because the port opened. The remote host must never be able to overwrite the bar.

## 7. Automatic ZMODEM download (MVP requirement)

A **receive-only ZMODEM implementation** is included in the MVP:

- Detect valid ZMODEM start sequences from an incoming serial stream (e.g. a Linux \`sz filename\` invocation) and switch automatically from terminal mode to receive mode.
- Receive individual files and batches into a configured local download directory.
- **Download directory configurable both by CLI and by the arrow-key UI.** Document a usable default; fail clearly if unavailable/unwritable.
- Validate transfer integrity with appropriate ZMODEM CRCs; handle retries and recoverable errors.
- During transfer show a temporary progress view (filename, bytes/percent, errors/retries). Connection settings can remain visible; **do not display destination directory in persistent status bar**.
- DOS filename handling: safe basenames and 8.3 fallback as needed, reject sender path traversal/absolute paths, never silently overwrite existing files, and make incomplete files distinguishable.
- Graceful handling for disk full, transfer failure, cancel, and bad destination; restore ordinary terminal mode and usable serial state afterward. Esc in progress view is a proposed local cancel action.
- Keep protocol code modular; evaluate small reference implementations but **verify source licenses** before borrowing code. Do not silently import GPL-licensed \`lrzsz\` into a project with an incompatible licensing plan.

**Deferred:** ZMODEM sending/upload and interrupted-transfer resumption.

## 8. Explicit non-goals

- Modem dialing, AT commands, phonebooks, carrier-detect modem workflows
- Telnet, SSH, or any DOS networking stack
- XMODEM/YMODEM in the initial release
- Scripting, macros, elaborate profiles, graphical or mouse interfaces
- ZMODEM upload and resume for MVP

## 9. Acceptance and milestones

1. **Serial baseline:** Menu and CLI configure a real COM port and support a stable bidirectional null-modem session on an 8088/8086-era DOS PC; clean exit.
2. **Terminal and UI:** Basic ANSI/VT100 handling, 80×24 viewport, working menu/navigation, CLI equivalence, and accurate protected bottom status bar.
3. **ZMODEM receiver:** Automatic receive from Linux \`sz\`, both single- and multiple-file cases; configured destination, CRC/retry, safe names and collisions, cancel/error recovery.
4. **Hardware/footprint validation:** Test an IBM PS/2 Model 25-class machine where available; exercise 8250-class behavior, monochrome display, slow CPU, higher baud rates, and disk-full/cancel paths. Record measured .EXE/.COM size, conventional memory and limitations.
5. **Separate release:** Move design and implementation to a dedicated \`term16\` repository, then add its built DOS executable to the full GR-DOS distribution.

## 10. Open implementation details (not blockers)

Final CLI spellings/defaults; terminal emulation subset; key shortcuts; unsupported flow-control behavior; maximum practical baud rates; default download path; file-collision and partial-download policies; project license. These are implementation choices, not reasons to expand MVP scope.
