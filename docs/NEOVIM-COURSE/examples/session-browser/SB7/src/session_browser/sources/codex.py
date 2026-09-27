"""Codex sessions, read from ~/.codex/sessions.

Each thread is one rollout file, sessions/YYYY/MM/DD/rollout-<time>-<id>.jsonl,
whose first line is a `session_meta` entry describing it. The names Codex gives
threads live separately, in session_index.jsonl.
"""

import errno
import os
import sys
from io import BufferedIOBase, BytesIO
from pathlib import Path

from session_browser.models import Message, Session, Source
from session_browser.sources import (
    Entry,
    modified,
    one_line,
    parse_line,
    parse_timestamp,
    read_entries,
)

# Codex can compress rollouts older than a week (an experimental feature, off
# by default). Python 3.14 reads zstd with no extra dependency; older Pythons,
# and a 3.14 built without libzstd, simply skip the compressed files. The
# version check comes first so pyright, analysing for 3.12, does not flag an
# import that cannot exist there.
if sys.version_info >= (3, 14):
    try:
        from compression import zstd
    except ImportError:
        zstd = None
else:
    zstd = None

SUFFIXES = (".jsonl", ".jsonl.zst") if zstd else (".jsonl",)


def codex_home() -> Path:
    """Where Codex keeps its data: CODEX_HOME (Codex's own override) or ~/.codex."""
    return Path(os.environ.get("CODEX_HOME") or Path.home() / ".codex")


def load_sessions(root: Path | None = None) -> list[Session]:
    """One Session per thread you started under `root` (default: codex_home())."""
    root = root or codex_home()
    names = read_index(root / "session_index.jsonl")
    sessions = []
    for path in sorted((root / "sessions").glob("*/*/*/rollout-*")):
        if not path.name.endswith(SUFFIXES):
            continue
        try:
            session = read_session(path, names)
        except OSError:  # deleted or unreadable since the glob listed it
            continue
        if session is not None:
            sessions.append(session)
    return sessions


def read_index(path: Path) -> dict[str, str]:
    """Map thread id to the name Codex gave it. A later line wins."""
    try:
        lines = path.read_bytes().splitlines()
    except OSError:  # no threads named yet
        return {}
    names = {}
    for line in lines:
        entry = parse_line(line) or {}
        thread_id, name = entry.get("id"), entry.get("thread_name")
        if isinstance(thread_id, str) and isinstance(name, str) and name:
            names[thread_id] = name
    return names


def read_session(path: Path, names: dict[str, str]) -> Session | None:
    """Build a Session from one rollout, or None if it is not yours to resume."""
    with open_rollout(path) as file:
        entries = read_entries(file)
    meta = _session_meta(entries)
    # Sub-agent threads are ones Codex spawned for itself. They are missing
    # from session_index.jsonl too, and resuming one on its own makes no sense.
    if meta is None or meta.get("thread_source") == "subagent":
        return None
    thread_id, cwd, git = meta.get("id"), meta.get("cwd"), meta.get("git")
    if not isinstance(thread_id, str):
        return None
    branch = git.get("branch") if isinstance(git, dict) else None
    prompts = [text for e in entries if (text := user_text(e))]
    times = [when for e in entries if (when := parse_timestamp(e.get("timestamp")))]
    title = names.get(thread_id) or (prompts[0] if prompts else "(untitled)")

    return Session(
        source=Source.CODEX,
        id=thread_id,
        title=one_line(title),
        cwd=Path(cwd) if isinstance(cwd, str) else None,
        # Not the index's updated_at: that records when the thread was named,
        # which can be an hour before its last message.
        updated=max(times) if times else modified(path),
        path=path,
        detail=f"git branch {branch}" if isinstance(branch, str) and branch else "",
    )


def recent_messages(path: Path, limit: int = 6) -> list[Message]:
    """The last `limit` prompts and replies of a rollout, oldest first."""
    with open_rollout(path) as file:
        entries = read_entries(file)
    messages = []
    for entry in entries:
        if text := user_text(entry):
            messages.append(Message("user", text))
        elif text := assistant_text(entry):
            messages.append(Message("assistant", text))
    return messages[-limit:]


def open_rollout(path: Path) -> BufferedIOBase:
    """Open a rollout for reading, decompressing it if it ends in .zst."""
    if path.suffix != ".zst" or zstd is None:
        return path.open("rb")
    # Decompress it all at once. A damaged or half-written archive then fails
    # here, as the OSError every caller already handles for an unreadable
    # file, rather than halfway through reading it with a ZstdError that no
    # caller expects and that would crash the app.
    try:
        return BytesIO(zstd.decompress(path.read_bytes()))
    except zstd.ZstdError as error:
        raise OSError(errno.EIO, f"damaged zstd file ({error})") from error


def user_text(entry: Entry) -> str:
    """What you typed in this entry, or ""."""
    return _item_text(entry, "UserMessage")


def assistant_text(entry: Entry) -> str:
    """What Codex replied in this entry, or ""."""
    return _item_text(entry, "AgentMessage")


def _item_text(entry: Entry, item_type: str) -> str:
    """The text of a finished conversation item of the given type.

    The same words appear again as `response_item` messages, but those also
    carry context Codex injects (<environment_context>, developer notes), so
    only the `item_completed` events are read.
    """
    payload = entry.get("payload")
    if entry.get("type") != "event_msg" or not isinstance(payload, dict):
        return ""
    item = payload.get("item")
    if payload.get("type") != "item_completed" or not isinstance(item, dict):
        return ""
    content = item.get("content")
    if item.get("type") != item_type or not isinstance(content, list):
        return ""
    # User blocks are typed "text" and agent blocks "Text"; both hold `text`.
    return "\n".join(
        block["text"]
        for block in content
        if isinstance(block, dict) and isinstance(block.get("text"), str)
    ).strip()


def _session_meta(entries: list[Entry]) -> Entry | None:
    """The payload of the first line, which in a rollout is always session_meta."""
    if entries and entries[0].get("type") == "session_meta":
        payload = entries[0].get("payload")
        if isinstance(payload, dict):
            return payload
    return None
