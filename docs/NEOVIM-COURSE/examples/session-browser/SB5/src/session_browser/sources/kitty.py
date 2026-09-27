"""Kitty session files, read from ~/.local/share/kitty/sessions.

A session file is a plain-text list of commands (layout, cd, new_tab, launch,
...) that `kitty --session <file>` replays to build tabs and windows. The
browser lists the files in one directory. It does not ask running kitty
instances what they have open: that needs remote control, which is off here.
"""

import os
from pathlib import Path

from session_browser.models import Session, Source
from session_browser.sources import modified

SUFFIXES = (".kitty-session", ".kitty_session", ".session")
"""The extensions kitty itself looks for when it scans a directory."""


def sessions_dir() -> Path:
    """SESSION_BROWSER_KITTY_DIR, else the directory kitty's own docs use."""
    default = Path.home() / ".local" / "share" / "kitty" / "sessions"
    return Path(os.environ.get("SESSION_BROWSER_KITTY_DIR") or default)


def load_sessions(directory: Path | None = None) -> list[Session]:
    """One Session per session file in `directory` (default: sessions_dir())."""
    directory = Path(os.path.expanduser(directory or sessions_dir()))  # see _resolve
    sessions = []
    for path in sorted(directory.glob("*")):
        if not path.name.endswith(SUFFIXES):
            continue
        try:
            sessions.append(read_session(path))
        except OSError:  # a directory with a session-like name, or unreadable
            continue
    return sessions


def read_session(path: Path) -> Session:
    """Build a Session from a session file: its name, first cd and a summary."""
    cwd: Path | None = None
    tabs = windows = 0
    in_tab = False
    for line in path.read_text(errors="replace").splitlines():
        # Split the way kitty does: a keyword, then the rest of the line after
        # the first spaces or tabs.
        words = line.split(maxsplit=1)
        keyword = words[0] if words else ""
        argument = words[1].strip() if len(words) > 1 else ""
        if keyword == "cd" and argument and cwd is None:
            cwd = _resolve(argument, path.parent)
        elif keyword == "new_tab":
            tabs, in_tab = tabs + 1, True
        elif keyword == "new_os_window":
            in_tab = False
        elif keyword == "launch":
            # A window launched before any new_tab opens the first tab itself.
            if not in_tab:
                tabs, in_tab = tabs + 1, True
            windows += 1

    return Session(
        source=Source.KITTY,
        id=path.name,
        title=path.stem,
        cwd=cwd,
        updated=modified(path),
        path=path,
        detail=f"{_count(tabs, 'tab')}, {_count(windows, 'window')}",
    )


def _resolve(argument: str, base: Path) -> Path:
    """Read a cd argument the way kitty does: ~ and $VARS expanded, and a
    relative path taken from the session file's own directory."""
    # os.path.expanduser, as kitty uses, leaves a ~user that does not exist on
    # this machine as it is. Path.expanduser would raise RuntimeError instead.
    path = Path(os.path.expanduser(os.path.expandvars(argument)))
    return path if path.is_absolute() else base / path


def _count(number: int, noun: str) -> str:
    return f"{number} {noun}" if number == 1 else f"{number} {noun}s"
