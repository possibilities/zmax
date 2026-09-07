# Notes on the fork's internals

What the sessions that built the fork (tranches 1–6, 2026-08-22/23) learned
about zmx the hard way, kept here because no code comment says it and the
next rebase will meet it again. The protocol itself is documented by its
golden tests (`src/ipc.zig` in the fork, `src/zmx-protocol.ts` in smolmux);
this is the surrounding knowledge.

## zmx internals

Things that cost time to discover and are not obvious from the code.

- **A closed pty master stays readable.** Once the slave side is gone the EOF
  branch runs on *every* poll iteration, forever. Anything armed there must be
  armed once, behind a null check — this is what made a re-armed deadline spin
  the daemon at full tilt.
- **Buffering a frame does not send it.** `poll_fds` asks for `POLLOUT` at the
  top of an iteration from `has_pending_output` as it was *then*. A frame
  queued later in the same iteration needs another one, which is why the drain
  window exists. `Exit` was silently lost until that was understood.
- **Never block the daemon on `waitpid`.** It is single-threaded and holds the
  session socket; a wait that does not return wedges the session and every
  client. Use `WNOHANG` and retry.
- **Sizing ownership needs per-client memory.** Asking a newly active client
  for its size is too late for the input that made it active. Keep each
  terminal's last Resize beside its client record, apply it to the PTY and
  shadow terminal before queueing that client's first user-input bytes, and
  order activity so an owner disconnect can restore the latest survivor.
- **Mouse motion is sizing interaction.** OpenTUI enables all-motion mouse
  tracking, so a passive move arrives as SGR mouse input and should claim the
  Client just like a key. Recognize the raw `CSI < ... M/m` form before the VT
  parser loses its private marker; basic mouse input dispatches as `CSI M`.
  Focus gain claims too, focus loss does not — but focus loss must keep parsing
  because a key may follow it in the same payload.
- **A socket client is not necessarily a terminal.** Discovery and other
  one-shot requests connect to a session too. Final-client lifecycle therefore
  arms only on a valid Init and counts only clients that actually attached a
  terminal; otherwise a create probe can kill a session before its first
  terminal arrives or keep it alive after the last terminal leaves.
- **EOF does not prove the child is dead**, only that every slave fd closed.
  In practice it is very hard to separate the two: the session leader keeps the
  controlling terminal, so a child closing its stdio does *not* produce EOF.
- **Descriptor ownership can cross; parenthood cannot.** A handoff sends the
  PTY master and listening socket over `SCM_RIGHTS`. The importer must never
  `waitpid` the child it adopted: the wrapper treats `ECHILD` as unreachable.
  After PTY EOF, PID probes supply liveness but cannot pin the number against
  reuse. Exit flags and records report unknown status honestly.
- **The terminal is not its parser.** A partial UTF-8 character or escape
  sequence belongs to `vt_stream`, not the shadow terminal. Handoff refuses
  until the parser is ground and its UTF-8 decoder has no pending bytes.
  CUP also clears pending wrap, so that flag crosses separately for each
  screen; the final cursor is restored after margins and tabstops.
- **Import must validate the source directory.** A stock target and Companion
  can default to different directories even when they speak the same manifest.
  Compare the complete session socket path before taking ownership, or teardown
  could unlink an unrelated same-name session in the target directory.
- **Discovery treats files in the socket directory as sessions.** The private
  handoff socket therefore lives under logs, named `h-<daemon pid>.sock` to fit
  macOS's socket-path limit. Both daemons briefly share the session log with
  independent offsets; the seam can interleave a log entry.
- **`handleKill` signals the process group** (`kill(-pid, …)`), which is what
  reaps whatever the child backgrounded. Skipping it because the child was
  already reaped leaks those processes.
- **`zmx attach <name> <cmd…>` takes no `--`.** A `--` is passed to `execvpe`
  as the program name and fails with `FileNotFound`.
- **`zmx list` writes rows to stdout with a two-space indent** and "no sessions
  found in <dir>" to stderr, and reports the **child's** pid, not the daemon's.
  Trim before parsing. Tranche 3 added `--json` for programs; the text form is
  unchanged.
- **`std.Io.File.writer` is positional.** It `pwrite()`s from an offset it
  tracks from zero, so with stdout redirected to a file every command started
  over at the top. `writerStreaming` is what a CLI means by stdout. Upstream
  has this bug everywhere; fixed here in `ae68e80`.
- **ghostty-vt prunes scrollback by bytes as well as lines.**
  `max_scrollback_bytes` defaults to 10 KB, and zmx never set it, so the
  2,000-line default really kept about 500 lines. It is `null` now and lines
  govern. Costs, measured on 87-column plain text: 2,000 lines is about
  175 KB of VT, 50,000 lines about 4.5 MB. Pruning is page-granular, so a
  limit is honoured only to within a page (2,500 asked, 2,208 kept).
- **`bats` is the CLI's test harness** (`brew install bats-core`), and it
  needs GNU `timeout` on PATH (`brew install coreutils`; a `timeout` symlink
  to `gtimeout` in `~/.local/bin` is how this machine has it).
- **A daemon lingers after its child**: SIGHUP, a 500 ms grace, SIGKILL, the
  reap, the exit record, and only then the socket file. `kill` returns when
  the daemon accepts it, not when that is done, so "it is gone" must be
  polled. During the window the session reads as `refused`, never absent.
