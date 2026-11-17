#!/usr/bin/env python3
"""List, add or remove dev-stack host slugs in modules/software/dev-hosts.json.

modules/software/dev-hosts.nix turns each slug into /etc/hosts lines for every
story worktree (127.0.0.N dev-usNNN.<slug>.localhost ...). This only edits the
JSON; the change applies at the next `just rebuild`.
"""
import json
import os
import re
import sys
import tempfile
from pathlib import Path

DATA = Path(__file__).resolve().parent.parent / "modules/software/dev-hosts.json"
LABEL = re.compile(r"[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?")


def load(path):
    data = json.loads(path.read_text())
    slugs = data.get("slugs")
    if not isinstance(slugs, list) or not all(isinstance(s, str) for s in slugs):
        raise ValueError(f"{path}: 'slugs' must be a list of strings")
    return data


def save(path, data):
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".dev-hosts-")
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(data, stream, indent=2)
            stream.write("\n")
        os.chmod(tmp, 0o644)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def main(argv, path=DATA):
    if not argv or argv[0] not in ("list", "add", "remove") or (argv[0] != "list" and len(argv) != 2):
        print("usage: dev-hosts.py list | add <slug> | remove <slug>", file=sys.stderr)
        return 2
    data = load(path)
    slugs = data["slugs"]
    if argv[0] == "list":
        for slug in slugs:
            print(f"{slug}: [api.]dev.{slug}.localhost on 127.0.0.1; "
                  f"[api.]dev-usNNN.{slug}.localhost and [api.]test-usNNN.{slug}.localhost on 127.0.0.N (N = 1-253)")
        if not slugs:
            print("(no slugs; add one with: just dev-host-add <slug>)")
        return 0
    slug = argv[1]
    if argv[0] == "add":
        if not LABEL.fullmatch(slug):
            print(f"refusing: {slug!r} is not a valid hostname label "
                  "(lower-case letters, digits and inner hyphens, at most 63)", file=sys.stderr)
            return 1
        if slug in slugs:
            print(f"{slug} is already listed.")
            return 0
        data["slugs"] = sorted(slugs + [slug])
    else:
        if slug not in slugs:
            print(f"{slug} is not listed.", file=sys.stderr)
            return 1
        data["slugs"] = [s for s in slugs if s != slug]
    save(path, data)
    print(f"{'Added' if argv[0] == 'add' else 'Removed'} {slug}. Apply with: just rebuild")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
