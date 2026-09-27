"""Lesson 03 kata: operators and text objects.

Edit the COPY in /tmp/nvim-practice, never this file in the repo. You do not
need to save to practise: :q! throws your changes away. If you do save, ruff
reformats the file first (format on save), which can move things around.
"""

from dataclasses import dataclass, field
from pathlib import Path

SOURCES = ("claude", "codex", "kitty")

TITLES = [
    "Parse just's JSON dump with serde",
    "Review the Codex source parser",
    "Suggest clippy fixes for just-panel",
]

KEYS = {
    "j": ("cursor_down", "Down"),
    "k": ("cursor_up", "Up"),
    "/": ("focus_search", "Search"),
    "q": ("quit", "Quit"),
}

PREVIEW = "<b>just-panel</b> and <i>session-browser</i>"

COMMANDS = [
    "rebuild",
    "check",
    "update",
]


@dataclass
class Filter:
    query: str | None
    source: str | None
    project: str | None


@dataclass
class Session:
    source: str
    id: str
    title: str
    cwd: Path | None = None
    tags: list[str] = field(default_factory=list)

    def label(self) -> str:
        return f"[{self.source}] {self.title} ({self.project()})"

    def project(self) -> str:
        return self.cwd.name if self.cwd else "unknown"

    def resume_command(self) -> list[str]:
        if self.source == "claude":
            return ["claude", "--resume", self.id]
        return ["codex", "resume", self.id]


def sort_for_display(sessions: list[Session]) -> list[Session]:
    return sorted(sessions, key=lambda s: (s.source, s.title))
