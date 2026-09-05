#!/bin/bash
# Run via python3 .githooks/pre-push --check for the shared lock and deadline.
set -euo pipefail
cd "$(dirname "$0")/.."
scripts=(scripts/reconcile-branches.sh scripts/pin-companion.sh tests/validate.sh
    tests/pin-transaction.sh tests/fixtures/fake-zig.sh scripts/check-static.sh scripts/install-hooks.sh)
for script in "${scripts[@]}"; do
    bash -n "$script"
done
shellcheck --severity=warning "${scripts[@]}"
printf 'Static checks passed.\n'
