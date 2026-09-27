"""A first draft of a Kitty session reader, to tidy up in lesson 11."""

import os
import sys
from pathlib import Path

SUFFIXES = ('.kitty-session', '.kitty_session', '.session')


def sessions_dir() -> Path:
    default = Path.home() / '.local' / 'share' / 'kitty' / 'sessions'
    return Path(os.environ.get('SESSION_BROWSER_KITTY_DIR') or default)


def count_windows(path: Path) -> int:
    lines = path.read_text(errors='replace').splitlines()
    return sum(1 for line in lines if line.startswith('launch') or line.startswith('new_os_window'))


def describe(path: Path) -> str:
    return path.stem + ': ' + count_windows(path) + ' windows'
