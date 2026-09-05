#!/bin/bash

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

fail() {
    printf 'validate: %s\n' "$*" >&2
    exit 1
}

bash -n scripts/reconcile-branches.sh
bash -n scripts/pin-companion.sh
bash -n tests/pin-transaction.sh
bash -n tests/fixtures/fake-zig.sh
for script in scripts/reconcile-branches.sh scripts/pin-companion.sh tests/pin-transaction.sh tests/fixtures/fake-zig.sh; do
    [ -x "$script" ] || fail "$script is not executable"
done
[ "$(readlink CLAUDE.md)" = AGENTS.md ] || fail "CLAUDE.md must link to AGENTS.md"

# The spec has every section the shared maintain skill reads by name.
for section in Purpose Upstream 'Branch model' Features Gate Consumer Notify; do
    grep -Fx "## $section" MAINTAIN.md >/dev/null \
        || fail "MAINTAIN.md is missing the section: ## $section"
done
grep -F 'Composition: linear stack' MAINTAIN.md >/dev/null \
    || fail "the branch model does not declare the linear stack"
grep -F 'scripts/pin-companion.sh --apply' MAINTAIN.md >/dev/null \
    || fail "the consumer does not name the pin script"
grep -F 'No external proof is required' MAINTAIN.md >/dev/null \
    || fail "the gate does not say whether external proof is required"
# shellcheck disable=SC2016 # Match literal Markdown text.
grep -F 'Title: `zmx Maintenance`' MAINTAIN.md >/dev/null \
    || fail "the notification title is missing"
if grep -F 'agentwiki' MAINTAIN.md >/dev/null; then
    fail "the spec depends on an external wiki policy"
fi

# The namespace entrypoint declares exactly the branch model the spec states
# and defers every mechanic to the shared script.
for declared in \
    'MAINTAIN_FORK_REPO=possibilities/zmx' \
    'MAINTAIN_UPSTREAM_REPO=neurosnap/zmx' \
    'MAINTAIN_MAIN_BRANCH=main' \
    'MAINTAIN_INTEGRATION_BRANCH=integration' \
    "MAINTAIN_CARRY_PREFIX=''" \
    'MAINTAIN_QUARANTINE_PREFIX=DELETEME/' \
    'MAINTAIN_PRESERVE_OPEN_PRS=1'; do
    grep -F "export $declared" scripts/reconcile-branches.sh >/dev/null \
        || fail "branch entrypoint does not declare $declared"
done
if grep -E 'git .*(push|fetch|update-ref)' scripts/reconcile-branches.sh >/dev/null; then
    fail "branch entrypoint carries namespace mechanics of its own"
fi
set +e
missing_skill_output=$(MAINTAIN_SKILL_DIR=/nonexistent scripts/reconcile-branches.sh --check 2>&1)
missing_skill_status=$?
set -e
[ "$missing_skill_status" -ne 0 ] || fail "branch entrypoint ran without the shared script"
printf '%s\n' "$missing_skill_output" | grep -F 'the maintain skill is not installed' >/dev/null \
    || fail "branch entrypoint does not explain a missing shared script"

# The pin script is a consumer, never a maintainer: it builds the published
# commit detached, proves the build, and moves nothing but the pin.
grep -F 'scripts/build-companion.sh" --output' scripts/pin-companion.sh >/dev/null \
    || fail "pin script does not use the shared consumer builder"
grep -F 'is not the published' scripts/pin-companion.sh >/dev/null \
    || fail "pin script does not refuse an unpublished integration"
grep -F 'tests/instance.e2e.test.ts' scripts/pin-companion.sh >/dev/null \
    || fail "pin script does not run the current PTY suite"
if grep -E 'git .*(rebase|push .*(force|lease))' scripts/pin-companion.sh >/dev/null; then
    fail "pin script contains maintenance behavior"
fi

tests/pin-transaction.sh

printf 'zmax validation passed.\n'
