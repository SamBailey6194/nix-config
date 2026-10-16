"""Point a graphify SKILL.md at the Nix interpreter instead of installing graphify.

Upstream's Step 1 picks an interpreter in this order: `uv tool run --from
graphifyy` (PyPI, whatever is latest), the shebang of `graphify` on PATH, then
`python3` — and if none can import graphify it runs `uv tool install --upgrade
graphifyy` or `pip install graphifyy`. uv is on PATH here, so the first branch
always wins and the Nix package is never used; the install fallback would write
into ~/.local. The "Interpreter guard for subcommands" repeats the shebang probe.

Both blocks are replaced with one fixed interpreter, and both writes of
`graphify-out/.graphify_python` record that path rather than `sys.executable`:
sys.executable is a /nix/store path, which a later garbage collection would
leave dangling in every project's graphify-out/. The path given here is the
stable profile link (pkgs/graphify/default.nix).

Every anchor must match exactly once (twice for the write), so an upstream
rewrite fails the build instead of silently shipping an unpatched skill.

Usage: patch-skill.py SRC DST PYTHON
"""
import sys

STEP1_START = "# Detect the correct Python interpreter (handles uv tool, pipx, venv, system installs)\n"
STEP1_END = "# Write interpreter path for all subsequent steps (persists across invocations)\n"
GUARD = """    GRAPHIFY_BIN=$(which graphify 2>/dev/null)
    if [ -n "$GRAPHIFY_BIN" ]; then
        PYTHON=$(head -1 "$GRAPHIFY_BIN" | tr -d '#!')
        case "$PYTHON" in *[!a-zA-Z0-9/_.@-]*) PYTHON="python3" ;; esac
    else
        PYTHON="python3"
    fi
"""
WRITE = """"$PYTHON" -c "import sys; open('graphify-out/.graphify_python', 'w', encoding='utf-8').write(sys.executable)"\n"""


def replace_once(text, old, new, count=1):
    found = text.count(old)
    if found != count:
        sys.exit(f"patch-skill.py: expected {count} match(es), found {found}: {old[:60]!r}")
    return text.replace(old, new)


def main():
    src, dst, python = sys.argv[1:]
    text = open(src, encoding="utf-8").read()

    start = text.find(STEP1_START)
    end = text.find(STEP1_END)
    if start < 0 or end < start or text.count(STEP1_START) != 1:
        sys.exit("patch-skill.py: Step 1 interpreter block not found exactly once")
    text = text[:start] + (
        "# NixOS: graphify is installed declaratively (nix-config pkgs/graphify).\n"
        "# Never fetch or pip-install it: this interpreter already has graphify.\n"
        f'PYTHON="{python}"\n'
    ) + text[end:]
    text = replace_once(text, GUARD, f'    PYTHON="{python}"\n')
    # The write is indented inside the guard; match it with or without.
    found = text.count(WRITE)
    if found != 2:
        sys.exit(f"patch-skill.py: expected 2 .graphify_python writes, found {found}")
    text = text.replace(WRITE, "printf '%s' \"$PYTHON\" > graphify-out/.graphify_python\n")

    # Hints such as "pip install 'graphifyy[video]'" stay: they only print when
    # an extra fails to import, and default.nix packages the ones the skill uses.
    for banned in ("pip install graphifyy", "uv tool install", "uv tool run --from graphifyy"):
        if banned in text:
            sys.exit(f"patch-skill.py: {banned!r} still present after patching")
    open(dst, "w", encoding="utf-8").write(text)


if __name__ == "__main__":
    main()
