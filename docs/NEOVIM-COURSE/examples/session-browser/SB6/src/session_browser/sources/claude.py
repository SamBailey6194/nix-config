"""Claude Code sessions, read from ~/.claude/projects.

Each session is <config dir>/projects/<encoded cwd>/<session id>.jsonl. The
encoded cwd is the working directory with every character that is not a letter
or a digit replaced by "-". That is lossy (/, . and _ all become -), so the real
directory comes from the `cwd` field of the entries, never from the name.
"""

import os
import re
from pathlib import Path

from session_browser.models import Message, Session, Source
from session_browser.sources import (
    Entry,
    modified,
    one_line,
    parse_timestamp,
    read_entries,
)

INJECTED = re.compile(
    r"<(command-[\w-]+|local-command-[\w-]+|task-notification|pasted_content)>"
)
"""User entries Claude Code writes for you: slash commands and their output,
background task notices and pasted blocks. None of them is something you typed."""


def config_dir() -> Path:
    """Where Claude Code keeps its data.

    CLAUDE_CONFIG_DIR is Claude Code's own override. Honouring it keeps the
    browser reading the same store as `claude` itself, and lets the tests and
    the course tapes point both at synthetic fixtures.
    """
    return Path(os.environ.get("CLAUDE_CONFIG_DIR") or Path.home() / ".claude")


def load_sessions(root: Path | None = None) -> list[Session]:
    """One Session per main transcript under `root` (default: config_dir())."""
    projects = (root or config_dir()) / "projects"
    sessions = []
    # Sub-agent transcripts sit one level deeper, in <session>/subagents/, so
    # this pattern only ever matches the main sessions.
    for path in sorted(projects.glob("*/*.jsonl")):
        try:
            sessions.append(read_session(path))
        except OSError:  # deleted or unreadable since the glob listed it
            continue
    return sessions


def read_session(path: Path) -> Session:
    """Build a Session from one transcript, reading only its two ends."""
    with path.open("rb") as file:
        entries = read_entries(file)
    cwd = next((e["cwd"] for e in entries if isinstance(e.get("cwd"), str)), None)
    branch = next(
        (e["gitBranch"] for e in entries if isinstance(e.get("gitBranch"), str)), ""
    )
    # Claude Code re-appends its generated title as the conversation moves on,
    # so the last one is the current one.
    titles = [
        e["aiTitle"]
        for e in entries
        if e.get("type") == "ai-title" and isinstance(e.get("aiTitle"), str)
    ]
    prompts = [text for e in entries if (text := user_text(e))]
    times = [when for e in entries if (when := parse_timestamp(e.get("timestamp")))]

    if titles:
        title = titles[-1]
    elif prompts:
        title = prompts[0]
    else:
        title = "(untitled)"

    return Session(
        source=Source.CLAUDE,
        id=path.stem,  # the file name is the session id
        title=one_line(title),
        cwd=Path(cwd) if cwd else None,
        updated=max(times) if times else modified(path),
        path=path,
        detail=f"git branch {branch}" if branch else "",
    )


def recent_messages(path: Path, limit: int = 6) -> list[Message]:
    """The last `limit` prompts and replies of a transcript, oldest first."""
    with path.open("rb") as file:
        entries = read_entries(file)
    messages = []
    for entry in entries:
        if text := user_text(entry):
            messages.append(Message("user", text))
        elif text := assistant_text(entry):
            messages.append(Message("assistant", text))
    return messages[-limit:]


def user_text(entry: Entry) -> str:
    """What you typed in this entry, or "" if it is not a prompt of yours."""
    if entry.get("type") != "user" or entry.get("isMeta"):
        return ""
    text = _message_text(entry)
    return "" if INJECTED.match(text) else text


def assistant_text(entry: Entry) -> str:
    """What Claude wrote in this entry; "" for tool calls and thinking."""
    return _message_text(entry) if entry.get("type") == "assistant" else ""


def _message_text(entry: Entry) -> str:
    """The text blocks of an entry's message, joined. Tool results have none."""
    message = entry.get("message")
    content = message.get("content") if isinstance(message, dict) else None
    if isinstance(content, list):
        content = "\n".join(
            block["text"]
            for block in content
            if isinstance(block, dict)
            and block.get("type") == "text"
            and isinstance(block.get("text"), str)
        )
    return content.strip() if isinstance(content, str) else ""
