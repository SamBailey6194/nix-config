#!/usr/bin/env python3
"""Run a command with the dedicated TypeSafe key or shared agenix env value."""
import os
import shlex
import sys
from pathlib import Path


def load_key(text):
    for line in text.splitlines():
        name, separator, value = line.partition("=")
        if separator and name.strip() == "TYPESAFE_API_KEY":
            parts = shlex.split(value, comments=True)
            if len(parts) != 1 or not parts[0]:
                raise ValueError("TYPESAFE_API_KEY must contain one non-empty value")
            return parts[0]
    raise ValueError("TYPESAFE_API_KEY is missing from the shared secret")


def main():
    if len(sys.argv) < 2:
        sys.exit("Usage: with-typesafe <command> [arguments...]")
    environment = os.environ.copy()
    if not environment.get("TYPESAFE_API_KEY"):
        try:
            dedicated = Path("/run/agenix/typesafe-api-key")
            if dedicated.exists():
                key = dedicated.read_text().rstrip("\n")
                if not key or "\n" in key or "\r" in key or "\0" in key:
                    raise ValueError("Invalid dedicated TypeSafe key")
                environment["TYPESAFE_API_KEY"] = key
            else:
                environment["TYPESAFE_API_KEY"] = load_key(
                    Path("/run/agenix/claude-secrets").read_text()
                )
        except (OSError, ValueError):
            sys.exit("Set TYPESAFE_API_KEY or provision this device's encrypted TypeSafe key")
    os.execvpe(sys.argv[1], sys.argv[1:], environment)


if __name__ == "__main__":
    main()
