# zmx fork maintenance

This repository delivers and maintains our fork of
[`neurosnap/zmx`](https://github.com/neurosnap/zmx): the Companion that smolmux
bundles as `smolmux-zmx`, which owns each agent's process and terminal so both
survive smolmux closing. It owns the behavior smolmux needs independently of upstream
review or publication while continuously rebuilding that behavior on current
upstream zmx. `/maintain` — the shared `maintain` skill — runs a maintenance
cycle from this file; this file is the whole of what that skill knows about
zmx.

## Purpose

Keep a published `integration` branch of zmx that carries every feature below,
rebuilt on current upstream every cycle, and consumed by smolmux through its
Companion pin. The fork is narrow and purpose-specific: zmx stays a session
daemon with a shadow terminal, smolmux stays the renderer and organizer, and
anything about agent status, heartbeats, or fx itself is smolmux's problem, never
the fork's. Nothing here installs a `zmx` on the system path, and the fork
never shadows or depends on a zmx a human may have installed.

## Upstream

- Bound checkout: `~/src/zmx`. `origin` is `neurosnap/zmx`; `fork` is
  `possibilities/zmx`. zmx has no `AGENTS.md`; smolmux's (`~/code/smolmux/AGENTS.md`
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
  that smolmux needs the standalone daemon's socket boundary, and that the fork is
  not an attempt to pull zmx away from its goals.
- What we offer: narrow planks, one at a time, each shaped as upstream would
  write it and carrying no smolmux concept — a fix to a real upstream defect, or a
  seam upstream could want on its own terms. The Companion protocol
  (`Hello`/`Welcome`, the restore boundary, `create`, discovery, records, the
  `-Dcompanion` build) is never offered; it is the fork's reason to exist. An
  offer is a `fix/<name>` or `feat/<name>` branch cut from current
  `origin/main`, written fresh rather than lifted from the stack, adversarially
  reviewed by subagents before it is pushed, pushed to the fork when its pull
  request opens, and tended by `watch-requests`. Independent planks may be
  open together; a plank that builds on another waits for it. Every message
  to upstream is approved by the human except code answering a review when
  the change is clear, and the recap once those commits are pushed. A
  defect we have already fixed in the stack and do not depend on upstream
  for is reported as an **issue** with a proof-of-concept commit, not a pull
  request: the commit lives on the fork under a `poc/<name>` tag — tags are
  outside the branch model, so reconciliation never moves them — and the
  issue says we would turn it into a PR if the maintainer wants one. The
  planks, each verified against upstream `ea45749` built ReleaseFast:
  - `poc/first-attach-output` — output a command prints before its creator's
    first attach connects is lost (the creator connects ~10 ms after forking;
    a release build's child prints inside that): replay the terminal on a
    first attach too, whenever it already holds output. Filed as
    [neurosnap/zmx#246](https://github.com/neurosnap/zmx/issues/246). Stack
    commits `14e6b2e`/`4e29345` carry the fork's fuller answer; the pinned
    Companion is not affected.
  - `poc/attach-exit-status` — `zmx attach <name> <cmd>` exits 0 whatever
    cmd did, because the daemon's only `waitpid` is a blind one at teardown:
    read the status with `waitid(WNOWAIT)` at pty EOF, send it as its own
    `Exit` message, hold a daemon whose child ended before anyone connected,
    flush before closing, exit attach with the status. Filed as
    [neurosnap/zmx#247](https://github.com/neurosnap/zmx/issues/247). Stack
    commits `4e29345`, `23e5519`, `e81ef16`, `bbb26d4` carry the fork's
    version; smolmux reads exit records, never `attach`.
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
  only ref smolmux's pin may name and never a development branch of its own:
  work lands on it through a rebased candidate.
- Composition: linear stack. `integration` is one linear series of commits
  above `origin/main`, rebased as a whole onto current upstream in a scratch
  worktree every cycle, with each commit's subject the marker the inventory
  below refers to. There are no carry branches. A feature is repaired by
  editing its commit in place during the rebase; a new feature is a new commit
  at the top of the stack; a landed one is dropped.
- Deletion marker prefix: `DELETEME/`. Creating, moving, or removing
  `DELETEME/<original-name>` requires an explicit human decision naming that
  branch. Maintenance never infers deletion from branch age, ownership,
  request state, namespace, or absence from the stack. Every undeclared fork
  head remains unchanged.
- Open pull-request heads: validated. Reconciliation confirms the exact head
  of each currently open request from the fork but does not acquire ownership
  of the ref. Closing a request does not authorize renaming or deleting its
  branch, which is why an offer is pushed when its request opens and not before.
- Rerere: not relied on. The stack is small and rebases are meant to be
  read: a recorded resolution would hide exactly the protocol drift a cycle
  exists to notice.
- `scripts/reconcile-branches.sh` is this repository's entrypoint to the
  shared branch script; it declares these values and nothing else.
- Supervision: `scripts/reconcile-branches.sh --configure-supervision`
  converges this model into the bound checkout's own `supervisor.*` git
  config, which is where advisory tools read it — `/tend` judges a worktree
  against the integration branch and never proposes removing a carry head's
  worktree. It is derived state, not a second declaration:
  `--check-supervision` verifies it, and that this section still names these
  branches.

## Features

Every feature is a commit or a few adjacent commits in the stack; the
scratchpad records which. Absence is work. Work that adds a feature writes its
entry in the same change; an unrecorded feature is unfinished work, because a
later cycle reconciles only what this section names.

### Portable wire

- The wire is an explicit little-endian codec with a frame cap; `Header` and
  `Resize` bytes, every control payload, and the refusal bytes are frozen by
  golden tests that smolmux's `src/zmx-protocol.ts` mirrors. Control payloads are
  fixed-width binary; JSON is for CLI output only.

### Negotiated clients

- A connecting client sends `Hello` and receives `Welcome` or a refusal naming
  both sides' protocol ranges; a client has a phase
  (`connected → negotiated → restoring → ready → exited/closed`) and a refused
  client's bytes act on nothing. An oversized frame, a late `Hello`, and a
  silent handshake are survived.

### Multi-client terminal ownership

- Every attached terminal remembers its dimensions. A completed attach, focus
  gain, keyboard input, mouse motion or buttons, paste, or resize makes that
  client the sizing owner; its stored dimensions reach both the PTY and shadow
  terminal before interactive bytes do. Focus loss and terminal replies do
  not claim ownership. When the owner disconnects, the most recently active
  attached terminal takes over immediately.
- `create --exit-on-last-client` is opt-in session lifecycle. It arms only
  after the first valid terminal Init, then ends the child when the last
  terminal disconnects; discovery, probes, and other one-shot clients neither
  arm the policy nor keep the opted-in session alive.

### Restore and exit

- Every attach begins with `RestoreBegin`, the terminal as it stands, and
  `Ready`; live bytes reach only ready clients. A reconnect replays onto a
  clean screen the same way. What a restore sends is the scrollback, a clear,
  and then the visible screen — and the clear costs the one screenful that had
  scrolled into view, which the scratchpad records as a measured defect with
  its candidate fix. A handoff does not share it: see Swappable PTYs.
- The child's exit is exact wherever the daemon forked the child: `waitpid` is
  captured, final PTY bytes drain before `Exit`, the record carries code,
  signal, and reason, a session winds down once, and `zmx attach <cmd>` exits
  with the child's status. A daemon that adopted its child in a handoff
  cannot wait for it and says so instead of inventing a status; see
  Swappable PTYs.
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

### Swappable PTYs

- `zmx migrate <name> [--to <zmx>]` hands a running session to another zmx
  binary, defaulting to the one running the command, so a Companion upgrade
  replaces every daemon without restarting the agents under them. The pty
  master and the listening socket cross a private 0600 socket by `SCM_RIGHTS`
  with a manifest — session name and socket path, child pid, creation time,
  command, shell, labels, cwd, scrollback limit, task state, the final-client
  policy and whether it is armed, pty bytes not yet written to the child, and
  the shadow terminal serialized — so the child is never signalled and never
  learns that the process holding its terminal changed. The listening socket
  crossing too means a connect during the swap waits in the backlog rather
  than reading as refused.
- The exchange runs inline in the daemon's single-threaded loop and is
  strictly ordered: token, manifest, validation, descriptors, restored,
  committed. Everything before the commit may fail and leaves the source
  holding exactly what it held — the importer is killed and reaped, the
  session carries on, and the client is told why; the terminal is rebuilt and
  the snapshot replayed before the receiver reports restored. Nothing after
  the commit is allowed to fail, so the ownership acknowledgement is only
  logged. A source that hands its session on skips its whole teardown: it
  signals nothing, writes no exit record, and deletes no socket.
- The snapshot is its own serializer, not the one a restore sends. It emits a
  screen's scrollback and visible area as one continuous stream with no clear,
  replays the scrolls a formatter trims along with the blank row a cursor sits
  on, and positions the cursor last — so nothing the child writes next lands
  on a line it should have kept. Terminal state precedes any alternate-screen
  content, because which screen content lands on is itself a mode, and the
  primary screen crosses even while a full-screen program owns the display,
  which no restore carries. A handoff therefore loses no scrollback; a restore
  still loses a screenful, which Restore and exit names.
- Parenthood does not cross. An adopted child is observed by probing its pid
  after the pty reaches EOF, never by `waitpid`, and `Exit` carries a flags
  byte whose low bit means the status is unknown — placed so the zero every
  earlier daemon wrote there still reads as the status it had. An exit record
  then carries `null` for code and signal rather than a zero that would make a
  failure look like a success, `zmx attach <cmd>` says the status is unknown
  and exits 0, and an adopted child already seen to end is not signalled at
  all, because nothing pins its pid. Sessions can be handed on repeatedly.
- Known consequence, by choice: a session with `--exit-on-last-client` armed
  survives a migration with no clients attached, because its clients were
  dropped by the swap rather than by leaving, and it ends when the next
  attached terminal disconnects.

### Companion build

- `zig build -Dcompanion` keeps a directory of its own by default —
  `/tmp/fmx-<uid>/zmx`, logs under it, created 0700/0600 and refused unless
  private and the caller's own — and never touches a stock zmx's directory.
  `-Dversion=<zon version>+fmx.<12 hex>` is what the Companion reports; a
  `+fmx.` version without `-Dcompanion` refuses to build.
- **Both of those still say fmx, and that is deliberate.** The consumer was
  renamed to smolmux; the fork was not, because each name is load-bearing
  here. `build.zig` refuses a version naming fmx unless `-Dcompanion` was
  passed, which is what stops a stock build passing the consumer's pin and
  then keeping a human's own sessions in the wrong directory — renaming the
  marker without moving the guard would silently disarm it. The directory
  default is a carried feature this section names, so changing it is an
  inventory change with a gate. Both belong in a stack commit of their own,
  not in a consumer's rename, and until then smolmux keeps its own files in
  `/tmp/smolmux-<uid>` and passes `ZMX_DIR` on every command; `smolmux doctor`
  prints the by-hand command with the directory named. `version` and `help` say what a Companion build's
  defaults are.

### Scope

- Keep changes mechanically close to upstream where that is cheap: later
  rebases and offers both depend on it. No ghostty-free daemon path, no
  embedder loop, no in-process Zig consumer — smolmux talks over the socket.
- The protocol version in `src/ipc.zig` does not move on its own: smolmux's
  `src/zmx-protocol.ts` mirrors its constants and golden bytes, and a bump
  strands every agent a previous Companion is still holding. A frame that
  claims a reserved byte without moving the version — the `Exit` flags byte —
  is mirrored on the same terms: smolmux reads the bytes it always read, so
  the mirror follows before the pin moves rather than in the same breath.
  smolmux's
  `AGENTS.md` says what must exist first (a drain or a carry for
  survivors); a stack change that needs a new version waits for that, and
  the two move together in one pin.

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

Also run the smolmux suite against that Companion build before publishing, from
a clean `~/code/smolmux` on `main`:

```sh
SMOLMUX_ZMX_PATH="<prefix>/bin/zmx" bun test
SMOLMUX_ZMX_PATH="<prefix>/bin/zmx" SMOLMUX_RUN_PTY_TESTS=1 bun test tests/multiplexer.e2e.test.ts
```

No external proof is required: the fork has no hosted CI. `test/create.bats`
"history: a transfer that ends early" is timing-sensitive on this machine; a
failure there alone is rerun, not waved through.

## Consumer

smolmux's Companion pin. After the leased push of `integration`, run:

```sh
~/code/zmax/scripts/pin-companion.sh --apply
```

It reads the published `integration` commit from the bound checkout (which
must equal `fork/integration`), derives the build string from the fork's
`build.zig.zon`, pulls smolmux `main` (another session commits there), builds the
Companion ReleaseFast from a detached worktree at that commit, writes
`~/code/smolmux/companion.json`, runs smolmux's suite and e2e against the build,
commits the pin on smolmux `main`, pushes, and then refreshes this machine's
editable smolmux's Companion (`~/.local/bin/smolmux-zmx`, through smolmux's
`scripts/install-companion.sh`) — or reverts the file and reports which gate
failed. It says when the fork's `build.zig.zon` changed since the
previous pin, because smolmux's `THIRD_PARTY_NOTICES.md` Companion section is kept
by hand against it. Cutting an smolmux release is a separate, deliberate act.

## Notify

- Title: `zmx Maintenance`
- Group: `zmax.maintain`