- **A session can end before its creating client attaches.** `zmx attach x sh
  -c 'echo hi; exit 7'` usually exits 1 with "session not ready" — the child is
  gone before the connect. Not a bug in this work; it bites when writing tests.
- **`getTerminalSize` logs a stack trace under pipes** (`open("/dev/tty")` →
  ENXIO) on the daemonize path. Pre-existing upstream, harmless, noisy — a
  small upstream fix would be to fall back silently with no controlling tty.
- Zig 0.16: there is no `std.time.milliTimestamp`. Monotonic time is
  `std.Io.Timestamp.now(io, .boot)`; `.real` is the wall clock. Both need an
  `io`, which is why `clientLoop` now takes one.


## What the wire looks like now

Measured on aarch64 and x86_64 in Debug/ReleaseSafe/ReleaseFast before
anything changed, and now pinned by tests on both sides:

- `Header` (8 bytes): tag `u8`, len `u32` LE, 3 reserved bytes — written zero,
  ignored on read. Unchanged from what `packed struct{u8,u32}` emitted.
- `Resize` (8 bytes): rows, cols, xpixel, ypixel, each `u16` LE.
- `Hello` (8 + name): min_version `u16`, max_version `u16`, capabilities
  `u32`, then the client name (≤ 64 bytes).
- `Welcome` (10 bytes): version `u16` (0 = refused), min_version `u16`,
  max_version `u16`, capabilities `u32`.
- `max_payload_len` is 16 MiB; a header announcing more fails the reader
  before the payload is accumulated. Restore snapshots have not been measured
  against it yet — do that when scrollback becomes configurable (tranche 3).

Protocol v1 = the envelope above plus `Hello`/`Welcome` and the attached-client
lifecycle. Negotiation is opt-in per connection: a client that never sends
`Hello` keeps pre-negotiation behavior, which is what every one-shot CLI client
does, so nothing upstream had to change with it.

## Things learned while building the protocol client

- `zmx attach <name> <cmd...>` takes the command with **no** `--` separator; a
  `--` is passed to `execvpe` as the program name and fails with `FileNotFound`.
- `attach` under pipes (no TTY) works, but `getTerminalSize` logs an
  `unexpected errno: 6` stack trace from `open("/dev/tty")` on the daemonize
  path. Pre-existing on upstream `main`, harmless, noisy. Worth a small
  upstream fix (fall back silently when there is no controlling terminal).
- `zmx list` writes session rows to **stdout** with a two-space indent, and
  "no sessions found in <dir>" to **stderr**. `--short` prints bare names.
  Do not parse it without trimming; tranche 3 replaces this with `--json`.
- `list` reports the **child's** pid, not the daemon's. After the child exits
  the daemon still runs briefly (`handleKill` sleeps 500 ms between SIGHUP and
  SIGKILL, then `waitpid`), so "the child is gone" must be polled, not
  asserted one tick after the socket closes.
- The daemon only serializes a restore when `has_pty_output and
  has_had_client`; a first-ever attach gets none. That is why held pre-ready
  output is flushed at Init when no restore was sent — without it a first
  attach loses everything the child printed before it connected.
- Bun's `socket.write()` can return fewer bytes than given; the `Transport`
  queue in `src/zmx-client.ts` handles that and waits for `drain`.
- `Bun.connect`'s `open` handler must not return a value (its type is `void`).
- smolmux's tsconfig `include` did not cover `scripts/`; it does now.


## Adversarial boundary review (2026-09-04)

Malformed or oversized requests now fail their peer rather than the daemon
loop. This boundary includes Init/Resize cell budgets, History format bytes,
Write path lengths, literal destination quoting, output queue capacity, and
PTY input capacity. Run and Write roll back their queued bytes when they
cannot queue their acknowledgement; a caller whose connection closes still
cannot infer whether already-flushed commands ran.

Restore is an attach transaction: no Ready after a serialization failure,
no sizing or terminal membership before the complete queue succeeds, and no
arming `--exit-on-last-client` on a failed first Restore. Serialization errors
must restore transient terminal modes through `defer`. Optional-return
helpers need ordinary `defer` cleanup, because returning null does not invoke
`errdefer`.

The consumer uses `scripts/build-companion.sh` for its provisional pin, then
runs `tests/instance.e2e.test.ts`. The former multiplexer test path no longer
exists. Failure restores only the pin bytes written by the transaction;
concurrent edits remain available for review. This review adds safeguards to
the existing protocol version 1 and does not audit newer upstream commits.

## Handoff continuation (2026-09-07)

The original `a26f4bf` was based on `2ffb1c1`, before `2be662d` bounded client
queues and made Restore transactional. Its loop now takes a terminal pointer,
so the port retains per-peer error handling and validates dimensions in the
shared terminal constructor. Handoff uses the newer fallible color/cwd helpers
and refuses manifest construction on snapshot or label failure. Migration
acknowledgements use the same queue budget as other replies.

The old review's synchronized-output cleanup finding is already fixed by
`2be662d`; retain its `defer`. Restore's separate screenful loss remains visible
in smolmux's `app.capture` after reattach and is covered by the consumer's bound
test. Handoff serializes continuous history and both screens without that clear.
Do not treat the historical 105/106 Bats result as current gate evidence.
