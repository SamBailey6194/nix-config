#!/usr/bin/env python3
"""Claude PreToolUse guard: reject git commits and pushes that skip hooks.

Catches what settings.json deny globs cannot: --no-verify abbreviations,
-n inside short-flag clusters (git commit -an), and disabling hooks with
-c core.hooksPath=... This is a guardrail for direct commands, not a shell
security boundary.
"""
import json
import os
import re
import shlex
import sys

SEPARATORS = {"&&", "||", ";", "|", "|&", "&", "(", ")", "\n"}
# git options that take the following token as their value
GIT_VALUE_OPTIONS = {"-C", "-c", "--git-dir", "--work-tree", "--namespace", "--config-env"}
# git commit short options whose value is the rest of the cluster or the next token
COMMIT_VALUE_FLAGS = set("mFCct")
# git commit short options whose optional value is attached (-uno, -S<keyid>)
COMMIT_ATTACHED_FLAGS = set("uS")
HEREDOC = re.compile(r"<<-?\s*(['\"]?)(\w+)\1[^\n]*\n.*?^\s*\2\s*$", re.S | re.M)


def segments(command):
    lexer = shlex.shlex(HEREDOC.sub("", command), posix=True, punctuation_chars=";&|()")
    lexer.whitespace_split = True
    lexer.commenters = ""
    segment = []
    for token in lexer:
        if token in SEPARATORS:
            if segment:
                yield segment
            segment = []
        else:
            segment.append(token)
    if segment:
        yield segment


def skips_hooks(words):
    # Drop leading VAR=value assignments and simple wrappers.
    while words and (re.match(r"^\w+=", words[0]) or words[0] in {"env", "command", "nohup"}):
        words = words[1:]
    if not words or os.path.basename(words[0]) != "git":
        return False

    i = 1
    while i < len(words) and words[i].startswith("-"):
        option = words[i]
        name, _, value = option.partition("=")
        if name in GIT_VALUE_OPTIONS and not value and i + 1 < len(words):
            value = words[i + 1]
            i += 1
        if name in {"-c", "--config-env"} and "core.hookspath" in value.lower():
            return True
        i += 1
    if i >= len(words) or words[i] not in {"commit", "push"}:
        return False

    subcommand, args = words[i], words[i + 1:]
    skip_value = False
    for arg in args:
        if skip_value:
            skip_value = False
            continue
        if arg == "--":
            break
        # git accepts unambiguous long-option prefixes, e.g. --no-ver
        if arg.startswith("--no-v") and "--no-verify".startswith(arg.split("=")[0]):
            return True
        if subcommand == "commit" and re.match(r"^-[^-]", arg):
            for position, flag in enumerate(arg[1:], start=1):
                if flag == "n":
                    return True
                if flag in COMMIT_ATTACHED_FLAGS:
                    break
                if flag in COMMIT_VALUE_FLAGS:
                    skip_value = position == len(arg) - 1
                    break
        elif arg in {"--message", "--file", "--reuse-message", "--reedit-message",
                     "--template", "--author", "--date", "--cleanup", "--fixup",
                     "--squash", "--trailer", "--pathspec-from-file"}:
            skip_value = True
    return False


def violation(command):
    try:
        return any(skips_hooks(words) for words in segments(command))
    except ValueError:
        # Unbalanced quotes: fall back to a plain text check.
        return bool(re.search(r"--no-verify|core\.hookspath", command, re.I))


def main():
    payload = json.load(sys.stdin)
    command = payload.get("tool_input", {}).get("command", "")
    if violation(command):
        print("Git hooks must run: do not use --no-verify, -n or core.hooksPath "
              "with git commit/push. Fix the hook failure instead.", file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
