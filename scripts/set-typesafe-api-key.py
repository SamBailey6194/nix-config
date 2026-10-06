#!/usr/bin/env python3
"""Prompt once and encrypt a TypeSafe key separately for both devices.

Requires age and nix. Encryption needs public recipients, not private keys.
Use --bundled to update the existing env files with a recovery identity.
Plaintext stays in memory; files staged on disk contain only age ciphertext.
"""
import argparse
import getpass
import json
import os
from pathlib import Path
import shlex
import subprocess
import tempfile
import sys


DEVICES = ("laptop-intel", "devtower-intel")


def replace_key(text, key):
    lines = [line for line in text.splitlines()
             if line.partition("=")[0].strip() != "TYPESAFE_API_KEY"]
    lines.append("TYPESAFE_API_KEY=" + shlex.quote(key))
    return "\n".join(lines) + "\n"


def run(command, **kwargs):
    result = subprocess.run(command, capture_output=True, **kwargs)
    if result.returncode:
        # Never forward subprocess output: it may contain secret material.
        raise RuntimeError(f"{command[0]} failed; check tools and decryption identity")
    return result.stdout


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--identity", type=Path,
                        default=Path.home() / ".ssh/id_ed25519_agenix")
    parser.add_argument("--bundled", action="store_true",
                        help="Update existing claude-secrets bundles; requires decryption")
    args = parser.parse_args()
    directory = Path(__file__).resolve().parents[1] / "secrets"

    try:
        prefix = "claude-secrets" if args.bundled else "typesafe-api-key"
        files = tuple(f"{prefix}-{device}.age" for device in DEVICES)
        # Bundled editing needs decryption; dedicated encryption does not.
        plaintext = {name: run(["age", "--decrypt", "--identity", str(args.identity),
                                str(directory / name)]).decode() for name in files} if args.bundled else {}
        recipients = {name: json.loads(run([
            "nix", "eval", "--json", "--file", str(directory / "secrets.nix"),
            "--apply", f's: s."{name}".publicKeys',
        ])) for name in files}
        key = getpass.getpass("Paste the TypeSafe/Jev API key (hidden): ")
        if not key or "\n" in key or "\r" in key or "\0" in key:
            raise ValueError("A non-empty, single-line API key is required")
        encrypted = {}
        for name in files:
            command = ["age", "--armor"]
            for recipient in recipients[name]:
                command.extend(["--recipient", recipient])
            text = replace_key(plaintext[name], key) if args.bundled else key + "\n"
            encrypted[name] = run(command, input=text.encode())

        # Prepare both ciphertexts before replacing either existing file.
        with tempfile.TemporaryDirectory(prefix=".typesafe-", dir=directory) as staging:
            for name in files:
                output = Path(staging) / name
                output.write_bytes(encrypted[name])
                original = directory / name
                output.chmod(original.stat().st_mode & 0o777 if original.exists() else 0o644)
            for name in files:
                os.replace(Path(staging) / name, directory / name)
    except (OSError, ValueError, RuntimeError, EOFError, KeyboardInterrupt):
        sys.exit("Key update failed. Check age/nix and recipient rules. Bundled editing also requires a recovery identity. No key was printed.")
    print("Saved the TypeSafe key encrypted for laptop-intel and devtower-intel.")


if __name__ == "__main__":
    main()
