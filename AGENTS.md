# zmax agent guidance

This repository owns delivery and maintenance of the operator's zmx fork —
the Companion fmx bundles as `fmx-zmx`. Read `CONTEXT.md`, `MAINTAIN.md`, and
`SCRATCHPAD.md` before changing the fork or its pin.

## Ownership

- `MAINTAIN.md` is the project specification and the whole of what the shared
  `maintain` skill knows about zmx: purpose, upstream and our stance toward
  it, the branch model, the feature inventory that must remain true, the
  gate, the consumer, and the notification. Its section headings are fixed —
  the skill reads them by name — so add to a section rather than renaming one.
- `/maintain` is the shared `maintain` skill in `~/code/agentguidance`, the
  operating procedure for every fork workshop on this machine. zmx-specific
  procedure belongs in `MAINTAIN.md`, never in a copy of the skill here.
- Every behavior the fork carries is reversed into `MAINTAIN.md` § Features by
  the same change that builds it, in the same commit. The entry is part of the
  work, never a follow-up: a carried feature the inventory does not name is
  unfinished, because the next cycle reconciles only what that section states.
- `SCRATCHPAD.md` is current maintenance state, not a second specification or
  an unbounded transcript.
- `scripts/reconcile-branches.sh` is the thin entrypoint to the skill's shared
  namespace script: it declares the branch model `MAINTAIN.md` states — a
  linear stack, no carry heads, open-request heads validated, and explicit
  `DELETEME/` markers — and nothing else. Reconciliation leaves all undeclared
  refs unchanged; the mechanics live and are tested in agentguidance.
- `scripts/pin-companion.sh` is the consumer step: it moves fmx's Companion
  pin (`~/code/fmx/companion.json`) to the published `integration` commit
  after building that commit and running fmx's suite against it. It never
  rebases, publishes, or cuts an fmx release.

The checkout being maintained is `~/src/zmx`, with `fork` pointing to
`possibilities/zmx` and `origin` pointing to `neurosnap/zmx`. Its
`integration` branch is the only ref fmx's pin may name. zmx has no agent
guidance of its own; fmx's `AGENTS.md` and `CONTEXT.md` carry the Companion's
contract and language, and `docs/fork-notes.md` keeps what building the fork
taught about zmx's internals and wire — read it before a rebase touches
`loop.zig`, `daemonize.zig`, or `ipc.zig`.

## Working topology

Work directly on `main` in this repository. Outside this repository, create a
dedicated worktree, commit the finished change, merge it into the target's
`main` or integration branch as appropriate, and remove the worktree after the
merge. Never do feature work in the bound zmx checkout, never force-update
`integration` in place, and never push an offer onto a branch a pull request
is open on.

The stack is linear: a feature is a commit, repaired in place during the
cycle's rebase, never a branch of its own. An offer to upstream is written
fresh on `fix/<name>` from current `origin/main`, shaped as upstream would
write it, and is not a stack commit moved across — the stack and the offer
serve different audiences.

Maintenance owns only Main and Integration. Creating, moving, or removing a
`DELETEME/<original>` ref requires an explicit human decision naming that
branch; age, ownership, request state, and namespace are never deletion intent.

## Validation

Run:

```sh
tests/validate.sh
```

Fork work follows `MAINTAIN.md`'s gate in full — fmt, build, unit tests, bats,
a Companion release build, and fmx's suite against it. Moving the pin is
`scripts/pin-companion.sh`, never a hand edit of `companion.json`.

Finished work lands on `main` and is pushed.
