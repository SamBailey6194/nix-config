"""Session sources: one module per tool that keeps its sessions on disk.

Claude Code and Codex both write JSON Lines: one JSON object per line, appended
as the conversation goes. Both formats are internal to their tools and change
between releases, so the helpers here are defensive. A line that does not
parse, or parses to something other than an object, is skipped rather than
allowed to hide the whole session.
"""

import json
import os
from datetime import UTC, datetime
from io import BufferedIOBase
from itertools import islice
from pathlib import Path
from typing import Any

type Entry = dict[str, Any]
"""One parsed line of a JSON Lines session file."""

HEAD_LINES = 30
"""Lines read from the top of a file: enough to reach the first `cwd`."""

TAIL_BYTES = 256 * 1024
"""Bytes read from the bottom of a file: enough to reach the latest title."""


def read_entries(file: BufferedIOBase) -> list[Entry]:
    """Parse the first HEAD_LINES lines and the last TAIL_BYTES of a file.

    Transcripts grow to megabytes, but the facts the list needs sit at the two
    ends: the working directory near the top, the latest title and timestamp
    near the bottom. On a real store of 168 transcripts (315 MB), parsing just
    the ends took 0.35 s against 1.5 s for every line, and the gap grows with
    your history. A file shorter than the two parts together is read once,
    whole.
    """
    lines = list(islice(file, HEAD_LINES))
    head_end = file.tell()
    size = file.seek(0, os.SEEK_END)
    start = max(head_end, size - TAIL_BYTES)
    file.seek(start)
    tail = file.read().splitlines()
    if start > head_end:
        # We jumped into the middle of the file, so the first "line" is almost
        # always the back half of a real one. Drop it: if the jump happened to
        # land on a line boundary, one whole line from the middle is lost,
        # which never matters for what the list shows.
        tail = tail[1:]
    return [entry for line in lines + tail if (entry := parse_line(line)) is not None]


def parse_line(line: bytes) -> Entry | None:
    """The line as a dict, or None if it is not a JSON object."""
    try:
        entry = json.loads(line)
    except ValueError:  # malformed JSON and invalid UTF-8 both end up here
        return None
    return entry if isinstance(entry, dict) else None


def parse_timestamp(value: object) -> datetime | None:
    """Parse an ISO 8601 time such as 2026-09-24T09:47:35.120Z, else None."""
    if not isinstance(value, str):
        return None
    try:
        when = datetime.fromisoformat(value)
    except ValueError:
        return None
    # Both tools write UTC with a trailing Z. A time without any offset would
    # be naive, which Session rejects, so read it as UTC too.
    return when if when.tzinfo else when.replace(tzinfo=UTC)


def modified(path: Path) -> datetime:
    """The file's modification time, as a timezone-aware datetime."""
    return datetime.fromtimestamp(path.stat().st_mtime, tz=UTC)


def one_line(text: str, width: int = 80) -> str:
    """Collapse all whitespace and cut to `width` characters, for titles."""
    text = " ".join(text.split())
    return text if len(text) <= width else text[: width - 1] + "…"
