# Maintenance scratchpad

This is current state for `/maintain`. The skill updates or removes stale
entries on every maintenance cycle and appends one compact history entry.

## Baseline

- Last completed maintenance: none — the fork was built in six tranches
  (2026-08-22/23) before this workshop existed; this is the seeded state.
- Upstream base: `ea45749` (`neurosnap/zmx:main`, "fix(docs): handle session
  prefixes in picker (#239)").
- Published integration: `652a151698ded52246c578f63e1c69d57d6e3b32`, 21
  commits above the base.
- Companion pin in fmx: commit `652a151698de`, build `0.7.0+fmx.652a151698de`
  (fmx `main` `0de23fa`). No fmx release carries the pair yet; `latest.txt`
  still serves a lone-`fmx` 0.1.1 archive.
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
- Companion build: `d378b52`, `652a151`.

## Offers

- None open. Two candidates are specified in `MAINTAIN.md` (§Upstream); neither
  branch has been cut. Our last word on #127 is the newest comment there, with
  no maintainer response as of 2026-08-22.

## Current notes

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
  run.
