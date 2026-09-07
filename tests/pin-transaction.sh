#!/bin/bash

set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)

fail() {
    printf 'pin-transaction: %s\n' "$*" >&2
    exit 1
}

test_root=$(mktemp -d "${TMPDIR:-/tmp}/zmax-pin-test.XXXXXX")
cleanup() {
    local status=$?
    trap - EXIT
    rm -rf -- "$test_root"
    exit "$status"
}
trap cleanup EXIT

# A fork: upstream main, an integration stack above it, published to a bare fork.
zmx="$test_root/zmx"
zmx_fork="$test_root/zmx-fork.git"
git init --quiet --initial-branch=main "$zmx"
git -C "$zmx" config user.name zmax-test
git -C "$zmx" config user.email zmax@example.invalid
printf '.{\n    .name = .zmx,\n    .version = "0.7.0",\n    .minimum_zig_version = "0.16.0",\n}\n' >"$zmx/build.zig.zon"
git -C "$zmx" add build.zig.zon
git -C "$zmx" commit --quiet -m upstream
git -C "$zmx" switch --quiet -c integration
printf 'companion\n' >"$zmx/companion"
git -C "$zmx" add companion
git -C "$zmx" commit --quiet -m "feat: companion"
integration_sha=$(git -C "$zmx" rev-parse HEAD)
git init --quiet --bare "$zmx_fork"
git -C "$zmx" remote add fork "$zmx_fork"
git -C "$zmx" push --quiet fork main integration

# smolmux: a pin at upstream's commit, on main, with a bare origin.
smolmux="$test_root/smolmux"
smolmux_origin="$test_root/smolmux-origin.git"
git init --quiet --initial-branch=main "$smolmux"
git -C "$smolmux" config user.name zmax-test
git -C "$smolmux" config user.email zmax@example.invalid
old_sha=$(git -C "$zmx" rev-parse main)
printf '{\n  "repository": "https://github.com/possibilities/zmx.git",\n  "branch": "integration",\n  "commit": "%s",\n  "build": "0.7.0+fmx.%s"\n}\n' \
    "$old_sha" "${old_sha:0:12}" >"$smolmux/companion.json"
mkdir -p "$smolmux/scripts" "$smolmux/tests"
consumer_builder="${ZMAX_TEST_BUILD_COMPANION:-$HOME/code/smolmux/scripts/build-companion.sh}"
[ -x "$consumer_builder" ] || fail "shared consumer builder not found: $consumer_builder"
cp "$consumer_builder" "$smolmux/scripts/build-companion.sh"
touch "$smolmux/tests/instance.e2e.test.ts"
git -C "$smolmux" add companion.json scripts tests
git -C "$smolmux" commit --quiet -m pin
git init --quiet --bare "$smolmux_origin"
git -C "$smolmux" remote add origin "$smolmux_origin"
git -C "$smolmux" push --quiet origin main
git -C "$smolmux" branch --set-upstream-to=origin/main main >/dev/null

fake_bin="$test_root/bin"
mkdir "$fake_bin"
ln -s "$root/tests/fixtures/fake-zig.sh" "$fake_bin/zig"

run_pin() {
    PATH="$fake_bin:$PATH" \
    ZMAX_ZMX_CHECKOUT="$zmx" \
    ZMAX_SMOLMUX_CHECKOUT="$smolmux" \
    ZMAX_PIN_SKIP_TESTS=1 \
    "$root/scripts/pin-companion.sh" "$@"
}

run_pin_with_tests() {
    PATH="$fake_bin:$PATH" \
    ZMAX_ZMX_CHECKOUT="$zmx" \
    ZMAX_SMOLMUX_CHECKOUT="$smolmux" \
    ZMAX_PIN_SKIP_TESTS=0 \
    "$root/scripts/pin-companion.sh" "$@"
}

expected_build="0.7.0+fmx.${integration_sha:0:12}"

