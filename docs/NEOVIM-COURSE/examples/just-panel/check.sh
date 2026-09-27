#!/usr/bin/env bash
# Build, test, lint and format-check the just-panel worked examples.
#
# Usage, from docs/NEOVIM-COURSE/examples/just-panel:
#
#   ./check.sh JP5     one milestone (JP0 to JP8)
#   ./check.sh all     every milestone, JP0 to JP8 in order
#
# Each JPn/ is a mini Cargo workspace (JPn/Cargo.toml) whose crate is
# JPn/just-panel/. In it the script runs:
#
#   cargo build --locked
#   cargo test --locked
#   cargo clippy --locked --all-targets -- -D warnings
#   cargo fmt --check
#
# and prints PASS or FAIL for each. A check passes only with exit code 0 and no
# `warning` lines: rustc warnings do not make `cargo build` fail on their own.
# `--locked` makes cargo stop rather than rewrite the example's Cargo.lock.
#
# Build output goes to CARGO_TARGET_DIR, which defaults to a folder OUTSIDE the
# repository (${TMPDIR:-/tmp}/just-panel-examples-target), so the course tree
# never gains a target/ folder. Exit status: 0 when every check passed.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
export CARGO_TARGET_DIR=${CARGO_TARGET_DIR:-${TMPDIR:-/tmp}/just-panel-examples-target}

usage() {
    echo "usage: $0 JP0..JP8 | all" >&2
    exit 2
}

[ $# -eq 1 ] || usage
case $1 in
    all) milestones=(JP0 JP1 JP2 JP3 JP4 JP5 JP6 JP7 JP8) ;;
    JP[0-8]) milestones=("$1") ;;
    *) usage ;;
esac

failures=0

run() {
    local label=$1
    shift
    local log code warnings
    log=$("$@" 2>&1)
    code=$?
    warnings=$(grep -c '^warning' <<<"$log")
    if [ "$code" -eq 0 ] && [ "$warnings" -eq 0 ]; then
        echo "PASS  $label"
    else
        echo "FAIL  $label (exit $code, $warnings warning lines)"
        tail -40 <<<"$log"
        failures=$((failures + 1))
    fi
    # Show the test summaries, so the counts can be compared with MILESTONES.md.
    grep -E '^test result:' <<<"$log" | sed 's/^/      /'
    return 0
}

echo "target directory: $CARGO_TARGET_DIR"
for snap in "${milestones[@]}"; do
    cd "$here/$snap" || exit 1
    # The touch trick. Every milestone's crate sits at the same path inside its
    # workspace (just-panel/), and cargo keys a crate's fingerprint on that
    # relative path. In one shared target folder, cargo compares this
    # milestone's source file times with the last build of *any* milestone:
    # when the files are older (as they are after a checkout), it takes the
    # crate as up to date and reuses the previous milestone's build and test
    # binary. Touching main.rs makes it newer, so the crate really recompiles.
    # Dependencies are still reused, so this costs seconds, not minutes.
    touch just-panel/src/main.rs
    echo "== $snap"
    run "cargo build" cargo build --locked
    run "cargo test" cargo test --locked
    run "cargo clippy --all-targets -- -D warnings" cargo clippy --locked --all-targets -- -D warnings
    run "cargo fmt --check" cargo fmt --check
done

if [ "$failures" -eq 0 ]; then
    echo "All checks passed."
else
    echo "$failures check(s) failed."
    exit 1
fi
