# Maintenance scratchpad

This is current state for `/maintain`. The skill updates or removes stale
entries on every maintenance cycle and appends one compact history entry.

## Delivered baseline

- Last completed maintenance: 2026-08-29.
- Upstream base: `fb1b6b66476fc83c1453b0cde8fe2a50166eb395`
  (`neurosnap/zmx:main`, "fix(docs): remove stale list --where references
  (#250)").
- Published integration: `2ffb1c1e425f56a996577d344f24417f8dd6d603`, 25
  commits above the base, with protocol version 1 unchanged.
- Companion pin in smolmux: commit `2ffb1c1e425f`, build
  `0.7.0+fmx.2ffb1c1e425f`, moved by `scripts/pin-companion.sh` in smolmux commit
  `89a4041a962c35f763d132a49452c238af904e2d`. The editable smolmux Companion was
  refreshed to the same build. This pin on smolmux main is not itself a release.
- Gate as last run: formatting, Debug build, Zig tests, bats 94/94, and the
  Companion ReleaseFast build passed; macOS and Linux compile checks also
  passed. Clean smolmux main passed typecheck, 342 tests with one expected skip,
  and the Companion-backed PTY test 1/1 against that exact build.

## Audited-upstream frontier

- Frontier: `fb1b6b66476fc83c1453b0cde8fe2a50166eb395`, completed
  2026-08-29.
- The prior frontier was reconstructed as
  `ea45749278bac648ab13a4280a6035012854d717`, completed 2026-08-23 by the
  six-tranche fork build and recorded by the workshop seed. The later delivered
  Integration base was not substituted for it. The aggregate audit range was
  `ea45749278bac648ab13a4280a6035012854d717..fb1b6b66476fc83c1453b0cde8fe2a50166eb395`
  (2 commits): v0.7.1 release documentation and synchronous release jobs,
  documenting a compatibility fix already inside the prior frontier, followed
  by removal of stock zmx's stale `list --where` references. No new upstream
  runtime capability landed in the range.
- Dispositions: retire (0), repair (1) — Discovery and records, whose real
  fork `--where` implementation already restored accurate README/help/fish
  completion in `241efd3`; unchanged (7) — Portable wire, Negotiated clients,
  Multi-client terminal ownership, Restore and exit, Create, Scrollback, and
  Companion build. The audit found no missed product repair.

## Carried state

Every entry below remains downstream-only at the audited-upstream frontier
`fb1b6b6`; current upstream semantics were inspected against every entry, and
no upstream replacement satisfies one. Every listed commit is an ancestor of
the exact published integration and passed the fork and smolmux gates above. Each
feature is retired only after an equivalent upstream implementation is read
and its path exercised.

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
- Swappable PTYs: `a26f4bf` on `feat/swappable-ptys` in
  `~/src/zmx-swappable-ptys`. Built 2026-09-04, gated, and **not yet on
  `integration`**: it is the next commit for the top of the stack, and smolmux's
  `src/zmx-protocol.ts` mirror of the `Exit` flags byte has to follow before
  the pin moves.
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
- Second defect in Restore, found by the same review and also not fixed here:
  `util.serializeTerminalState` clears `synchronized_output` on the live
  terminal and restores it only on the success path, so either of its two
  early returns leaves the mode cleared for the rest of the session. The
  handoff serializer does the same thing correctly with a `defer`, which is
  the one-line shape of the fix. It predates this work and sits in the Restore
  commit, not this one.
- Known defect in Restore, measured but not fixed: `serializeTerminalState`
  clears the visible screen between the scrollback and the active screen, so
  every restore drops exactly one screenful — and not the oldest part, but the
  screenful immediately above the viewport, which is the run a reader most
  wants. The smolmux redesign session measured it against a Companion at the
  current pin: 5 rows lost L192–L196 of 200, 10 rows lost L182–L186, 20 rows
  lost L162–L166. It compounds: a Session that has reattached several times
  has several holes, and smolmux's new `session.capture` scrollback bound reads
  the emulator that replay populates. The handoff path no longer has it —
  `util.serializeTerminalForHandoff` in `a26f4bf` round-trips losslessly and
  is unit-tested for it — and the same serializer is the candidate fix for
  restore. It was scoped to handoffs deliberately: the clear was upstream's
  fix for issue #31, restore is a carried feature smolmux depends on for every
  attach, and changing what every client receives is its own decision with its
  own gate. Both consumers clear the terminal before the restore bytes arrive
  smolmux does it twice over, prepending RIS to the first Restore bytes in its
  thin Client and writing RIS into each Session's emulator at `restoreBegin`,
  and zmx `attach` writes the clear itself. So the clear inside the snapshot
  buys either of them nothing and costs them the screenful; a consumer that
  clears neither way is the case to check before moving.
- One gate step fails on the delivered baseline `2ffb1c1` and on the
  swappable-PTYs commit alike, so it is machine drift rather than a fork
  regression, verified by building the baseline separately and running the
  same step against it: `test/companion.bats` "a companion build creates its
  directory private" fails on the mode of a directory it creates under the
  test's own tmp dir. The last cycle recorded bats 94/94, so this arrived with
  something on this machine, not with the fork.
- This branch was built before the consumer's rename and rebased onto it at
  `c86e296`; the fork-side names that deliberately stay `fmx` are recorded in
  this file's own section on that, and nothing here duplicates it.

## History

- 2026-09-04: Built Swappable PTYs as `a26f4bf` on `feat/swappable-ptys`
  after asking the smolmux redesign session whether the minimal consumer still
  needs a
  child's exact exit status; it does not, and is making `session.exited`'s
  code and signal nullable. Testing under load then found three losses at the
  seam, all in what the snapshot said rather than in the handoff itself: a
  screenful, from reusing the restore serializer, whose clear costs the screen
  that had scrolled into view; a single line, from a formatter saying nothing
  about the blank row a cursor sits on, which left the replay one scroll
  behind so the child's next line overwrote the last one it should have kept;
  and, for a session in the alternate screen, the whole screen, because
  content was emitted before the mode that decides which screen it lands on.
  All three are fixed by a handoff-specific serializer that also carries the
  primary screen a restore never sends, guarded by four round-trip unit tests
  and an end-to-end one. The gate then ran in full against the final commit
  `a26f4bf`: fmt, Debug build, Zig tests, bats 105/106 (the companion
  directory-mode failure above), a Companion ReleaseFast build of
  `0.7.0+fmx.a26f4bf2d440`, and the consumer suite in a clean worktree of
  smolmux `main` at `8868db9` — 229 pass, 3 skip, 0 fail, with the
  Companion-backed PTY end-to-end file 3/3. Not published, not pinned.
- 2026-09-04, adversarial review of the same commit by a subagent (Opus, high
  effort) on the handoff and teardown paths, which reproduced its findings
  against a build rather than reading alone. It confirmed the alternate-screen
  loss independently, and found two defects the work had not: a stalled
  importer froze the daemon for as long as the peer liked, because the
  accepted socket was put back into blocking mode and one `write` of a
  manifest exceeds a send buffer; and the chmod failure path in
  `bindHandoffSocket` closed a descriptor the errdefer also closed. Both are
  fixed with tests, along with a client message that had claimed a session it
  could not see was unchanged. Its remaining items were taken in full: a
  screen that failed to format was dropped from the snapshot instead of
  failing it, a manifest over the frame cap reached the far side as a
  malformed frame rather than as "too large", an empty argument did not
  survive a round trip, the serializer's doc comment had come adrift onto the
  helper below it, and the help text said dropped clients reconnect, which
  nothing does. The review's `--exit-on-last-client` finding was the one
  substantive item still open, and the ruling is that the policy crosses
  disarmed rather than armed at a client only the previous daemon saw; that
  leaves a migrated session in the state a created one is in before its first
  attach, which the policy already defines, and it is covered by a test.
  Two findings were accepted rather than fixed and are recorded above as what
  they are: `list --json` and `inspect --json` can now carry a null exit
  status, which is the intended contract change the consumer is following; and
  an adopted child's end is reported without a status, which is inherent to a
  session outliving the process that forked it and is named in the fork notes.
  The review then separated a ruling that had been made against the wrong
  thing: reporting an imprecise status is cosmetic and stays inside the
  session, but signalling a process group on a pid nothing pins leaves it and
  can reach a stranger. Teardown now asks whether the adopted child is still
  there before it signals rather than after, so the guard written for that
  case can fire; `kill` on a migrated session still reaps its child, which a
  test holds. One foot-gun is left as it is: the
  manifest version is an equality check, so the first bump makes running
  sessions unmigratable to the build that bumped it. It fails safely and
  loudly, and a compatibility window is a decision, not an oversight.

- 2026-08-23: Seeded the workshop from the end of tranche 6 and reconciled
  the fork's branch namespace for the first time. No maintenance cycle has
  run. Later that day: the first Linux Companion build (smolmux's 0.2.0 release
  run) exposed the @cImport stat; fixed on `integration` and the pin moved
  through `pin-companion.sh` — its first real use.
- 2026-08-23: Added multi-client terminal sizing and opt-in final-client
  lifecycle as `0081b6e`, gated the 24-commit stack, published `integration`,
  and transactionally moved smolmux to build `0.7.0+fmx.0081b6ea9795` (346 tests,
  12/12 PTY).
- 2026-08-23: Made passive mouse motion and focus gain take sizing ownership
  as `bea6677`, gated and published the 25-commit stack, moved smolmux to
  `0.7.0+fmx.bea6677b7762` (361 tests, 12/12 PTY), and made a failed pin gate
  restore `companion.json` byte for byte.
- 2026-08-25: Removed automatic branch deletion inference and atomically
  restored the three fork-local upstream `push-*` copies from their accidental
  `DELETEME/*` names without changing their tips.
- 2026-08-29: Advanced the mirror to `fb1b6b6`, repaired and adversarially
  reviewed the rebased stack, gated and published `2ffb1c1` under the original
  lease, moved smolmux to its matching build in `89a4041`, and reconciled the
  namespace while preserving all three `push-*` heads. Updated the workshop
  entrypoint to the installed shared-skill namespace.
- 2026-08-29 retrospective: Reconstructed the prior audited frontier at
  `ea45749278bac648ab13a4280a6035012854d717` and audited the aggregate
  `ea45749278bac648ab13a4280a6035012854d717..fb1b6b66476fc83c1453b0cde8fe2a50166eb395`
  (2 commits): v0.7.1 release documentation/synchronous release jobs and the
  stale stock `list --where` cleanup, with no new runtime capability.
  Dispositions were retire 0, repair 1 (Discovery and records, already repaired
  in `241efd3`), unchanged 7; the frontier advanced to `fb1b6b6` without a
  product republish or gate.

## The consumer is called smolmux; two fork names deliberately are not

The consumer this fork serves was renamed from fmx to smolmux, and this
repository now says smolmux everywhere it means that program. Two names inside
the fork itself did not move, and neither is an oversight.

`-Dversion=<zon version>+fmx.<12 hex>` stays. `build.zig` refuses a version
naming fmx unless `-Dcompanion` was passed, and that refusal is what stops a
stock build passing the consumer's pin and then keeping a human's by-hand
sessions in the stock directory. Renaming the marker without moving the guard
would silently disarm it.

The `-Dcompanion` directory default stays `/tmp/fmx-<uid>/zmx`. MAINTAIN.md
names it as a carried feature, so changing it is an inventory change with a
gate rather than a rename.

Both belong in a stack commit with the gate that goes with them. Until then
smolmux keeps its own sockets in `/tmp/smolmux-<uid>` and passes `ZMX_DIR` on
every Companion command, so nothing is broken; the only cost is that a by-hand
`smolmux-zmx list` needs the directory named, which `smolmux doctor` prints.