# --check plans and writes nothing.
check_output=$(run_pin --check)
printf '%s\n' "$check_output" | grep -F "PIN  $old_sha -> $integration_sha" >/dev/null \
    || { printf '%s\n' "$check_output" >&2; fail "--check did not plan the pin move"; }
printf '%s\n' "$check_output" | grep -F "BUILD 0.7.0+fmx.${old_sha:0:12} -> $expected_build" >/dev/null \
    || { printf '%s\n' "$check_output" >&2; fail "--check did not plan the build string"; }
[ -z "$(git -C "$smolmux" status --porcelain)" ] || fail "--check changed smolmux"

# Unpublished integration is refused before anything is built.
printf 'more\n' >>"$zmx/companion"
git -C "$zmx" commit --quiet -am "feat: more"
set +e
unpublished_output=$(run_pin --apply 2>&1)
unpublished_status=$?
set -e
[ "$unpublished_status" -ne 0 ] || fail "pinned an unpublished integration"
printf '%s\n' "$unpublished_output" | grep -F 'is not the published fork/integration' >/dev/null \
    || { printf '%s\n' "$unpublished_output" >&2; fail "did not explain the unpublished integration"; }
git -C "$zmx" reset --quiet --hard "$integration_sha"

# A Companion that misreports its build is refused, and the pin file is untouched.
set +e
misreport_output=$(FAKE_ZIG_REPORT=0.7.0 run_pin --apply 2>&1)
misreport_status=$?
set -e
[ "$misreport_status" -ne 0 ] || fail "accepted a Companion reporting the wrong build"
printf '%s\n' "$misreport_output" | grep -F "reports '0.7.0', not $expected_build" >/dev/null \
    || { printf '%s\n' "$misreport_output" >&2; fail "did not explain the misreported build"; }
grep -F "\"commit\": \"$old_sha\"" "$smolmux/companion.json" >/dev/null \
    || fail "a refused pin changed companion.json"
[ -z "$(git -C "$smolmux" status --porcelain)" ] || fail "a refused pin left smolmux dirty"
[ "$(git -C "$zmx" worktree list | wc -l | tr -d ' ')" = 1 ] \
    || fail "a refused pin left a build worktree"

# A failed build leaves everything as it was.
set +e
FAKE_ZIG_FAIL=1 run_pin --apply >/dev/null 2>&1 && fail "accepted a failed build"
set -e
[ -z "$(git -C "$smolmux" status --porcelain)" ] || fail "a failed build left smolmux dirty"

# A failed smolmux gate restores companion.json byte for byte, including its final
# newline. Command substitution used to lose it and leave the clean checkout
# dirty after the otherwise-correct rollback.
printf '#!/bin/sh\nexit 1\n' >"$fake_bin/bun"
chmod +x "$fake_bin/bun"
pin_before_failure=$(git -C "$smolmux" hash-object companion.json)
set +e
gate_failure_output=$(run_pin_with_tests --apply 2>&1)
gate_failure_status=$?
set -e
[ "$gate_failure_status" -ne 0 ] || fail "accepted a failed smolmux gate"
printf '%s\n' "$gate_failure_output" | grep -F 'smolmux typecheck failed against the new pin' >/dev/null \
    || { printf '%s\n' "$gate_failure_output" >&2; fail "did not explain the failed smolmux gate"; }
[ "$(git -C "$smolmux" hash-object companion.json)" = "$pin_before_failure" ] \
    || fail "a failed smolmux gate did not restore companion.json byte for byte"
[ -z "$(git -C "$smolmux" status --porcelain)" ] || fail "a failed smolmux gate left smolmux dirty"
rm "$fake_bin/bun"

# Failure after a concurrent pin edit must preserve the other writer's bytes.
cat >"$fake_bin/bun" <<'BUN'
#!/bin/bash
printf 'concurrent pin edit\n' > companion.json
exit 1
BUN
chmod +x "$fake_bin/bun"
if run_pin_with_tests --apply >"$test_root/concurrent.log" 2>&1; then
    fail "accepted a concurrently edited pin"
