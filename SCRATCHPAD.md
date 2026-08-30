# Maintenance scratchpad

This is current state for `/maintain`. The skill updates or removes stale
entries on every maintenance cycle and appends one compact history entry.

## Baseline

- Last completed maintenance: 2026-08-29.
- Upstream base: `fb1b6b66476fc83c1453b0cde8fe2a50166eb395`
  (`neurosnap/zmx:main`, "fix(docs): remove stale list --where references
  (#250)").
- Published integration: `2ffb1c1e425f56a996577d344f24417f8dd6d603`, 25
  commits above the base, with protocol version 1 unchanged.
- Companion pin in fmx: commit `2ffb1c1e425f`, build
  `0.7.0+fmx.2ffb1c1e425f`, moved by `scripts/pin-companion.sh` in fmx commit
  `89a4041a962c35f763d132a49452c238af904e2d`. The editable fmx Companion was
  refreshed to the same build. This pin on fmx main is not itself a release.
- Gate as last run: formatting, Debug build, Zig tests, bats 94/94, and the
  Companion ReleaseFast build passed; macOS and Linux compile checks also
  passed. Clean fmx main passed typecheck, 342 tests with one expected skip,
  and the Companion-backed PTY test 1/1 against that exact build.

## Carried state

Every entry below remains downstream-only at upstream `fb1b6b6`; that
baseline's changes and current implementation were read, and no upstream
replacement satisfies one. Every listed commit is an ancestor of the exact
published integration and passed the fork and fmx gates above. Each feature is
retired only after an equivalent upstream implementation is read and its path
exercised.

- Portable wire: `e0da029`, `5c07655`, `bf2cc50`.
- Negotiated clients: `a094f6c`, `9e33017`, `079e9f5`.
- Multi-client terminal ownership and opt-in final-client lifecycle:
  `906fa49`, with mouse-motion and focus-gain ownership in `2ffb1c1`.
- Restore and exit: `31d37d1`, `fdd778b`, `551518a`, `af4cfa2`, `f295b3a`.
- Create: `afdf25b`, with cross-feature review repairs in `f1f7645` and
  `dab954b`, and creator-environment handling in `6526e5e`.
- Discovery and records: `241efd3`, `43e4e1b`, with the relevant review
  repair in `f1f7645` and swept-socket record preservation in `6526e5e`.
- Scrollback: `452f452`, `15327ca`; its early-ending transfer race test is
  made deterministic by `e4064d1`.
- Companion build: `52d25cf`, `b5889fb`, `8a536ca`.

## Offers

- No pull request is open. The two defects written fresh against `ea45749`
  remain filed as issues with their adversarially reviewed proof-of-concept
  tags: [#246](https://github.com/neurosnap/zmx/issues/246)
  (`poc/first-attach-output` → `a68c809`) and
  [#247](https://github.com/neurosnap/zmx/issues/247)
  (`poc/attach-exit-status` → `53407fe`). Both are open with no comments as
  of 2026-08-29, and upstream `fb1b6b6` contains neither replacement. Local
  `fix/*` branches of the same commits exist in `~/src/zmx` and are not
  published. `fix/daemon-dev-tty` is specified, not cut. #127 remains open;
  there has been no maintainer response since our 2026-08-22 comment.

## Current notes

- `fdd778b` now observes child status with `waitid(P_PID, WEXITED | WNOHANG |
  WNOWAIT)` and leaves the zombie to pin its PID and process group until the
  teardown's single `waitpid`; the prior PID-reuse signalling note is
  resolved. `551518a` keeps a scripted attach alive after non-terminal stdin
  EOF so it receives `Exit` and returns the exact child status.
- Upstream removed stock zmx's stale `list --where` documentation at
  `fb1b6b6`; the fork's real `--where` implementation, README help, and fish
  completion remain together in `241efd3`.
- Final reconciliation has `main` at `fb1b6b6` and `integration` at
  `2ffb1c1`. It preserves `push-onwykpqrsxty` at `c5072cf`,
  `push-rzzukqmnkpss` at `d5fa1ea`, and `push-vtznxtxsltwy` at `a67197e`.
  There are no open pull-request heads or `DELETEME/*` markers.
- `~/src/zmx` has a gitignored `zig-pkg/` from early tranches; a fresh
  worktree builds from the global Zig cache without it.

## History

- 2026-08-23: Seeded the workshop from the end of tranche 6 and reconciled
  the fork's branch namespace for the first time. No maintenance cycle has
  run. Later that day: the first Linux Companion build (fmx's 0.2.0 release
  run) exposed the @cImport stat; fixed on `integration` and the pin moved
  through `pin-companion.sh` — its first real use.
- 2026-08-23: Added multi-client terminal sizing and opt-in final-client
  lifecycle as `0081b6e`, gated the 24-commit stack, published `integration`,
  and transactionally moved fmx to build `0.7.0+fmx.0081b6ea9795` (346 tests,
  12/12 PTY).
- 2026-08-23: Made passive mouse motion and focus gain take sizing ownership
  as `bea6677`, gated and published the 25-commit stack, moved fmx to
  `0.7.0+fmx.bea6677b7762` (361 tests, 12/12 PTY), and made a failed pin gate
  restore `companion.json` byte for byte.
- 2026-08-25: Removed automatic branch deletion inference and atomically
  restored the three fork-local upstream `push-*` copies from their accidental
  `DELETEME/*` names without changing their tips.
- 2026-08-29: Advanced the mirror to `fb1b6b6`, repaired and adversarially
  reviewed the rebased stack, gated and published `2ffb1c1` under the original
  lease, moved fmx to its matching build in `89a4041`, and reconciled the
  namespace while preserving all three `push-*` heads. Updated the workshop
  entrypoint to the installed shared-skill namespace.
