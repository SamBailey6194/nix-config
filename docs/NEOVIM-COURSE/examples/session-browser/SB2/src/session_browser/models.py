"""Plain data types shared by the sources, the actions and the app."""

from dataclasses import dataclass
from datetime import datetime
from enum import StrEnum
from pathlib import Path
from typing import Literal


class Source(StrEnum):
    """The tool a session belongs to."""

    CLAUDE = "claude"
    CODEX = "codex"
    KITTY = "kitty"


@dataclass(frozen=True, slots=True)
class Session:
    """One row of the browser: what the list, the preview and the actions need."""

    source: Source
    id: str
    """The tool's own id: a Claude or Codex session UUID, or a Kitty file name."""
    title: str
    cwd: Path | None
    """The directory the session ran in, or None if the file does not say."""
    updated: datetime
    """Time of the last activity. Always timezone-aware, see `__post_init__`."""
    path: Path
    """The file the session was read from."""
    detail: str = ""
    """One extra line for the preview: a git branch, tab and window counts..."""

    def __post_init__(self) -> None:
        # Sessions from all three tools are sorted together by `updated`, and
        # Python refuses to compare a naive datetime with an aware one. Reject
        # a naive one here, where it is made, rather than in the middle of a
        # sort far away from the code that got it wrong.
        if self.updated.tzinfo is None:
            raise ValueError(f"{self.key}: 'updated' has no timezone")

    @property
    def key(self) -> str:
        """Unique across all three tools, so it can be the table's row key."""
        return f"{self.source}:{self.id}"

    @property
    def project(self) -> str:
        """The last part of the working directory: the name you know it by."""
        return self.cwd.name if self.cwd else ""


@dataclass(frozen=True, slots=True)
class Message:
    """One thing you or the assistant said, for the preview pane."""

    role: Literal["user", "assistant"]
    text: str