fi
[ "$(cat "$smolmux/companion.json")" = 'concurrent pin edit' ] \
    || fail "rollback overwrote another writer's pin"
git -C "$smolmux" restore --worktree -- companion.json
rm "$fake_bin/bun"

# Another session committing the provisional pin owns that new HEAD. Rollback
# must not leave a dirty reversal of its committed file.
fixture_head=$(git -C "$smolmux" rev-parse HEAD)
cat >"$fake_bin/bun" <<'BUN'
#!/bin/bash
set -e
git add companion.json
git commit --quiet -m 'concurrent pin commit'
exit 1
BUN
chmod +x "$fake_bin/bun"
if run_pin_with_tests --apply >"$test_root/concurrent-commit.log" 2>&1; then
    fail "accepted a concurrently committed pin"
fi
[ -z "$(git -C "$smolmux" status --porcelain)" ] || fail "rollback reversed a concurrent commit"
[ "$(git -C "$smolmux" rev-parse HEAD)" != "$fixture_head" ] || fail "fixture did not move HEAD"
git -C "$smolmux" reset --quiet --hard "$fixture_head"
rm "$fake_bin/bun"

# A rejected commit restores both the provisional file and our staged change.
printf '#!/bin/sh\nexit 1\n' >"$smolmux/.git/hooks/pre-commit"
chmod +x "$smolmux/.git/hooks/pre-commit"
if run_pin --apply >"$test_root/commit-failure.log" 2>&1; then
    fail "accepted a rejected pin commit"
fi
[ -z "$(git -C "$smolmux" status --porcelain)" ] || fail "commit failure left the pin staged or dirty"
rm "$smolmux/.git/hooks/pre-commit"

# Prove the success path actually asks for the current PTY test target.
cat >"$fake_bin/bun" <<'BUN'
#!/bin/bash
set -eu
printf '%s\n' "$*" >>"$BUN_TEST_RECEIPT"
if [ "$1" = test ] && [ "$#" -gt 1 ]; then
    [ "$2" = tests/instance.e2e.test.ts ] && [ -f "$2" ] || exit 1
fi
if [ "$1" = test ] && [ "$#" -eq 1 ]; then
    [ "${SMOLMUX_RUN_MIGRATION_TESTS:-0}" = 1 ] || exit 1
fi
BUN
chmod +x "$fake_bin/bun"
# The real thing: pin written, committed on main, pushed.
BUN_TEST_RECEIPT="$test_root/bun-receipt" run_pin_with_tests --apply >/dev/null
grep -Fx 'test tests/instance.e2e.test.ts' "$test_root/bun-receipt" >/dev/null \
    || fail "success skipped the PTY gate"
grep -F "\"commit\": \"$integration_sha\"" "$smolmux/companion.json" >/dev/null \
    || fail "the pin was not moved"
grep -F "\"build\": \"$expected_build\"" "$smolmux/companion.json" >/dev/null \
    || fail "the build string was not written"
[ -z "$(git -C "$smolmux" status --porcelain)" ] || fail "the pin was not committed"
[ "$(git --git-dir="$smolmux_origin" rev-parse main)" = "$(git -C "$smolmux" rev-parse main)" ] \
    || fail "the pin was not pushed"
git -C "$smolmux" log -1 --format=%s | grep -F "Pin the Companion to zmx ${integration_sha:0:12}" >/dev/null \
    || fail "the pin commit is not named"
[ "$(git -C "$zmx" worktree list | wc -l | tr -d ' ')" = 1 ] \
    || fail "the build worktree was not removed"

# Running again is a no-op.
run_pin --apply | grep -F 'Already pinned.' >/dev/null || fail "a second apply was not a no-op"

printf 'pin transaction validation passed.\n'
