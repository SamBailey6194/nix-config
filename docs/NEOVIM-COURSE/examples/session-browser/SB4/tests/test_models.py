"""The data types behave the way the rest of the app assumes."""

from dataclasses import FrozenInstanceError
from datetime import UTC, datetime
from pathlib import Path

import pytest

from session_browser.models import Session, Source

WHEN = datetime(2026, 9, 24, 9, 47, tzinfo=UTC)
SESSION = Session(
    source=Source.CLAUDE,
    id="4b1f6c2e",
    title="Parse the just dump JSON",
    cwd=Path("/tmp/nvim-course/nix-config/rust/just-panel"),
    updated=WHEN,
    path=Path("4b1f6c2e.jsonl"),
)


def test_key_is_unique_across_sources() -> None:
    codex = Session(Source.CODEX, SESSION.id, "Same id", None, WHEN, Path("x.jsonl"))

    assert SESSION.key == "claude:4b1f6c2e"
    assert codex.key != SESSION.key


def test_project_is_the_last_part_of_cwd() -> None:
    assert SESSION.project == "just-panel"


def test_project_is_empty_without_cwd() -> None:
    kitty = Session(Source.KITTY, "x.kitty-session", "x", None, WHEN, Path("x"))

    assert kitty.project == ""


def test_sessions_are_immutable() -> None:
    with pytest.raises(FrozenInstanceError):
        SESSION.title = "Renamed"  # pyright: ignore[reportAttributeAccessIssue]


def test_naive_datetime_is_rejected() -> None:
    with pytest.raises(ValueError, match="timezone"):
        Session(Source.KITTY, "x", "x", None, datetime(2026, 9, 24), Path("x"))
