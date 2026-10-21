#!/usr/bin/env python3
"""Interactive front end for meeting-notes, used by the justfile:

  just meeting          ask for the details, then record (Ctrl+C to finish)
  just meeting-stop     stop the recording from another terminal
  just meeting-notes    pick a recording, confirm details, transcribe and write notes

Answer `n`, `n/a` or `none` (or press Enter where a default is shown) to skip
a question. See docs/MEETING-NOTES.md.
"""

import json
import os
import shutil
import subprocess
import sys

SKIP = {"", "n", "no", "n/a", "na", "none", "-"}


def ask(question, default=None):
    hint = f" [{default}]" if default else ""
    try:
        answer = input(f"{question}{hint}: ").strip()
    except (EOFError, KeyboardInterrupt):
        # Backing out before anything starts is not a failure for `just`
        print("\nCancelled.")
        sys.exit(0)
    return answer


def ask_text(question, default=None):
    """Free text; a skip word returns None (or the default on plain Enter)."""
    answer = ask(question, default)
    if answer == "" and default:
        return default
    return None if answer.lower() in SKIP else answer


def ask_yes(question, default=True):
    answer = ask(question, "Y/n" if default else "y/N").lower()
    if answer == "":
        return default
    return answer in {"y", "yes"}


def ask_choice(question, choices, default):
    while True:
        answer = ask(f"{question} ({'/'.join(choices)})", default).lower() or default
        if answer in choices:
            return answer
        print(f"  choose one of: {', '.join(choices)}")


def meeting_notes():
    exe = shutil.which("meeting-notes")
    if not exe:
        sys.exit("meeting-notes is not installed on this host (software.meetingNotes)")
    return exe


def start():
    exe = meeting_notes()
    print("New meeting recording. n/a skips a question.\n")
    title = ask_text("Title", "Meeting") or "Meeting"
    attendees = ask_text("Remote attendees, comma-separated (not you)")
    output = ask_choice("Call audio: auto = headphones and speakers", ["auto", "chat", "hdmi"], "auto")
    process = ask_yes("Write the notes as soon as the recording stops?")

    cmd = [exe, "run" if process else "record", "--title", title, "--output", output]
    if attendees:
        cmd += ["--attendees", attendees]
    print("\nStop with Ctrl+C here, or `just meeting-stop` from another terminal.\n")
    os.execv(exe, cmd)


def stop():
    os.execv(meeting_notes(), [meeting_notes(), "stop"])


def notes():
    exe = meeting_notes()
    rows = json.loads(subprocess.run([exe, "list", "--json", "--limit", "8"],
                                     capture_output=True, text=True, check=True).stdout)
    if not rows:
        sys.exit("no finished recordings yet: start one with `just meeting`")

    print("Recent recordings (newest last):\n")
    for i, r in enumerate(rows, 1):
        done = "  [notes]" if r["notes"] else ""
        print(f"  {i}. {r['started'][:16].replace('T', ' ')}  {r['title']}{done}")
    print()
    while True:
        pick = ask("Which recording", str(len(rows)))
        pick = pick or str(len(rows))
        if pick.isdigit() and 1 <= int(pick) <= len(rows):
            rec = rows[int(pick) - 1]
            break
        print(f"  enter 1-{len(rows)}")

    saved = ", ".join(rec["attendees"])
    cmd = [exe, "process", rec["dir"]]
    answer = ask("Remote attendees (Enter keeps the saved list, n/a for none)", saved or None)
    if answer and answer.lower() in SKIP:
        cmd += ["--attendees", ""]
    elif answer and answer != saved:
        cmd += ["--attendees", answer]

    speakers = ask_text("Speaker names if you already know them, e.g. 00=Jane, 01=Tom "
                        "(n/a: suggest and confirm after transcribing)")
    if speakers:
        cmd += ["--speakers", speakers]

    summariser = ask_choice("Notes written by", ["claude", "local"], "claude")
    cmd += ["--summariser", summariser]
    if not ask_yes("Write notes and action points (no = transcript only)?"):
        cmd.append("--no-summary")
    if rec["notes"] and ask_yes("Notes exist already: transcribe and label again from scratch?", False):
        cmd.append("--redo")

    print()
    os.execv(exe, cmd)


if __name__ == "__main__":
    actions = {"start": start, "stop": stop, "notes": notes}
    if len(sys.argv) != 2 or sys.argv[1] not in actions:
        sys.exit(f"usage: {sys.argv[0]} {{{'|'.join(actions)}}}")
    actions[sys.argv[1]]()
