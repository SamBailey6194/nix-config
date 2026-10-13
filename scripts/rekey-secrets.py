#!/usr/bin/env python3
"""Rekey the secrets one agenix identity can open; list the rest as skipped.

Usage: python3 scripts/rekey-secrets.py [--identity KEY] [--all] [--dry-run]

`agenix -r` stops at the first file the identity cannot open, and a device's
editing key opens only that device's secrets, so it never finishes. This reads
each .age header instead (recipient tags are public, nothing is decrypted to
check) and rekeys only files that list the identity. Files whose recipients
already match secrets/secrets.nix are left alone unless --all is given, so
each passphrase prompt is for a file that changes.

The identity defaults to $AGENIX_IDENTITY, then ~/.ssh/id_ed25519_agenix. Its
public key is read from KEY.pub, so checking needs no passphrase. To use a host
key (no passphrase prompts), run under sudo with AGENIX set, because sudo drops
the dev shell's PATH; rekeyed files are handed back to the sudo user:

  sudo AGENIX="$(command -v agenix)" python3 scripts/rekey-secrets.py \
    --identity /etc/ssh/ssh_host_ed25519_key
"""
import argparse
import base64
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

root = Path(__file__).resolve().parents[1]
secrets_dir = root / "secrets"
SSH_STANZA = re.compile(r"^-> ssh-(?:ed25519|rsa) (\S+)", re.MULTILINE)


def ssh_tag(public_key):
    """age's stanza tag: base64 of the first 4 bytes of SHA-256(key blob)."""
    fields = public_key.split()
    if len(fields) < 2 or not fields[0].startswith("ssh-"):
        return None
    digest = hashlib.sha256(base64.b64decode(fields[1])).digest()
    return base64.b64encode(digest[:4]).decode().rstrip("=")


def header_tags(path):
    """Recipient tags in an .age header, or None if any stanza is not SSH."""
    with open(path, "rb") as handle:
        header = handle.read(64 * 1024).split(b"\n---", 1)[0].decode("ascii", "replace")
    stanzas = re.findall(r"^-> (\S+)", header, re.MULTILINE)
    tags = SSH_STANZA.findall(header)
    return set(tags) if len(tags) == len(stanzas) else None


def wanted_tags(public_keys):
    tags = {ssh_tag(key) for key in public_keys}
    return None if None in tags else tags


def plan(rules, identity_tag, rekey_all=False):
    """Return (name, action) pairs: rekey, current, skip or missing."""
    actions = []
    for name in sorted(rules):
        path = secrets_dir / name
        if not path.is_file():
            actions.append((name, "missing"))
            continue
        present = header_tags(path)
        if present is None or identity_tag not in present:
            actions.append((name, "skip"))
        elif not rekey_all and present == wanted_tags(rules[name]):
            actions.append((name, "current"))
        else:
            actions.append((name, "rekey"))
    return actions


def load_rules():
    expression = "builtins.mapAttrs (_: v: v.publicKeys) (import ./secrets.nix)"
    output = subprocess.run(
        ["nix-instantiate", "--eval", "--strict", "--json", "-E", expression],
        cwd=secrets_dir, check=True, capture_output=True, text=True,
    ).stdout
    return json.loads(output)


def agenix_command():
    agenix = os.environ.get("AGENIX") or shutil.which("agenix")
    return [agenix] if agenix else ["nix", "run", f"{root}#agenix", "--"]


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--identity", type=Path, default=Path(
        os.environ.get("AGENIX_IDENTITY") or Path.home() / ".ssh/id_ed25519_agenix"))
    parser.add_argument("--all", action="store_true",
                        help="also rekey files whose recipients already match")
    parser.add_argument("--dry-run", action="store_true", help="only list the plan")
    args = parser.parse_args(argv)

    identity = args.identity.expanduser()
    public = Path(f"{identity}.pub")
    if not identity.is_file() or not public.is_file():
        print(f"Need both {identity} and {public}.", file=sys.stderr)
        return 2
    identity_tag = ssh_tag(public.read_text())
    if identity_tag is None:
        print(f"{public} is not an SSH public key.", file=sys.stderr)
        return 2

    actions = plan(load_rules(), identity_tag, args.all)
    failed = []
    for name, action in actions:
        if action != "rekey" or args.dry_run:
            print(f"{action:8} {name}")
            continue
        print(f"rekey    {name}", flush=True)
        result = subprocess.run(
            [*agenix_command(), "-e", name, "-i", str(identity)],
            cwd=secrets_dir, env={**os.environ, "EDITOR": ":"}, check=False,
        )
        if result.returncode != 0:
            failed.append(name)
        elif os.geteuid() == 0 and "SUDO_UID" in os.environ:
            os.chown(secrets_dir / name, int(os.environ["SUDO_UID"]), int(os.environ["SUDO_GID"]))

    counts = {a: sum(1 for _, b in actions if b == a) for a in ("rekey", "current", "skip", "missing")}
    print(f"\n{counts['rekey']} to rekey, {counts['current']} already current, "
          f"{counts['skip']} not openable with {identity.name}, {counts['missing']} not created"
          + (" (dry run)" if args.dry_run else ""))
    if counts["skip"]:
        print("Rekey the skipped files with a key that opens them (that device's key).")
    if failed:
        print("Failed: " + ", ".join(failed), file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
