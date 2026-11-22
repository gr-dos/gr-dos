# The *16 programs (issue #36)

GR-DOS's full distribution, the CF/hard disk install's `C:\DOS` and the
release ZIP's `BIN`, includes the DOS programs of the `gr-dos` GitHub
organization's repositories whose names end in `16`. Nothing in this
repository lists them. They are found on GitHub, with a short list of
exceptions and additions in [`dist16/config`](../dist16/config). The build
uses only [`dist16/lock`](../dist16/lock), which pins each program's
release, commit and SHA-256. So the distribution changes only when the lock
changes, in a reviewed commit, and not when GitHub gains a repository or a
release.

`scripts/dist16` does the work (`perldoc scripts/dist16`):

| Command | What it does | Network |
|---|---|---|
| `make dist16-resolve` | finds the repositories, checks their releases, rewrites `dist16/lock` and reports what it included and left out | GitHub API, downloads |
| `make dist16-check` | the same report, plus how the lock differs from what `resolve` would write (exit 1 if it does) | GitHub API, downloads |
| `make` (`scripts/dist16 fetch`) | downloads what the lock pins into `build/tools/dist16`, checks it, and stages it in `build/linux/dist16` | only for files not already cached and verified |
| `make test-dist16` | the tests, against a fake GitHub | none |

## What is shipped

