# Maintenance scratchpad

This is current state for `/maintain`. The skill updates or removes stale
entries on every maintenance cycle and appends one compact history entry.

## Baseline

- Last completed maintenance: none — the fork was built in six tranches
  (2026-08-22/23) before this workshop existed; this is the seeded state.
- Upstream base: `ea45749` (`neurosnap/zmx:main`, "fix(docs): handle session
  prefixes in picker (#239)").
- Published integration: `2c79c4dd2f3b7caaf1f555f49bba5353b4e34858`, 22
  commits above the base (`2c79c4d` fixed the Linux build: libc's
  `struct stat` is opaque under musl through @cImport; statx/fstatat now).
- Companion pin in fmx: commit `2c79c4dd2f3b`, build `0.7.0+fmx.2c79c4dd2f3b`,
  moved by `scripts/pin-companion.sh` on 2026-08-23 (fmx 363 pass, e2e 5/5
  against it). fmx 0.2.0 — the first release of the pair — is building on
  the GitHub runners; `latest.txt` still serves a lone-`fmx` 0.1.1 archive
  until it publishes.
- Gate as last run (end of tranche 6): `zig build test` green; bats 92/93
  with the timing-sensitive `create.bats` history case; fmx 361 pass and e2e
  5/5 against the ReleaseFast Companion build.

## Carried state

Stack commits, bottom to top, against the inventory in `MAINTAIN.md`:

- Portable wire: `9f75428` (freeze Header and Resize bytes), `3b3063b`
  (explicit little-endian codec and frame cap), `9bca39a` (refusal bytes and
  the constants fmx mirrors).
- Negotiated clients: `cc7c6ed` (Hello/Welcome and client phase), `7709119`
  (a refused client acts on nothing), `78f16f9` (oversized frame, late Hello,
  silent handshake).
- Restore and exit: `4e29345` (explicit restore boundary, exact exit),
  `23e5519` (never block the daemon on an uncertain reap), `e81ef16` (wind a
  session down once), `14e6b2e` (daemonize returns on an acknowledged exec —
  the `fix/first-attach-restore` offer's subject), `ae68e80` (stdout and
  stderr as streams). The attach exit status (`fix/attach-exit-status`) is
  inside `4e29345`/`23e5519`.
- Create: `ae52fa0`; discovery: `718e4d3`; records and forget: `bbb26d4`;
  their review rounds `702f9e3`, `c483f60`.
- Scrollback: `d06399d`, `54e7229`.
- Created child environment and swept-socket record: `1c933f1`.
- Companion build: `d378b52`, `652a151`, `2c79c4d`.

## Offers

- No pull request is open. Two defects were written fresh against
  `ea45749`, adversarially reviewed (two Opus reviewers each, high effort;
  the exit-status one was rewritten on their findings), and filed as issues
  with proof-of-concept commits on the fork's `poc/*` tags rather than
  offered, since the pinned Companion is not affected and nothing of ours
  waits on upstream: [#246](https://github.com/neurosnap/zmx/issues/246)
  (`poc/first-attach-output` → `a68c809`) and
  [#247](https://github.com/neurosnap/zmx/issues/247)
  (`poc/attach-exit-status` → `53407fe`). Local branches `fix/*` of the same
  commits exist in `~/src/zmx` and are not published. `fix/daemon-dev-tty`
  is specified, not cut. Our last word on #127 is the newest comment there,
  with no maintainer response as of 2026-08-22.

## Current notes

- `integration` is `d951390`, one test-only commit above the pin
  (`2c79c4d`): `create.bats`'s early-ending-history case now stops the
  daemon before asking, so it cannot lose the race to a release build. The
  pin need not move for it. A full `bats test/` once stalled at
  `run: requires a command argument` and then ran 93/93; a `zmx run`
  with no command still forks its daemon before refusing, and the daemon
  closes only fds below 64, so a long bats run may hand it a higher pipe
  fd that keeps `run` waiting — unproven, worth a look if it recurs.

- **For the next cycle:** the stack reaps the child at pty EOF (`23e5519`)
  and the teardown still sends SIGHUP/SIGKILL to the process group `-pid`
  (`handleKill`), so a pid reused within the ~1.5 s between them could be
  signalled. Deliberate in the fork (backgrounded children must not outlive
  the session), negligible in practice, but `waitid(P_PID, pid, WEXITED |
  WNOHANG | WNOWAIT)` reads the status without reaping — the zombie keeps
  pid and pgid pinned until the teardown's own `waitpid` — and removes the
  window. Found by the #247 review; `poc/attach-exit-status` shows the call.

- Fork branches were reconciled on 2026-08-23: local, origin, and fork `main`
  all name `ea45749`; `integration` is `652a151`; the three `push-*` heads
  mirrored from upstream's pico.sh CI when the fork was made are preserved
  under `DELETEME/push-*`. No branch remains pending quarantine. Local `main`
  pulls from `origin/main` and pushes to `fork/main`.
- `~/src/zmx` has a gitignored `zig-pkg/` from early tranches; a fresh
  worktree builds from the global Zig cache without it.

## History

- 2026-08-23: Seeded the workshop from the end of tranche 6 and reconciled
  the fork's branch namespace for the first time. No maintenance cycle has
  run. Later that day: the first Linux Companion build (fmx's 0.2.0 release
  run) exposed the @cImport stat; fixed on `integration` and the pin moved
  through `pin-companion.sh` — its first real use.
