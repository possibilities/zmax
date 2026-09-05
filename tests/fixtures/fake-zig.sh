#!/bin/bash
# A zig that builds nothing: it writes a bin/zmx answering `version` with the
# -Dversion it was given, so the pin script's proof of the build can run
# without Zig. Set FAKE_ZIG_FAIL=1 to fail the build, FAKE_ZIG_REPORT to make
# the binary misreport its build.
set -euo pipefail
if [ "${1:-}" = version ]; then printf '0.16.0\n'; exit 0; fi
version=
prefix=
for argument in "$@"; do
    case "$argument" in
        -Dversion=*) version=${argument#-Dversion=} ;;
        --prefix) prefix=__next__ ;;
        *) if [ "$prefix" = __next__ ]; then prefix=$argument; fi ;;
    esac
done
[ "${FAKE_ZIG_FAIL:-0}" -eq 1 ] && { echo "fake zig: build failed" >&2; exit 1; }
[ -n "$prefix" ] || { echo "fake zig: no --prefix" >&2; exit 2; }
mkdir -p "$prefix/bin"
printf '#!/bin/sh\nprintf "zmx\\t\\t%%s\\n" "%s"\n' "${FAKE_ZIG_REPORT:-$version}" >"$prefix/bin/zmx"
chmod 0755 "$prefix/bin/zmx"
