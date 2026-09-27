#!/usr/bin/env bash
# Build the just-panel worked examples that have a TUI (JP5 to JP8) and run
# smoke.py's real-terminal scenarios against each, on the course's demo
# justfile (../../fixtures/just/justfile: its recipes only echo, sleep or print
# the time, so nothing real runs).
#
# Usage, from docs/NEOVIM-COURSE/examples/just-panel:
#
#   ./smoke-all.sh             JP5, JP6, JP7 and JP8
#   ./smoke-all.sh JP7 JP8     only those milestones
#
# Needs cargo, just and uv. smoke.py reads the screen with pyte, which uv
# fetches into its cache on first use (`uv run --no-project --with pyte`), so
# nothing is installed and no virtualenv appears here. Build output goes to
# the same target folder as check.sh, outside the repository. Exit status: 0
# when every scenario passed.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
export CARGO_TARGET_DIR=${CARGO_TARGET_DIR:-${TMPDIR:-/tmp}/just-panel-examples-target}

declare -A scenarios=(
    [JP5]="navigate ctrl-c ctrl-keys"
    [JP6]="navigate filter-help ctrl-c ctrl-keys"
    [JP7]="navigate filter-help ctrl-c ctrl-keys run typeahead symlink"
    [JP8]="navigate filter-help ctrl-c ctrl-keys run typeahead symlink"
)

[ $# -gt 0 ] || set -- JP5 JP6 JP7 JP8
for snap in "$@"; do
    if [ -z "${scenarios[$snap]+set}" ]; then
        echo "usage: $0 [JP5 JP6 JP7 JP8]" >&2
        exit 2
    fi
done

failures=0
for snap in "$@"; do
    # The touch trick from check.sh: in a shared target folder cargo would
    # otherwise reuse the previous milestone's binary.
    touch "$here/$snap/just-panel/src/main.rs"
    if ! (cd "$here/$snap" && cargo build --locked -q); then
        echo "== $snap: build failed"
        failures=$((failures + 1))
        continue
    fi
    # The binary cargo just built; each milestone's scenarios run before the
    # next milestone's build replaces it.
    bin=$CARGO_TARGET_DIR/debug/just-panel
    for scenario in ${scenarios[$snap]}; do
        result=$(uv run -q --no-project --with pyte python "$here/smoke.py" "$bin" "$scenario")
        code=$?
        grep '^FAIL' <<<"$result"
        echo "$snap $(grep '^==' <<<"$result")"
        [ "$code" -eq 0 ] || failures=$((failures + 1))
    done
done

if [ "$failures" -eq 0 ]; then
    echo "All scenarios passed."
else
    echo "$failures scenario(s) or build(s) failed."
    exit 1
fi
