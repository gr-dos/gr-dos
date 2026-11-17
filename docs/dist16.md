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

The current lock includes CRCSUM, DF, DIFF16, LESS, MD5SUM, TAR, TRUNCATE
and WHICH from `gr-dos`, and TICO from `tico-edit`. It leaves these out:

| Repository | Why |
|---|---|
| `gr-dos/libc16` | excluded: a C runtime library, not a DOS program |
| `gr-dos/hello16` | excluded: the template the other repositories are made from |
| `gr-dos/patch16`, `perl16`, `term16` | unavailable: no release yet |

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
   `diff16`: `diff16.exe`). If both an `.exe` and a `.com` are present, the
   `.exe` is shipped. The gr-dos/hello16 conventions make the C `.EXE` the
   reference, and the `.COM` an assembly version of it (which16,
   truncate16, crcsum16). Any other asset is ignored and shown in the
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
   README keeps it. A `source-license` one, GPL-2.0-or-later, also needs
   the program's corresponding source, which the release must provide as
   [Source licenses](#source-licenses) says. A license added after a
   release counts from the next release.

A repository that fails is reported, and recorded in the lock as a `skip`
line with the reason, so the lock shows why a program is missing:

```text
included     gr-dos/which16 v0.03 which.exe as WHICH.EXE, MIT (ignored: which.com)
excluded     gr-dos/libc16: a C runtime library, not a DOS program
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

The build checks the lock against `dist16/config` when it reads it: a
program under a `source-license` with no `source` line, or a `source`
line under a permissive license, is refused, never shipped as if it were
permissively licensed.

`fetch` downloads each asset from
`https://github.com/REPO/releases/download/TAG/ASSET`, and each license
from `https://raw.githubusercontent.com/REPO/COMMIT/LICENSE`. It checks
both against the lock, keeps them in `build/tools/dist16`, and copies them
to `build/linux/dist16` (licenses in `licenses/NAME.txt`; source archives
in `source/NAME`, and `SOURCES.TXT`). A verified file
in the cache is not downloaded again, so a rebuild needs no network, and
CI caches `build/tools` by the lock's hash. A file that does not match is a
build error, and is never used.

## Source licenses

Issue #56 lets the full distribution include programs under the GNU GPL,
starting with [gr-dos/patch16](https://github.com/gr-dos/patch16), GNU
patch 2.2, which is GPL-2.0-or-later and linked with libc16 (MIT).
`dist16/config` lists such licenses apart from the permissive ones:

```text
license MIT BSD-2-Clause BSD-3-Clause ISC Zlib 0BSD
source-license GPL-2.0-or-later
```

GR-DOS is an **aggregation of separately licensed programs**. Shipping a
GPL program beside the others, in `C:\DOS` or the ZIP, does not relicense
the GR-DOS kernel, its utilities, its MIT `*16` programs or GR-DOS as a
whole, and is not a claim that the distribution is wholly MIT licensed.
No floppy gains a GPL program: the floppies' files are chosen by the
Makefile's `FLOPPY_*` lists, and `image/files-*k.txt` must not change.

### The release's dist16.source

GitHub reports a license's family, `GPL-2.0`, for the text of the GPL
version 2: not whether the program is `GPL-2.0-only` or
`GPL-2.0-or-later`, and not where its source is. So a program whose
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
  (`GPL-2.0` for `GPL-2.0-or-later`) and in `dist16/config`; a GitHub
  `GPL-3.0`, or a manifest saying `MIT` or `GPL-2.0-only`, fails.
- **The source is this release's.** The archive must be an asset of the
  release, checked against GitHub's size and digest like the program,
  and must hold, under one top directory, the same `dist16.source` and
  license file as the commit, and the `build` file. A link to a branch,
  or GitHub's generated archive (which is not byte-stable), is not
  accepted.
- **Statically linked libraries.** Each `depends` release must exist,
  and its license (at its tag's commit) must be one `dist16/config`
  allows. Its source asset is checked the same way, and must hold its
  license file. GPL-2.0 section 3 covers the source of every module the
  program contains, other than the compiler's own system libraries.
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
  text), its notices and its libraries' licenses at the end.
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

### Leaving a program out

Add an `exclude` with its reason to `dist16/config`. The reason is
required, and goes into the lock:

```text
exclude gr-dos/foo16 experimental: its file format is not settled
```

A repository both included and excluded is an error. An `exclude` that
matches no repository is reported, so stale ones are noticed.

### Choosing the asset, or holding a release

- `include gr-dos/foo16 asset=foo.com` ships the `.COM` instead of the
  `.EXE`.
- `include gr-dos/foo16 tag=v0.02` holds the program at that release. The
  report notes each newer one.
- TICO is held at v0.02 this way, because it is on the frozen 360 KB
  floppy. It is also marked `required`, so if it cannot be included,
  `resolve` fails rather than dropping it.

## Tests

`make test-dist16` (`tests/dist16/run`) runs `scripts/dist16` against
fixtures served from `file://` URLs, in place of the GitHub API, release
downloads and raw files. It needs no network. It covers:

- **Exclusion:** `gr-dos/libc16` is excluded, a named case.
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
- **Collisions:** GR-DOS's own names, with any extension, and two programs
  with one name.
- **Licenses:** none at the release's commit, one not allowed, and one
  GitHub cannot identify.
- **Source licenses (issue #56):** a GPL-2.0-or-later program with its
  source, a notice and a linked library's source is resolved, locked,
  fetched (offline too), staged with `SOURCES.TXT`, and packaged, and
  `check-dist` accepts the ZIP and CF layouts. Each of these fails: no
  `dist16.source`, a malformed one, one without `build`, a license that
  disagrees with GitHub's (`MIT`), one `dist16/config` does not allow
  (`GPL-2.0-only`, GitHub's `GPL-3.0`), a source asset the release does
  not have, one that is the program, one that is not a `.zip` or
  `.tar.gz`, one with another license file, manifest or no build file, a
  source checksum mismatch, a notice missing at the commit, a library
  with no such release or whose source is not an archive, Open Watcom's
  runtime in the program, and a program named `SOURCES`. `check-dist`
  refuses a README without the GPL text, a missing library source, an
  unpinned file in `SOURCE`, a missing `SOURCES.TXT`, and a
  `SOURCES.TXT` with no such program; the lock is refused with a GPL
  program and no `source` line, a `source` line under MIT, or lines out
  of order; and the MIT programs beside it are locked as before.
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
convention, except diff16 0.01, which has no `--version` and prints its
version in `--help`.
