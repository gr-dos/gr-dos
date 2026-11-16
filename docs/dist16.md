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
commands. The ZIP's `README.txt` lists each one with its repository and
release, and ends with each one's license. TICO.EXE is the only one on the
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
   `dist16/config`: MIT, BSD-2-Clause, BSD-3-Clause, ISC, Zlib and 0BSD.
   All of these only require their notice to be kept, and the ZIP's README
   keeps it. A license added after a release counts from the next release.

A repository that fails is reported, and recorded in the lock as a `skip`
line with the reason, so the lock shows why a program is missing:

```text
included     gr-dos/which16 v0.03 which.exe as WHICH.EXE, MIT (ignored: which.com)
excluded     gr-dos/libc16: a C runtime library, not a DOS program
unavailable  gr-dos/term16: no release
failed       gr-dos/foo16: v0.01: license GPL-3.0 is not one dist16/config allows
note         tico-edit/tico16 is pinned at v0.02; the latest release is v0.03
```

## The lock

`dist16/lock` is written only by `resolve`, sorted by repository, so the
same GitHub state always gives the same lock. Each program line holds:

```text
program REPO TAG COMMIT ASSET NAME SIZE SHA256 SPDX LICENSE LICENSE_SHA256
```

`fetch` downloads each asset from
`https://github.com/REPO/releases/download/TAG/ASSET`, and each license
from `https://raw.githubusercontent.com/REPO/COMMIT/LICENSE`. It checks
both against the lock, keeps them in `build/tools/dist16`, and copies them
to `build/linux/dist16` (licenses in `licenses/NAME.txt`). A verified file
in the cache is not downloaded again, so a rebuild needs no network, and
CI caches `build/tools` by the lock's hash. A file that does not match is a
build error, and is never used.

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
