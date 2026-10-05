#!/usr/bin/env python3
"""Copy current Git-listed source for path flakes, excluding build artifacts.

Usage: python3 scripts/prepare-nix-source.py /tmp/nix-config-source
Use a new empty directory. Includes untracked source, preserving local edits;
does not alter the repository or Git index.
"""
from pathlib import Path
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
destination = Path(sys.argv[1]).resolve()
if destination == root or root in destination.parents:
    sys.exit("Choose a destination outside this repository")
destination.mkdir(parents=True, exist_ok=True)
if any(destination.iterdir()):
    sys.exit("Destination must be empty; use a fresh directory")
paths = subprocess.check_output(
    ["git", "ls-files", "--cached", "--others", "--exclude-standard", "-z"], cwd=root
).split(b"\0")
count = 0
for raw in paths:
    if not raw:
        continue
    relative = Path(raw.decode())
    if any(part in {"target", "__pycache__", ".git", "node_modules", ".direnv"} for part in relative.parts):
        continue
    source = root / relative
    if not source.is_file() and not source.is_symlink():
        continue
    output = destination / relative
    output.parent.mkdir(parents=True, exist_ok=True)
    if source.is_symlink():
        output.symlink_to(source.readlink())
    else:
        shutil.copy2(source, output)
    count += 1
print(f"Copied {count} source files to {destination}")
