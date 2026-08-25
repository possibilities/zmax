# zmax context

**Workshop** — This repository, which owns the specification (`MAINTAIN.md`),
maintenance state, and consumer hand-over for the zmx fork; the maintenance
procedure itself is the shared `maintain` skill, which every workshop runs.
_Avoid_: wrapper, patch repo.

**Integration branch** — `possibilities/zmx:integration`, the linear stack of
every carried feature above current upstream, and the only ref fmx's Companion
pin may name.
_Avoid_: install branch, local main, feature branch.

**Main mirror** — Local `main` and `possibilities/zmx:main`, both fast-forwarded
to the exact current `neurosnap/zmx:main` during every maintenance cycle.
_Avoid_: integration base, development main.

**Stack** — The ordered commits between upstream `main` and `integration`, one
or a few per carried feature, rebased as a whole onto current upstream every
cycle. A feature is repaired by editing its commit in place; a landed one is
dropped; a new one is added at the top. Each commit's subject is the marker
`MAINTAIN.md`'s inventory and the scratchpad refer to.
_Avoid_: patch set, carry branches, series (that is what the rebase produces,
not the thing).

**Carried feature** — Behavior required by `MAINTAIN.md` that is not yet
available on upstream `main` and therefore remains a commit in the stack.
_Avoid_: permanent patch, downstream fix.

**Offer** — A narrow plank proposed upstream: a `fix/<name>` or `feat/<name>`
branch cut from current `origin/main`, written as upstream would write it with
no fmx concept in it, pushed to the fork when its pull request opens. An offer
is evidence of intent, not a dependency: the stack carries the behavior
whether or not the offer lands, and "landed" is read from upstream `main`,
never from the request's state.
_Avoid_: PR branch, upstreamed patch, carry.

**Companion pin** — fmx's `companion.json`: the integration commit an fmx
release is built with and the build string `<zon version>+fmx.<12 hex>` a
Companion built from it reports. The consumer binding of this workshop; moved
only by `scripts/pin-companion.sh`.
_Avoid_: lock file, dependency version.

**DELETEME branch** — An explicit human marker at
`DELETEME/<original-name>` recording a decision to remove that named fork
branch. Maintenance never creates it from branch age, ownership, request
state, or namespace, and leaves every other undeclared ref untouched.
_Avoid_: quarantine branch, stale branch, automatic archive.

**Maintenance cycle** — One `/maintain` run that reviews upstream movement and
the offers' fate, rebases the stack onto current upstream, gates the
candidate, publishes `integration` under a lease, moves fmx's pin, and updates
the scratchpad.
_Avoid_: update, release (that is fmx's act).
