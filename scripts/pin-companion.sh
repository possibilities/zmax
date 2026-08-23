#!/bin/bash

set -euo pipefail

# The consumer step of a zmx maintenance cycle: move fmx's Companion pin to
# the published integration commit, proven first. fmx's own release is not
# this script's to cut.
#
#   --check   say what would be pinned, build nothing, write nothing
#   --apply   build, test, write companion.json, commit on fmx main, push

die() {
    printf 'zmax pin: %s\n' "$*" >&2
    exit 1
}

usage() {
    printf 'Usage: scripts/pin-companion.sh --check|--apply\n'
}

case "${1:-}" in
    --check) mode=check ;;
    --apply) mode=apply ;;
    -h|--help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        exit 64
        ;;
esac
[ "$#" -eq 1 ] || {
    usage >&2
    exit 64
}

zmx_checkout="${ZMAX_ZMX_CHECKOUT:-$HOME/src/zmx}"
fmx_checkout="${ZMAX_FMX_CHECKOUT:-$HOME/code/fmx}"
fork_remote="${ZMAX_FORK_REMOTE:-fork}"
integration_branch=integration
pin_file="$fmx_checkout/companion.json"
fmx_remote="${ZMAX_FMX_REMOTE:-origin}"
fmx_branch="${ZMAX_FMX_BRANCH:-main}"
skip_tests="${ZMAX_PIN_SKIP_TESTS:-0}"

for command in git zig; do
    command -v "$command" >/dev/null 2>&1 || die "$command is required"
done
if [ "$skip_tests" -ne 1 ]; then
    command -v bun >/dev/null 2>&1 || die "bun is required"
fi

# companion.json is fmx's four-key file; read one key without a JSON parser
# so this script needs nothing a fixture cannot provide.
pin_value() {
    sed -n 's/^[[:space:]]*"'"$1"'":[[:space:]]*"\([^"]*\)".*/\1/p' "$pin_file" | head -n 1
}

# The fork: clean, and its integration exactly what is published.
git -C "$zmx_checkout" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "$zmx_checkout is not a git worktree"
[ -z "$(git -C "$zmx_checkout" status --porcelain --untracked-files=no)" ] \
    || die "$zmx_checkout has local changes"
commit=$(git -C "$zmx_checkout" rev-parse "refs/heads/$integration_branch") \
    || die "$zmx_checkout has no $integration_branch"
published=$(git -C "$zmx_checkout" ls-remote --exit-code --heads "$fork_remote" \
    "refs/heads/$integration_branch" | awk 'NR == 1 { print $1 }') \
    || die "$fork_remote has no $integration_branch"
[ "$commit" = "$published" ] \
    || die "local $integration_branch ($commit) is not the published $fork_remote/$integration_branch ($published); publish first"
zon_version=$(git -C "$zmx_checkout" show "$commit:build.zig.zon" \
    | grep -m 1 -E '^[[:space:]]*\.version = "' \
    | sed 's/^[[:space:]]*\.version = "\([^"]*\)",.*/\1/')
[ -n "$zon_version" ] || die "no .version in build.zig.zon at $commit"
build="$zon_version+fmx.${commit:0:12}"
repository=$(git -C "$zmx_checkout" remote get-url "$fork_remote")
case "$repository" in
    git@github.com:*) repository="https://github.com/${repository#git@github.com:}" ;;
esac
case "$repository" in
    *.git) ;;
    *) repository="$repository.git" ;;
esac

# fmx: clean on its branch, current with its remote.
git -C "$fmx_checkout" rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "$fmx_checkout is not a git worktree"
[ "$(git -C "$fmx_checkout" branch --show-current)" = "$fmx_branch" ] \
    || die "$fmx_checkout is not on $fmx_branch"
[ -z "$(git -C "$fmx_checkout" status --porcelain)" ] \
    || die "$fmx_checkout has local changes"
[ -f "$pin_file" ] || die "$pin_file is missing"
current_commit=$(pin_value commit)
current_build=$(pin_value build)
[ -n "$current_commit" ] && [ -n "$current_build" ] || die "$pin_file has no commit and build"

