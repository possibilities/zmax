# zmx fork maintenance

This repository delivers and maintains our fork of
[`neurosnap/zmx`](https://github.com/neurosnap/zmx): the Companion that fmx
bundles as `fmx-zmx`, which owns each agent's process and terminal so both
survive fmx closing. It owns the behavior fmx needs independently of upstream
review or publication while continuously rebuilding that behavior on current
upstream zmx. `/maintain` — the shared `maintain` skill — runs a maintenance
cycle from this file; this file is the whole of what that skill knows about
zmx.

## Purpose

Keep a published `integration` branch of zmx that carries every feature below,
rebuilt on current upstream every cycle, and consumed by fmx through its
Companion pin. The fork is narrow and purpose-specific: zmx stays a session
daemon with a shadow terminal, fmx stays the renderer and organizer, and
anything about agent status, heartbeats, or fx itself is fmx's problem, never
the fork's. Nothing here installs a `zmx` on the system path, and the fork
never shadows or depends on a zmx a human may have installed.

## Upstream

- Bound checkout: `~/src/zmx`. `origin` is `neurosnap/zmx`; `fork` is
  `possibilities/zmx`. zmx has no `AGENTS.md`; fmx's (`~/code/fmx/AGENTS.md`
  and `CONTEXT.md`) name the Companion's contract and the language —
  **Companion**, **Home**, **Companion pin**, **Restore** — and are read before
  touching the fork.
