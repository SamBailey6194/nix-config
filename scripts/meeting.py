#!/usr/bin/env python3
"""Interactive front end for meeting-notes, used by the justfile:

  just meeting          ask for the details, then record (Ctrl+C to finish)
  just meeting-stop     stop the recording from another terminal
  just meeting-notes    pick a recording, confirm details, transcribe and write notes
  just dnd              ask for campaign, session and players, then record the room

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


def host_config(exe):
    return json.loads(subprocess.run([exe, "config"], capture_output=True, text=True, check=True).stdout)


def ask_mode(cfg, default):
    """room or call, offering call only where this host has call outputs."""
    if not cfg["outputs"]:
        return "room"
    return ask_choice("Audio: call = mic + call audio, room = one mic hears everyone",
                      ["call", "room"], default if default in ("call", "room") else cfg["defaultMode"])


def ask_output(cfg):
    if len(cfg["outputs"]) < 2:
        return "auto"
    return ask_choice("Call audio: auto = every output", ["auto", *cfg["outputs"]], "auto")


def start():
    exe = meeting_notes()
    cfg = host_config(exe)
    print("New meeting recording. n/a skips a question.\n")
    title = ask_text("Title", "Meeting") or "Meeting"
    mode = ask_mode(cfg, cfg["defaultMode"])
    if mode == "room":
        attendees = ask_text("Everyone present, comma-separated (you included)")
    else:
        attendees = ask_text("Remote attendees, comma-separated (not you)")
    cmd = [exe, "record", "--title", title, "--mode", mode]
    if mode == "call":
        cmd += ["--output", ask_output(cfg)]
    process = ask_yes("Write the notes as soon as the recording stops?")
    if process:
        cmd[1] = "run"
    if attendees:
        cmd += ["--attendees", attendees]
    print("\nStop with Ctrl+C here, or `just meeting-stop` from another terminal.\n")
    os.execv(exe, cmd)


def dnd():
    exe = meeting_notes()
    campaigns = json.loads(subprocess.run([exe, "campaigns", "--json"],
                                          capture_output=True, text=True, check=True).stdout)
    print("New D&D session recording. n/a skips a question.\n")
    if campaigns:
        print("Campaigns (most recent last):")
        for i, c in enumerate(campaigns, 1):
            print(f"  {i}. {c['name']}  ({c['sessions']} sessions)")
        print()
    last = campaigns[-1]["name"] if campaigns else None
    answer = ask_text("Campaign (number or name)", last)
    if not answer:
        sys.exit("a campaign name is needed")
    if answer.isdigit() and 1 <= int(answer) <= len(campaigns):
        answer = campaigns[int(answer) - 1]["name"]
    known = next((c for c in campaigns if c["name"].casefold() == answer.casefold()), None)
    campaign = known["name"] if known else answer

    cfg = host_config(exe)
    title = ask_text("Session title", f"Session {(known or {}).get('sessions', 0) + 1}")
    mode = ask_mode(cfg, (known or {}).get("mode", cfg["defaultMode"]))
    print('Everyone at the table, you included, as "Player (Character)" and "Name (DM)".')
    saved = ", ".join((known or {}).get("attendees", []))
    players = ask_text("Players", saved or None)
    cmd = [exe, "record", "--kind", "dnd", "--campaign", campaign,
           "--mode", mode, "--title", title or "Session"]
    if mode == "call":
        # Online: the recorder is the mic track, everyone else the call audio
        listed = [p.strip() for p in (players or "").split(",") if p.strip()]
        dm = next((p for p in listed if "(dm)" in p.casefold()), None)
        me = ask_text("Which of them are you (your mic track)?", dm or cfg["selfName"])
        if me:
            cmd += ["--me", me]
        cmd += ["--output", ask_output(cfg)]
    process = ask_yes("Write the DM notes and recap as soon as the recording stops?", False)
    if process:
        cmd[1] = "run"
    if players:
        cmd += ["--attendees", players]
    print("\nStop with Ctrl+C here, or `just meeting-stop` from another terminal.")
    print("Suspend and lid-close suspend are blocked while recording; keep the lid open "
          "so the microphone is not muffled.\n")
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
        title = f"{r['campaign']}: {r['title']}" if r.get("campaign") else r["title"]
        print(f"  {i}. {r['started'][:16].replace('T', ' ')}  {title}{done}")
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
    who = "Remote attendees" if rec.get("mode", "call") == "call" else "Everyone present"
    answer = ask(f"{who} (Enter keeps the saved list, n/a for none)", saved or None)
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
    what = "the DM notes and players' recap" if rec.get("kind") == "dnd" else "notes and action points"
    if not ask_yes(f"Write {what} (no = transcript only)?"):
        cmd.append("--no-summary")
    if rec["notes"] and ask_yes("Notes exist already: transcribe and label again from scratch?", False):
        cmd.append("--redo")

    print()
    os.execv(exe, cmd)


if __name__ == "__main__":
    actions = {"start": start, "dnd": dnd, "stop": stop, "notes": notes}
    if len(sys.argv) != 2 or sys.argv[1] not in actions:
        sys.exit(f"usage: {sys.argv[0]} {{{'|'.join(actions)}}}")
    actions[sys.argv[1]]()
