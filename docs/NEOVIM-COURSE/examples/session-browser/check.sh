#!/usr/bin/env bash
# Check the session-browser worked examples: uv sync, pytest, ruff, pyright.
#
# Usage, from docs/NEOVIM-COURSE/examples/session-browser:
#
#   ./check.sh SB4     one milestone (SB0 to SB8)
#   ./check.sh all     every milestone, SB0 to SB8 in order
#
# Each milestone is first copied with `cp -r` to a work folder OUTSIDE the
# repository (${TMPDIR:-/tmp}/session-browser-examples/SBn, replaced on every
# run) and checked there. `uv sync` creates .venv inside the project, which is
# where [tool.pyright] expects it, and pytest, ruff and Python write caches
# next to the code; the copy keeps all of that out of the course tree. The
# copy also has fresh file times, as a new checkout does. In the copy:
#
#   uv sync --locked
#   uv run --locked pytest -q
#   ruff check
#   ruff format --check
#   pyright
#
# ruff and pyright come from PATH when they are there (on laptop-intel NixOS
# installs both system-wide, in modules/software/development.nix), otherwise
# from `uvx`. `--locked` makes uv stop rather than rewrite the example's
# uv.lock. Exit status: 0 when every check passed.
set -uo pipefail

here=$(cd "$(dirname "$0")" && pwd)
work=${TMPDIR:-/tmp}/session-browser-examples
# A virtualenv that is active, or pointed at, elsewhere would take the place of
# the project's own .venv, which pyright is told to use.
unset VIRTUAL_ENV UV_PROJECT_ENVIRONMENT

usage() {
    echo "usage: $0 SB0..SB8 | all" >&2
    exit 2
}

[ $# -eq 1 ] || usage
case $1 in
    all) milestones=(SB0 SB1 SB2 SB3 SB4 SB5 SB6 SB7 SB8) ;;
    SB[0-8]) milestones=("$1") ;;
    *) usage ;;
esac

if command -v ruff >/dev/null; then ruff=(ruff); else ruff=(uvx ruff); fi
if command -v pyright >/dev/null; then pyright=(pyright); else pyright=(uvx pyright); fi

failures=0

# run LABEL COMMAND...: PASS on exit 0, otherwise FAIL and the end of the log.
# Prints the last line of the output, which holds pytest's counts.
run() {
    local label=$1
    shift
    local log code
    log=$("$@" 2>&1)
    code=$?
    if [ "$code" -eq 0 ]; then
        echo "PASS  $label"
    elif [ "$label" = "pytest" ] && [ "$code" -eq 5 ] && [ ! -d tests ]; then
        # pytest exits 5 when it collects nothing: SB0 has no tests yet.
        echo "PASS  $label (no tests yet: the first ones arrive in SB1)"
    else
        echo "FAIL  $label (exit $code)"
        tail -40 <<<"$log"
        failures=$((failures + 1))
        return 0
    fi
    if [ "$label" = "pytest" ]; then
        tail -1 <<<"$log" | sed 's/^/      /'
    fi
    return 0
}

echo "work folder: $work"
echo "ruff: ${ruff[*]} ($("${ruff[@]}" --version 2>&1 | tail -1))"
echo "pyright: ${pyright[*]} ($("${pyright[@]}" --version 2>&1 | tail -1))"
mkdir -p "$work"
for snap in "${milestones[@]}"; do
    rm -rf "${work:?}/$snap"
    cp -r "$here/$snap" "$work/$snap"
    cd "$work/$snap" || exit 1
    echo "== $snap"
    run "uv sync" uv sync --locked
    echo "      $(uv run --locked python --version 2>&1)"
    run "pytest" uv run --locked pytest -q
    run "ruff check" "${ruff[@]}" check
    run "ruff format --check" "${ruff[@]}" format --check
    if grep -q '^\[tool\.pyright\]' pyproject.toml; then
        run "pyright" "${pyright[@]}"
    else
        # SB0 to SB2 predate [tool.pyright] (lesson 10 adds it), so name the
        # venv's Python here instead.
        run "pyright --pythonpath .venv/bin/python" "${pyright[@]}" --pythonpath .venv/bin/python
    fi
done

if [ "$failures" -eq 0 ]; then
    echo "All checks passed."
else
    echo "$failures check(s) failed."
    exit 1
fi
