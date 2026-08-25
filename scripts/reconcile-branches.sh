#!/bin/bash

set -euo pipefail

# zmax's entrypoint to the maintain skill's shared namespace script. It
# declares what MAINTAIN.md's Branch model says — the checkout, the remotes,
# the branch names, the linear-stack model — and nothing else; the mechanics
# (a read-only check from a disposable snapshot and one atomic exact-leased
# push of declared refs that leaves all other heads unchanged) are the skill's
# and are tested there.

skill_dir="${MAINTAIN_SKILL_DIR:-$HOME/.local/share/agentstart/core-marketplace/plugins/agentstart-core/skills/maintain}"
script="$skill_dir/scripts/reconcile-branches.sh"
if [ ! -f "$script" ]; then
    printf 'zmax branches: the maintain skill is not installed at %s (render ~/code/agentguidance, or set MAINTAIN_SKILL_DIR)\n' \
        "$skill_dir" >&2
    exit 1
fi

export MAINTAIN_CHECKOUT="${ZMAX_ZMX_CHECKOUT:-$HOME/src/zmx}"
export MAINTAIN_FORK_REPO=possibilities/zmx
export MAINTAIN_UPSTREAM_REPO=neurosnap/zmx
export MAINTAIN_FORK_REMOTE=fork
export MAINTAIN_UPSTREAM_REMOTE=origin
export MAINTAIN_MAIN_BRANCH=main
export MAINTAIN_INTEGRATION_BRANCH=integration
export MAINTAIN_CARRY_PREFIX=''
export MAINTAIN_QUARANTINE_PREFIX=DELETEME/
export MAINTAIN_PRESERVE_OPEN_PRS=1

exec bash "$script" "$@"
