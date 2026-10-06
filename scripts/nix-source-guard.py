#!/usr/bin/env python3
"""Claude PreToolUse guard: reject path flakes aimed at Git working trees.

This is a guardrail for direct commands, not a shell security boundary.
Instructions remain necessary for commands hidden in scripts or variables.
"""
import json
import re
import sys
from pathlib import Path
from urllib.parse import unquote


def violation(command, cwd):
    for match in re.finditer(r"\bpath:([^\s\"'`;|&)]+)", command):
        raw = unquote(match.group(1).split("#", 1)[0].split("?", 1)[0])
        # Unresolved shell variables cannot be checked statically.
        if "$" in raw or "`" in raw:
            return True
        path = Path(raw).expanduser()
        if not path.is_absolute():
            path = Path(cwd) / path
        path = path.resolve()
        for parent in (path, *path.parents):
            marker = parent / ".git"
            if marker.is_file() or (marker / "HEAD").is_file():
                return True
    return False


def main():
    payload = json.load(sys.stdin)
    command = payload.get("tool_input", {}).get("command", "")
    if violation(command, payload.get("cwd", str(Path.cwd()))):
        print("Use a Git-backed flake or a fresh source-only copy made with "
              "scripts/prepare-nix-source.py; path: copies ignored build artifacts.",
              file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