The current lock includes CAT, CRCSUM, DF, DIFF, EDIT, GZIP, LESS, LS,
MD5SUM, PATCH, RETROFCH, TAR, TCL, TERM16, TRUNCATE, UNAME and WHICH from `gr-dos`, TICO from
`tico-edit`, and SPROCKET from `plicease` (issue #37), with its license
notice, SPROCKET.LIC ([License assets](#license-assets)).
TCL's license is taken from a [license override](#license-overrides),
since GitHub does not recognize it.
`gr-dos/retrofetch16`'s program is `retrofch.exe`, not the repository's
stem, since `retrofetch.exe` is not an 8.3 name, so its `include` in
`dist16/config` names it with `asset=`. It leaves these out:

| Repository | Why |
|---|---|
| `gr-dos/libc16`, `libkitchen16` | excluded: library repositories (`lib*16`), not DOS programs |
| `gr-dos/hello16` | excluded: the template the other repositories are made from |
| `gr-dos/perl16` | unavailable: no release yet |

Each program goes in `C:\DOS` and the ZIP's `BIN`, after GR-DOS's own
commands. The ZIP's `README.txt` lists each one with its repository,
release and license, and ends with each one's license text. A program
under a license that requires its source, such as the GPL, also brings
that source ([Source licenses](#source-licenses)). TICO.EXE is the only one on the
boot floppies. It was there before issue #36, and it is pinned, so the
360 KB disk's files stay frozen ([M5](m5-utilities.md#floppies)). No floppy
gains a `*16` program automatically. Adding one to a floppy is a separate
decision, made in the Makefile's `FLOPPY_*` lists with the disk's free
space in mind.

## Discovery

`plicease/dos-srv16` did this first, in its Makefile's `fetch` target. It
listed the `plicease` user's repositories with
`gh repo list plicease --source`, kept the names matching `dos-*16`, and
downloaded every `.exe` asset of each one's *latest* release, along with
the extra repository `tico-edit/tico16`. Those programs have since moved to
the `gr-dos` organization and dropped the `dos-` prefix. `dist16` keeps the
idea and changes the rest:

- **Owner.** `discover gr-dos 16` lists the public repositories of the
  `gr-dos` organization (`GET /users/gr-dos/repos`, all pages), and keeps
  those whose names end in `16`, ignoring case.
- **Libraries.** A discovered repository whose name (not its owner)
  matches `lib*16`, ignoring case (`^lib.*16$`), such as `gr-dos/libc16`
  or `gr-dos/libkitchen16`, is a library, not a program. It is excluded
  before its releases are read, and is reported and locked as
  `skip REPO excluded library repository (lib*16 convention), not a DOS
  executable`, so a new library needs no `exclude` in `dist16/config`.
  An explicit `exclude` gives its own reason instead, and an `include`
  makes the repository a candidate program again. This is only about
  shipping a library *as a program* in `C:\DOS` and the ZIP's `BIN`
  (no): a program's `depends` on a library in `dist16.source` still
  resolves, verifies, fetches and ships that library's *source*
  ([Source licenses](#source-licenses)) (yes), as patch16's on libc16 does.
- **Forks, archived and private.** Forks and archived repositories are
  reported unavailable. Private ones are not listed by GitHub, and an
  `include` of one fails, because its release would not be downloadable.
  An `include` overrides fork and archived.
- **Releases.** The latest release (`GET /repos/R/releases/latest`, which
  skips drafts and prereleases), or the one `tag=` pins. A pinned draft or
  prerelease is unavailable.
- **Pinning.** `dos-srv16` always took the latest release. `dist16` takes
  it only in `resolve`, which writes the lock. The build takes only what
  the lock pins.
- **Failures.** A GitHub error that is not a 404, such as a rate limit
  (403 or 429), a server error, malformed JSON or no network, stops
  `resolve` and leaves the lock as it was, because a partial lock would
  silently drop programs. So does a `required` repository that cannot be
  included.

The API token is `GH_TOKEN` or `GITHUB_TOKEN`, or `gh auth token`. Without
one, GitHub allows 60 requests an hour. A resolve makes about four
requests per repository, so about 60 today.

## The release contract

A repository's release is shipped when it has:

1. **A program asset**, named `STEM.exe` or `STEM.com`, where STEM is the
   repository name with or without `16` (`crcsum16`: `crcsum.exe`;
   `diff16`: `diff.exe`). If both an `.exe` and a `.com` are present, the
   `.exe` is shipped, unless `prefer` chooses the `.com`
   ([Shipping the .COM](#shipping-the-com)). The gr-dos/hello16 conventions
   make the C `.EXE` the reference, and the `.COM` an assembly version of
   it (which16, truncate16, crcsum16). Any other asset is ignored and shown in the
   report. Several program names, such as `foo.exe` and `foo16.exe`, are
   ambiguous: the release fails until `asset=` chooses one.
2. **An 8.3 name** that is none of GR-DOS's own file names and no other
   program's, whatever the extension. A `MORE.EXE` would collide with
   GR-DOS's `MORE.COM`, since COMMAND.COM would run only one of them. Two
   programs with one name both fail. The Makefile passes GR-DOS's names
   (`RESERVED`).
3. **A real-mode DOS program.**
   - An `.exe` needs a sound MZ header, and no NE, LE, LX or PE header,
     COFF image or 32-bit DOS extender (DOS/4G, CWSDPMI, go32, PMODE/W,
     DOS32A).
   - A `.com` must fit its 64 KB segment, so it can be at most 65,280
     bytes.
   - The check cannot prove that the code uses only 8086 instructions.
     That rests on each project's build: the gr-dos conventions compile C
     with `wcc -0` and assemble with NASM's `cpu 8086`. less16 uses Free
     Pascal's `-Cp8086`, and tico16 documents an 8086 target.
4. **The size and SHA-256 GitHub gives** for the asset (`digest`), checked
   against the download. Without a digest, the download's SHA-256 is
   pinned as it is.
5. **A license at the release's commit**, not at `main`'s
   (`GET /repos/R/license?ref=COMMIT`), under one of the licenses in
   `dist16/config`. The `license` ones, MIT, BSD-2-Clause, BSD-3-Clause,
   ISC, Zlib and 0BSD, only require their notice to be kept, and the ZIP's
   README keeps it. A `source-license` one, GPL-2.0-or-later or
   GPL-1.0-or-later, also needs
   the program's corresponding source, which the release must provide as
   [Source licenses](#source-licenses) says. A license added after a
   release counts from the next release. A license GitHub does not
   recognize (`NOASSERTION`) fails, unless `dist16/config` has a
   [license override](#license-overrides) for the repository that the
   license file matches.

A repository that fails is reported, and recorded in the lock as a `skip`
line with the reason, so the lock shows why a program is missing:

```text
included     gr-dos/truncate16 v0.03 truncate.exe as TRUNCATE.EXE, MIT, .exe preferred (the default) (ignored: truncate.com)
excluded     gr-dos/libc16: library repository (lib*16 convention), not a DOS executable
unavailable  gr-dos/term16: no release
failed       gr-dos/foo16: v0.01: license GPL-3.0 is not one dist16/config allows
failed       gr-dos/bar16: v0.01: license GPL-2.0 needs the program's source, but there is no dist16.source at its commit
note         tico-edit/tico16 is pinned at v0.02; the latest release is v0.03
```

## The lock

`dist16/lock` is written only by `resolve`, sorted by repository, so the
same GitHub state always gives the same lock. Each program line holds:

```text
program REPO TAG COMMIT ASSET NAME SIZE SHA256 SPDX LICENSE LICENSE_SHA256
```

A program under a source license is followed by its source, its further
notices and its linked libraries' source (below):

```text
source REPO ASSET SIZE SHA256 BUILD
notice REPO PATH SHA256
depend REPO DEP TAG COMMIT ASSET SIZE SHA256 SPDX LICENSE LICENSE_SHA256
```

A program whose `include` has `license-asset=` is followed right away
by its [license asset](#license-assets):

```text
license-asset REPO ASSET NAME SIZE SHA256
```

A program under a [license override](#license-overrides) is followed by
the override, then its notices:

```text
override REPO GITHUB SPDX LICENSE SHA256
notice REPO PATH SHA256
```

The build checks the lock against `dist16/config` when it reads it: a
program under a `source-license` with no `source` line, or a `source`
line under a permissive license, is refused, never shipped as if it were
permissively licensed. An `override` line must be the config's
`license-override` for the repository, with the same license, file,
SHA-256 and notices, and the program's own license. A program under the
license of its repository's `license-override` must have the line, and
so its notices: without it, the lock would not record that GitHub did
not recognize the license, nor what was verified instead.

`fetch` downloads each asset from
`https://github.com/REPO/releases/download/TAG/ASSET`, and each license
from `https://raw.githubusercontent.com/REPO/COMMIT/LICENSE`. It checks
both against the lock, keeps them in `build/tools/dist16`, and copies them
to `build/linux/dist16` (licenses in `licenses/NAME.txt`; source archives
in `source/NAME`, and `SOURCES.TXT`). A verified file
in the cache is not downloaded again, so a rebuild needs no network, and
CI caches `build/tools` by the lock's hash. A file that does not match is a
build error, and is never used.

## License assets

Most projects' license is their repository's `LICENSE`, which the ZIP's
README carries. Some release the program's license notice as an asset of
its own, to go with the executable. plicease/sprocket does (issue #37):
its `SPROCKET.EXE` links [libc16](https://github.com/gr-dos/libc16)
instead of Open Watcom's runtime, and each release from 0.5.1 has
`sprocket-exe-license.txt` beside `sprocket.exe`. It is SPROCKET's MIT
`LICENSE`, and covers libc16 too, since the two have the same text and
holder; SPROCKET's release job fails if they differ. The project asks
that it ship with the program, so `dist16/config` names it:

```text
include plicease/sprocket asset=sprocket.exe license-asset=sprocket-exe-license.txt
```

- **Checked like the program.** The asset must be in the release, and is
  checked against GitHub's size and digest.
- **The license GitHub finds.** It must be the license file at the
  release's commit (`LICENSE`), byte for byte, so the README's notice and
  the shipped one are the same text. A release whose asset differs fails
  until someone reads it and decides what to do.
- **Pinned.** The lock has a `license-asset` line right after the
  program's, with its size and SHA-256, and its DOS name: the program's,
  with `.LIC` for its extension (`SPROCKET.LIC`). The lock is refused if
  the line is not the config's `license-asset=`, or is missing.
- **Shipped beside the program.** `fetch` stages it, `list` names it
  after the program, so it goes in `C:\DOS` and the ZIP's `BIN` right
  after `SPROCKET.EXE`, and `bin-list` gives it a line in the README.
  `check-dist` checks it in the ZIP's tree and the CF files, against the
  lock.

`sprocket.exe` is not a `*16` repository's, and its releases also hold the
Linux and Windows host programs, so `asset=` names it. `SPROCKET.EXE` is
on no floppy, like the other programs after TICO.

## License overrides

GitHub's license detector (Licensee) knows only some licenses. For any
other, such as the Tcl license (SPDX `TCL`), it reports `NOASSERTION`,
even when the file is that license and nothing else. That is a limit of
the detector, not a reason to relicense a program, so `dist16/config` can
name the license of one repository itself (issue #83):

```text
license MIT BSD-2-Clause BSD-3-Clause ISC Zlib 0BSD TCL
license-override gr-dos/tcl16 TCL LICENSE sha256=b9ee1e75... notice=vendor/LICENSE.tinytcl
```

It is an exception to GitHub's detection, not to the license check, and
it is narrow:

- **One repository, one file, exact bytes.** It applies only to that
  repository, only when GitHub reports `NOASSERTION` for that file at the
  commit of the release `resolve` takes, and only when the file's bytes,
  fetched from that commit (not `main`), have that SHA-256. Another file,
  a missing one, or other bytes (a changed license, or a new release's)
  fail, as without the override, until someone reads the new file and
  updates the SHA-256 in a reviewed change.
- **A license the config allows.** The SPDX identifier must also be one
  of the `license`s, so an override is only ever to a permissive license,
  and never decides whether a program's source is shipped. `NOASSERTION`
  itself is never allowed.
- **GitHub first.** A license GitHub does recognize is used as before,
  and the report notes the override is not used. If GitHub comes to
  recognize the override's own license, the program fails until the
  override is removed, so a lock never holds that license for the
  repository without its `override` line.
- **Notices.** Each `notice=` is a further file at the same commit that
  the license names, such as Tiny Tcl's own license for Tcl16. It is
  pinned in the lock and shipped after the license, in the ZIP's README.
- **Visible.** The lock's `override` line records what GitHub reported
  and what the override verified, and the report says so:

```text
included     gr-dos/tcl16 v0.01 tcl.exe as TCL.EXE, TCL by license-override (GitHub finds NOASSERTION; LICENSE SHA-256 verified, notice vendor/LICENSE.tinytcl)
```

## Source licenses

Issue #56 lets the full distribution include programs under the GNU GPL.
Two families are allowed:

| License | GitHub reports | For |
|---|---|---|
| `GPL-2.0-or-later` | `GPL-2.0` | [gr-dos/patch16](https://github.com/gr-dos/patch16), GNU patch 2.2, linked with libc16 (MIT); [gr-dos/gzip16](https://github.com/gr-dos/gzip16), GNU gzip 1.2.4's own 1993 MS-DOS program, unchanged, linked with nothing of ours (issue #103) |
| `GPL-1.0-or-later` | `GPL-1.0` | [gr-dos/perl16](https://github.com/gr-dos/perl16), whose Perl 3.044 is GPL version 1 or later |

`dist16/config` lists them apart from the permissive licenses:

```text
license MIT BSD-2-Clause BSD-3-Clause ISC Zlib 0BSD
source-license GPL-2.0-or-later GPL-1.0-or-later
```

Both are under the same contract, below. The `-only` forms are not
allowed, and neither is any other GPL version: a program needs a config
change, reviewed, to add one.

GR-DOS is an **aggregation of separately licensed programs**. Shipping a
GPL program beside the others, in `C:\DOS` or the ZIP, does not relicense
the GR-DOS kernel, its utilities, its MIT `*16` programs or GR-DOS as a
whole, and is not a claim that the distribution is wholly MIT licensed.
No floppy gains a GPL program: the floppies' files are chosen by the
Makefile's `FLOPPY_*` lists, and `image/files-*k.txt` must not change.

### The release's dist16.source

GitHub reports a license's family, `GPL-2.0` for the text of the GPL
version 2 and `GPL-1.0` for version 1's: not whether the program is
`-only` or `-or-later`, and not where its source is. So a program whose
license GitHub finds in a `source-license` family ships only if its
repository has a `dist16.source` at the release's commit:

```text
# patch16's corresponding source, for GR-DOS (docs/dist16.md there)
license GPL-2.0-or-later
source patch16-0.01-src.tar.gz
build BUILDING.md
notice AUTHORS
depends gr-dos/libc16 v0.07 libc16-0.07-src.zip
```

| Directive | Meaning |
|---|---|
| `license SPDX` | the exact license, one of `dist16/config`'s `source-license`s, in GitHub's family |
| `source ASSET` | the asset of the same release that is the program's complete source: a `.zip`, `.tar.gz` or `.tgz` |
| `build PATH` | the build instructions and scripts, a file in that archive |
| `notice PATH` | a further notice to keep, at the commit and in the archive (any number) |
| `depends REPO TAG ASSET` | a library linked into the program: its release, and that release's asset with its source (any number) |

`resolve` checks all of it, and a program fails, and is left out with the
reason, if anything is missing, unverifiable or contradictory:

- **No manifest**, or a malformed one: a GPL program is never treated as
  permissively licensed.
- **The license.** `dist16.source`'s license must be in GitHub's family
  (`GPL-2.0` for `GPL-2.0-or-later`, `GPL-1.0` for
  `GPL-1.0-or-later`) and in `dist16/config`. A GitHub `GPL-3.0`, a
  manifest saying `MIT`, `GPL-2.0-only` or `GPL-1.0-only`, or one whose
  version is not the license file's (`GPL-2.0-or-later` over GPL version
  1's text, or the reverse), fails.
- **The license text is the program's own.** The lock pins the license
  file GitHub found at the commit (`COPYING`), by SHA-256, and the source
  archive must hold the same file. That text is what the ZIP's README and
  `SOURCES.TXT` carry: a GPL version 1 program keeps the version 1 text,
  never a substituted version 2 notice.
- **The source is this release's.** The archive must be an asset of the
  release, checked against GitHub's size and digest like the program,
  and must hold, under one top directory, the same `dist16.source` and
  license file as the commit, and the `build` file. A link to a branch,
  or GitHub's generated archive (which is not byte-stable), is not
  accepted.
- **Statically linked libraries.** Each `depends` release must exist,
  and its license (at its tag's commit) must be one `dist16/config`
  allows. Its source asset is checked the same way, and must hold its
  license file. Section 3 of both GPL versions covers the source of every
  module the program contains, other than the system's or compiler's own
  standard libraries.
- **No Open Watcom runtime.** Using Open Watcom as a compiler and linker
  does not bring its license with it, but linking its C runtime would.
  An `.exe` under a source license that carries Open Watcom's runtime
  banner (`WATCOM C/C++ Run Time`) fails: it must be linked only with
  libraries its manifest names. patch16 is linked with libc16, as
  GR-DOS's own C utilities are.

### Where the source goes

- **The release ZIP** holds each archive, the program's and its
  libraries', in `SOURCE/NAME/` (`SOURCE/PATCH16/patch16-0.01-src.tar.gz`),
  so everyone who gets the ZIP gets the source with it. `README.txt` has a
  *Corresponding source* section naming each archive by its GitHub URL,
  SHA-256 and place in the ZIP, and the program's license (the full GPL
  text, of the version its project ships), its notices and its libraries' licenses at the end.
- **A CF card or hard disk** (`scripts/deploy-cf`) has `C:\DOS\SOURCES.TXT`,
  the same section with the license texts, but not the archives: the CF
  files are DOS 8.3 names, staged through a 1.44 MB image. It tells the
  reader to get them from the ZIP of the same release, or from GitHub at
  the pinned URLs, and check them with `sha256sum`. Both are release
  assets, kept with the release, not files on a branch. If you hand on a
  card, hand on the ZIP with it, or be ready to provide its `SOURCE`
  directory.
- `SOURCES.TXT` and `SOURCE` exist only when some program is under a
  source license; no program may be named `SOURCES`.

`make dist` runs `scripts/dist16 check-dist` on the ZIP's tree, and `make`
on the CF files: each program under a source license must be there with
every archive the lock pins, and its license texts in full, in
`README.txt` and `SOURCES.TXT`, and nothing else in `SOURCE`. The CF
tests (`make test-deploy-cf`) check that `C:\DOS\SOURCES.TXT` is
installed unchanged, or absent when there is no such program.

### patch16

Nothing in the build names patch16: like any `gr-dos/*16`, it is found
on GitHub, and today it has no release (`skip gr-dos/patch16 unavailable
no release`). Before it can ship, its release needs:

1. `dist16.source` at the release's commit, as above, with its `COPYING`
   (the GPL version 2), and any further notice GNU patch's terms ask to
   keep;
2. a source archive asset of the tree at that commit (for example
   `git archive --prefix=patch16-VERSION/`), with its build scripts;
3. a source asset for the libc16 release it is linked with: libc16's
   release ZIP holds its headers and libraries, not its C source, so a
   libc16 release must add one, such as `libc16-VERSION-src.zip`.

Then `make dist16-resolve` adds it to `dist16/lock`, which is reviewed
and committed in its own change (issue #56), with the floppy manifests
unchanged.

## Updating, and reviewing an update

CI's `Check dist16/lock against GitHub` step runs `make dist16-check` on
every build. It is informational: when it fails, a repository or release
has appeared, or one has changed, since the lock was written. The build
still uses the lock. To take the change:

1. `make dist16-resolve`, and read its report.
2. Review `git diff dist16/lock`:
   - every `program` line that is new or changed is a release that will
     ship, with its tag and commit;
   - every `skip` line is a program that will not, with the reason.
3. `make` and `make test`. The CF boot test (`make test-deploy-cf`) runs
   each program from `C:\DOS` and checks that it reports the version the
   lock pins. The floppies' manifests (`image/files-*k.txt`) must not
   change.
4. Commit `dist16/lock`, in its own commit or with the change that needed
   it.

### Adding a new gr-dos/foo16

Nothing here needs to change. Make the repository from gr-dos/hello16,
release it with `foo.exe` (or `foo.com`) and a license, and run
`make dist16-resolve`. If FOO's name collides with one of GR-DOS's own,
rename the program.

### Adding a program from another owner

Add a line to `dist16/config`, with `tag=` to pin a release if you want
one, and run `make dist16-resolve`:

```text
include someone/tool16
```

If its repository's name does not end in `16`, or its release holds other
programs, name the DOS one with `asset=`. If the release gives the
program's license notice as an asset, name that with `license-asset=`
([License assets](#license-assets)), as plicease/sprocket's does.

### Leaving a program out

Add an `exclude` with its reason to `dist16/config`. The reason is
required, and goes into the lock:

```text
exclude gr-dos/foo16 experimental: its file format is not settled
```

A repository both included and excluded is an error. An `exclude` that
matches no repository is reported, so stale ones are noticed. A `lib*16`
library needs no `exclude` ([Discovery](#discovery)).

### Shipping a lib*16 repository as a program

A repository named `lib*16` is excluded as a library. If one also
releases a DOS program to ship, `include` it, which is the exception to
the convention:

```text
include gr-dos/libfoo16
```

### Choosing the asset, or holding a release

- `include gr-dos/foo16 asset=foo.com` ships that exact asset. To choose
  the `.COM` over the `.EXE` without naming the file, use `prefer=com`
  ([Shipping the .COM](#shipping-the-com)).
- `include gr-dos/foo16 tag=v0.02` holds the program at that release. The
  report notes each newer one.
- TICO is held at v0.03 this way, because it is on the frozen 360 KB
  floppy. It is also marked `required`, so if it cannot be included,
  `resolve` fails rather than dropping it.

### Shipping the .COM

Many releases have both a C `STEM.exe` and an assembly `STEM.com`
(issue #42). The `.COM` is smaller, which matters on a crowded boot floppy
and a little on C:

| Repository | `.exe` | `.com` |
|---|---:|---:|
| which16 v0.04 | 4,252 | 2,545 |
| truncate16 v0.03 | 5,728 | 3,294 |
| crcsum16 v0.03 | 5,948 | 3,417 |

The `.EXE` is still the default. It is the reference build under the
gr-dos/hello16 conventions, and the `.COM` is tested against it
(`make -C asm test`). Some repositories also call their assembly version
experimental (truncate16's README). So each program's choice weighs size
against how mature its `.COM` is, and each change shows up in review as a
change to `dist16/lock`.

WHICH is shipped as `WHICH.COM` this way (issue #80): which16 v0.04's
`.COM` has its heap-exhaustion fix (which16 PR #9) and is compared
against the C build in which16's tests. The others ship their `.EXE`.

To ship one repository's `.COM`:

```text
include gr-dos/which16 prefer=com
```

Or make the `.COM` the default, and keep the `.EXE` where wanted:

```text
prefer com
include gr-dos/truncate16 prefer=exe
```

`prefer=` on an `include` overrides `prefer`. Either one falls back to the
other kind when a release has only one. Unlike `asset=which.com`, a
preference still works if the program is renamed, and it records the
reason for the choice. `asset=` names the exact file, so it overrides
`prefer`. Using `asset=` and `prefer=` on one `include` is an error, as is
a second `prefer`. The report says which was chosen, and why:

```text
included     gr-dos/which16 v0.04 which.com as WHICH.COM, MIT, .com preferred (prefer=com) (ignored: which.exe)
included     gr-dos/df16 v0.02 df.exe as DF.EXE, MIT, no .com, so the .exe (prefer com)
included     gr-dos/crcsum16 v0.03 crcsum.exe as CRCSUM.EXE, MIT, .exe preferred (the default) (ignored: crcsum.com)
```

## Tests

`make test-dist16` (`tests/dist16/run`) runs `scripts/dist16` against
fixtures served from `file://` URLs, in place of the GitHub API, release
downloads and raw files. It needs no network. It covers:

- **Exclusion:** `gr-dos/hello16` is excluded by name, and the `lib*16`
  libraries (`libc16`, `libkitchen16`, `libfoo16`, and `LibMixed16` in
  mixed case) by the naming convention, with no `exclude`, while
  `diff16`, `patch16` and `perl16` are programs; an `include` of a
  library ships it, and a GPL program's `depends` on the excluded
  `libc16` still resolves its source.
- **Include and exclude precedence:** include and exclude of one
  repository, an exclude without a reason, an include of another owner's
  repository, an include of a discovered repository (pinned, with no
  duplicate), and an exclude that matches nothing.
- **Releases:** no release, a pinned release that does not exist, and a
  prerelease.
- **Repositories:** a fork (and an included one), archived, and private.
- **Malformed releases:** bad JSON, no assets, an asset without a name, a
  size mismatch, and a malformed digest.
- **Checksums:** a mismatch with GitHub's, and a changed asset at fetch.
- **Asset names:** only unexpected assets, `.exe` with `.com`, `asset=`
  (and `asset=` naming nothing), an ambiguous `STEM`/`STEM16`, and a name
  that is not 8.3.
- **Preference (issue #42):** `prefer=com` ships the `.com`, and falls back
  to the `.exe` when there is none. A global `prefer com` is overridden by
  `prefer=exe` and by `asset=`. Each choice is in the report. `asset=` with
  `prefer=`, a bad value, and a second `prefer` are errors.
- **Collisions:** GR-DOS's own names, with any extension, and two programs
  with one name.
- **Licenses:** none at the release's commit, one not allowed, and one
  GitHub cannot identify.
- **Source licenses (issue #56):** a GPL-2.0-or-later and a
  GPL-1.0-or-later program, each with its source, a notice and a linked
  library's source, are resolved, locked, fetched (offline too), staged
  with `SOURCES.TXT`, and packaged, and `check-dist` accepts the ZIP and
  CF layouts. The GPL-1.0-or-later program keeps the GPL version 1 text,
  as its project gives it. Each of these fails: no `dist16.source`, a
  malformed one, one without `build`, a license that disagrees with
  GitHub's (`MIT`), one `dist16/config` does not allow (`GPL-2.0-only`,
  `GPL-1.0-only`, GitHub's `GPL-3.0`), a manifest version that is not
  GitHub's (`GPL-2.0-or-later` for GitHub's `GPL-1.0`, and the reverse),
  a source asset the release does not have, one that is the program, one
  that is not a `.zip` or `.tar.gz`, one with another license file (a
  version 2 `COPYING` for a version 1 program), manifest or no build
  file, a source checksum mismatch, a notice missing at the commit, a
  library with no such release or whose source is not an archive, Open
  Watcom's runtime in the program, and a program named `SOURCES`; the
  missing manifest, other license file and library failures are tested
  for GPL-1.0-or-later too. `check-dist` refuses a README without the GPL
  text, a missing library source, an unpinned file in `SOURCE`, a missing
  `SOURCES.TXT`, and a `SOURCES.TXT` with no such program; the lock is
  refused with a GPL program and no `source` line, a `source` line under
  MIT, or lines out of order; and the MIT programs beside it are locked
  as before.
- **License assets (issue #37):** another owner's program with
  `asset=` and `license-asset=`, locked with its `license-asset` line,
  listed, staged as `STEM.LIC` (offline too), and checked in the CF and
  ZIP layouts. Each of these fails: a release without the asset, an
  asset that is not the license at the commit, one that does not match
  GitHub's digest, a corrupt cached copy, a changed or missing `.LIC` in
  the distribution, a lock line the config does not name, another asset
  than it names, none when it names one, a line with another SHA-256 or
  DOS name, or out of place, and `license-asset=` naming the program.
- **Architecture:** PE, NE, COFF behind a stub, a DOS extender, no MZ
  header, a malformed MZ header, and a `.COM` over 65,280 bytes (with one
  at exactly 65,280).
- **GitHub failures:** a rate limit (403), a server error, and an unknown
  owner. Each leaves the lock unchanged, and so does a `required`
  repository with no release.
- **Determinism and reproducibility:** resolve gives the same lock twice;
  `check` reports a new release as drift without changing the lock;
  `fetch` reproduces the files offline from the cache, refuses a corrupt
  cache, refuses a malformed or colliding lock, and will not remove a
  directory it did not make.

The CF boot test (`make test-deploy-cf`) runs every locked program from
`C:\DOS`. Each prints its version with `--version`, the gr-dos
convention, except those that have none: TCL prints its version with
`/?`, SPROCKET in its usage, with no subcommand, and GZIP, GNU's gzip
1.2.4, gives that version, not gzip16's, with `-V`.