printf 'PIN  %s -> %s\n' "$current_commit" "$commit"
printf 'BUILD %s -> %s\n' "$current_build" "$build"
if git -C "$zmx_checkout" cat-file -e "$current_commit^{commit}" 2>/dev/null \
    && ! git -C "$zmx_checkout" diff --quiet "$current_commit" "$commit" -- build.zig.zon; then
    printf 'NOTICES build.zig.zon changed since the previous pin: re-check the Companion section of %s/THIRD_PARTY_NOTICES.md\n' "$fmx_checkout"
fi
if [ "$current_commit" = "$commit" ] && [ "$current_build" = "$build" ]; then
    printf 'Already pinned.\n'
    exit 0
fi
[ "$mode" = apply ] || exit 0

git -C "$fmx_checkout" pull --quiet --ff-only "$fmx_remote" "$fmx_branch" \
    || die "could not fast-forward $fmx_checkout to $fmx_remote/$fmx_branch"

work_dir=$(mktemp -d "${TMPDIR:-/tmp}/zmax-pin.XXXXXX")
build_worktree="$work_dir/zmx"
cleanup() {
    local status=$?
    trap - EXIT
    if [ -d "$build_worktree" ]; then
        git -C "$zmx_checkout" worktree remove --force "$build_worktree" >/dev/null 2>&1 || true
    fi
    rm -rf -- "$work_dir"
    exit "$status"
}
trap cleanup EXIT

# Build the published commit itself, detached, never the bound checkout.
git -C "$zmx_checkout" worktree add --quiet --detach "$build_worktree" "$commit" \
    || die "could not check out $commit for the build"
(cd "$build_worktree" && zig build -Dcompanion -Doptimize=ReleaseFast \
    -Dversion="$build" --prefix "$work_dir/companion") \
    || die "the Companion did not build at $commit"
companion="$work_dir/companion/bin/zmx"
reported=$(ZMX_DIR="$work_dir/zmx-dir" "$companion" version 2>/dev/null | awk 'NR == 1 && $1 == "zmx" { print $2 }')
[ "$reported" = "$build" ] || die "the Companion reports '$reported', not $build"

# Write the pin, then prove fmx against the build it names; revert on failure.
previous_pin=$(cat "$pin_file")
restore_pin() {
    printf '%s' "$previous_pin" >"$pin_file"
}
printf '{\n  "repository": "%s",\n  "branch": "%s",\n  "commit": "%s",\n  "build": "%s"\n}\n' \
    "$repository" "$integration_branch" "$commit" "$build" >"$pin_file"

if [ "$skip_tests" -ne 1 ]; then
    (cd "$fmx_checkout" && bun run typecheck) || { restore_pin; die "fmx typecheck failed against the new pin"; }
    (cd "$fmx_checkout" && FMX_ZMX_PATH="$companion" bun test) \
        || { restore_pin; die "fmx tests failed against Companion $build"; }
    (cd "$fmx_checkout" && FMX_ZMX_PATH="$companion" FMX_RUN_PTY_TESTS=1 bun test tests/multiplexer.e2e.test.ts) \
        || { restore_pin; die "fmx e2e failed against Companion $build"; }
fi

git -C "$fmx_checkout" add companion.json
git -C "$fmx_checkout" commit --quiet -m "Pin the Companion to zmx ${commit:0:12}

fmx-zmx is built from possibilities/zmx integration at $commit and reports
$build." || { restore_pin; die "could not commit the pin"; }
git -C "$fmx_checkout" push --quiet "$fmx_remote" "$fmx_branch" \
    || die "the pin is committed locally but could not be pushed; push $fmx_checkout $fmx_branch by hand"

printf 'Pinned fmx to Companion %s (%s); fmx %s pushed.\n' "$build" "${commit:0:12}" "$fmx_branch"

# The machine's editable fmx finds fmx-zmx on PATH; fmx's own script keeps
# that one at the pin. A failure here is reported, not fatal: the pin is
# already real, and the script can be rerun by hand.
if [ "$skip_tests" -ne 1 ] && [ -x "$fmx_checkout/scripts/install-companion.sh" ]; then
    "$fmx_checkout/scripts/install-companion.sh" \
        || printf 'zmax pin: the local Companion was not refreshed; rerun %s/scripts/install-companion.sh\n' "$fmx_checkout" >&2
fi