- Contribution conventions: low volume, strongly single-maintainer,
  scope-conscious. No `CONTRIBUTING.md`, issue-first rule, pull-request
  template, hosted CI, CLA, or DCO; CI is the maintainer's own pico.sh run on
  branch pushes to *their* repository. Direct pull requests are normal and
  small ones land quickly. The maintainer often refines or cherry-picks
  outside work onto `main`, preserving authorship, and closes the request
  without GitHub marking it merged; larger features start with issue alignment
  and land in narrow planks. The libzmx conversation is
  [#127](https://github.com/neurosnap/zmx/issues/127); our position there is
  that fmx needs the standalone daemon's socket boundary, and that the fork is
  not an attempt to pull zmx away from its goals.
- What we offer: narrow planks, one at a time, each shaped as upstream would
  write it and carrying no fmx concept — a fix to a real upstream defect, or a
  seam upstream could want on its own terms. The Companion protocol
  (`Hello`/`Welcome`, the restore boundary, `create`, discovery, records, the
  `-Dcompanion` build) is never offered; it is the fork's reason to exist. An
  offer is a `fix/<name>` or `feat/<name>` branch cut from current
  `origin/main`, written fresh rather than lifted from the stack, adversarially
  reviewed by subagents before it is pushed, pushed to the fork when its pull
  request opens, and tended by `watch-requests`. Independent planks may be
  open together; a plank that builds on another waits for it. Every message
  to upstream is approved by the human except code answering a review when
  the change is clear, and the recap once those commits are pushed. The
  planks, each verified against upstream `ea45749` built ReleaseFast:
  - `fix/first-attach-output` — output a command prints before its creator's
    first attach connects is lost (the creator connects ~10 ms after forking;
    a release build's child prints inside that): replay the terminal on a
    first attach too, whenever it already holds output. Stack commit
    `14e6b2e`/`4e29345` carry the fork's fuller answer.
  - `fix/attach-exit-status` — `zmx attach <name> <cmd>` exits 0 whatever
    cmd did, because the daemon's only `waitpid` is a blind one at teardown:
    reap at pty EOF, report the status to clients as `TaskComplete`, hold a
    daemon whose child ended before anyone connected for up to 2 s, flush
    before closing, exit attach with the status. Stack commits `4e29345`,
    `23e5519`, `e81ef16` carry the fork's version.
  - `fix/daemon-dev-tty` (not yet cut) — the daemon's `getTerminalSize` opens
    `/dev/tty` after `setsid()`, which fails with ENXIO and prints an
    "unexpected errno: 6" trace in Debug builds on every session start; map
    it to no device. The fork's `14e6b2e` does this.
- "Landed" means the behavior is on `neurosnap/zmx:main`, decided by reading
  that code and exercising its path — never by the request's state, since the
  maintainer lands work by rewriting it and closing. When an offer has landed,
  the matching stack commit is dropped at the next rebase and the inventory
  entry notes the upstream commit.

## Branch model

- Mirror branch: `main`, an exact mirror of `neurosnap/zmx:main` locally and on
  the fork. Never an integration base with downstream-only commits.
- Integration branch: `integration`, every carried feature together. It is the
  only ref fmx's pin may name and never a development branch of its own:
  work lands on it through a rebased candidate.
- Composition: linear stack. `integration` is one linear series of commits
  above `origin/main`, rebased as a whole onto current upstream in a scratch
  worktree every cycle, with each commit's subject the marker the inventory
  below refers to. There are no carry branches. A feature is repaired by
  editing its commit in place during the rebase; a new feature is a new commit
  at the top of the stack; a landed one is dropped.
- Quarantine prefix: `DELETEME/`. Any fork head other than `main`,
  `integration`, or a preserved open-request head — including an offer
  branch whose request has closed, and the `push-*` heads mirrored from
  upstream's CI when the fork was made — is moved at the same commit to
  `DELETEME/<original-name>`. Existing `DELETEME/*` heads are permanent:
  reported, never removed automatically.
- Open pull-request heads: preserved. The exact head of a currently open
  request from the fork keeps its name only while the request is open, which
  is why an offer is pushed when its request opens and not before.
- Rerere: not relied on. The stack is small and rebases are meant to be
  read: a recorded resolution would hide exactly the protocol drift a cycle
  exists to notice.
- `scripts/reconcile-branches.sh` is this repository's entrypoint to the
  shared namespace script; it declares these values and nothing else. The
  fork has no hosted CI, so quarantine creates trigger nothing.

## Features

Every feature is a commit or a few adjacent commits in the stack; the
scratchpad records which. Absence is work.

### Portable wire

- The wire is an explicit little-endian codec with a frame cap; `Header` and
  `Resize` bytes, every control payload, and the refusal bytes are frozen by
  golden tests that fmx's `src/zmx-protocol.ts` mirrors. Control payloads are
  fixed-width binary; JSON is for CLI output only.

### Negotiated clients

- A connecting client sends `Hello` and receives `Welcome` or a refusal naming
  both sides' protocol ranges; a client has a phase
  (`connected → negotiated → restoring → ready → exited/closed`) and a refused
  client's bytes act on nothing. An oversized frame, a late `Hello`, and a
  silent handshake are survived.

### Restore and exit

- Every attach begins with `RestoreBegin`, the whole terminal as it stands,
  and `Ready`; live bytes reach only ready clients. A reconnect replays onto a
  clean screen the same way.
- The child's exit is exact: `waitpid` is captured, final PTY bytes drain
  before `Exit`, the record carries code, signal, and reason, a session winds
  down once, and `zmx attach <cmd>` exits with the child's status.
- `daemonize()` returns on an acknowledged exec rather than a sleep, so a
  first attach in a release build never loses the child's opening output;
  stdio is written as streams.

### Create

- `zmx create [--labels kv] [--json] <name> -- <argv>` is create-only:
  `AlreadyExists` rather than attaching to an old session, direct argv exec,
  readiness through a close-on-exec pipe and a startup pipe across the
  double-fork, a bounded wait with a structured error, labels applied at
  creation, and no socket or session left behind after a failure. A created
  child execs with its creator's environment — no `ZMX_*` leaks to it.

### Discovery and records

- `list --json`, `inspect --json`, and `--where` report without sweeping:
  live, refused, and absent are distinguished, labels filter, and enumeration
  never deletes the evidence it reports. A created session leaves an exit
  record (kept even when its socket was swept by another Home); `forget`
  removes one.

### Scrollback

- `--scrollback-lines` and `ZMX_SCROLLBACK_LINES` govern what the shadow
  terminal keeps and a restore replays; history is transferred in chunks, and
  an incomplete transfer fails instead of printing a fragment.

### Companion build

- `zig build -Dcompanion` keeps fmx's directory by default —
  `/tmp/fmx-<uid>/zmx`, logs under it, created 0700/0600 and refused unless
  private and the caller's own — so `fmx-zmx` by hand needs no `ZMX_DIR` and
  never touches a stock zmx's directory. `-Dversion=<zon version>+fmx.<12 hex>`
  is what the Companion reports; a `+fmx.` version without `-Dcompanion`
  refuses to build. `version` and `help` say what a Companion build's
  defaults are.

### Scope

- Keep changes mechanically close to upstream where that is cheap: later
  rebases and offers both depend on it. No ghostty-free daemon path, no
  embedder loop, no in-process Zig consumer — fmx talks over the socket.

## Gate

From the candidate worktree, with Zig 0.16.x and bats installed:

```sh
zig fmt --check src/ build.zig
zig build
zig build test
bats test/
companion_build="$(grep -m 1 -E '^[[:space:]]*\.version = "' build.zig.zon | sed 's/.*"\([^"]*\)".*/\1/')+fmx.$(git rev-parse --short=12 HEAD)"
zig build -Dcompanion -Doptimize=ReleaseFast -Dversion="$companion_build" --prefix "$(mktemp -d)/companion"
```

Also run the fmx suite against that Companion build before publishing, from
a clean `~/code/fmx` on `main`:

```sh
FMX_ZMX_PATH="<prefix>/bin/zmx" bun test
FMX_ZMX_PATH="<prefix>/bin/zmx" FMX_RUN_PTY_TESTS=1 bun test tests/multiplexer.e2e.test.ts
```

No external proof is required: the fork has no hosted CI. `test/create.bats`
"history: a transfer that ends early" is timing-sensitive on this machine; a
failure there alone is rerun, not waved through.

## Consumer

fmx's Companion pin. After the leased push of `integration`, run:

```sh
~/code/zmax/scripts/pin-companion.sh --apply
```

It reads the published `integration` commit from the bound checkout (which
must equal `fork/integration`), derives the build string from the fork's
`build.zig.zon`, pulls fmx `main` (another session commits there), builds the
Companion ReleaseFast from a detached worktree at that commit, writes
`~/code/fmx/companion.json`, runs fmx's suite and e2e against the build,
commits the pin on fmx `main`, pushes, and then refreshes this machine's
editable fmx's Companion (`~/.local/bin/fmx-zmx`, through fmx's
`scripts/install-companion.sh`) — or reverts the file and reports which gate
failed. It says when the fork's `build.zig.zon` changed since the
previous pin, because fmx's `THIRD_PARTY_NOTICES.md` Companion section is kept
by hand against it. Cutting an fmx release is a separate, deliberate act.

## Notify

- Title: `zmx Maintenance`
- Group: `zmax.maintain`
