"""The Claude Code source, run against the synthetic transcripts in fixtures/."""

import json
from datetime import UTC, datetime
from pathlib import Path

import pytest

from session_browser.models import Message, Session, Source
from session_browser.sources import TAIL_BYTES, claude

JUST_PANEL = "4b1f6c2e-8d3a-4f7b-9c1e-2a5d7e9f0b13"
BROWSER = "9e7d2a41-3c6b-4e8f-a1d2-5b7c9e0f3a64"
NIX_CONFIG = "c2a8e5f0-6b4d-4a19-8e3c-7f1b2d4a6c85"
PROTOTYPE = "e5b3d7a9-1f2c-4d6e-b8a0-3c5e7f9b1d26"


@pytest.fixture
def sessions() -> dict[str, Session]:
    return {session.id: session for session in claude.load_sessions()}


def test_lists_main_transcripts_but_not_subagents(
    sessions: dict[str, Session],
) -> None:
    assert sorted(sessions) == sorted([JUST_PANEL, BROWSER, NIX_CONFIG, PROTOTYPE])
    assert all(session.source is Source.CLAUDE for session in sessions.values())


def test_title_is_the_last_ai_title(sessions: dict[str, Session]) -> None:
    assert sessions[JUST_PANEL].title == "Parse just's JSON dump with serde"


def test_title_falls_back_to_the_first_prompt_you_typed(
    sessions: dict[str, Session],
) -> None:
    assert sessions[BROWSER].title == (
        "How do I read a Claude Code transcript without parsing the whole file?"
    )


def test_cwd_is_where_the_session_started(sessions: dict[str, Session]) -> None:
    # This session later moved into python/session-browser.
    assert sessions[NIX_CONFIG].cwd == Path("/tmp/nvim-course/nix-config")
    assert sessions[NIX_CONFIG].project == "nix-config"


def test_malformed_line_does_not_hide_the_session(
    sessions: dict[str, Session],
) -> None:
    session = sessions[NIX_CONFIG]

    assert session.title == "Add a justfile recipe for the session-browser tests"
    assert session.updated == datetime(2026, 9, 26, 20, 5, 12, 904000, tzinfo=UTC)


def test_detail_names_the_git_branch(sessions: dict[str, Session]) -> None:
    assert sessions[JUST_PANEL].detail == "git branch main"
    assert sessions[PROTOTYPE].detail == ""


def test_recent_messages_are_what_was_said(sessions: dict[str, Session]) -> None:
    messages = claude.recent_messages(sessions[JUST_PANEL].path, limit=10)

    # The tool call and its result between the first two replies carry no text.
    assert [m.role for m in messages] == [
        "user",
        "assistant",
        "assistant",
        "user",
        "assistant",
    ]
    assert messages[0].text.startswith("Parse the output of `just --dump")
    assert messages[-1] == Message(
        "assistant",
        "Added `parses_star_parameters`, which checks that the `kind` of ARGS is "
        "`star`.",
    )


def test_recent_messages_keeps_only_the_last_few(
    sessions: dict[str, Session],
) -> None:
    messages = claude.recent_messages(sessions[JUST_PANEL].path, limit=2)

    assert [m.role for m in messages] == ["user", "assistant"]


def test_long_transcript_is_read_from_both_ends(tmp_path: Path) -> None:
    filler = {"type": "attachment", "attachment": {"type": "x" * 100}}
    lines = [
        {"type": "user", "cwd": "/tmp/nvim-course/big", "message": {"content": "Hi"}},
        *[filler] * 5000,
        {"type": "ai-title", "aiTitle": "Found at the bottom"},
        {"type": "system", "timestamp": "2026-09-27T08:00:00.000Z"},
    ]
    path = tmp_path / "projects" / "-tmp-nvim-course-big" / "big.jsonl"
    path.parent.mkdir(parents=True)
    path.write_text("".join(json.dumps(line) + "\n" for line in lines))
    assert path.stat().st_size > 2 * TAIL_BYTES

    [session] = claude.load_sessions(tmp_path)

    assert session.cwd == Path("/tmp/nvim-course/big")
    assert session.title == "Found at the bottom"
    assert session.updated == datetime(2026, 9, 27, 8, tzinfo=UTC)


def test_missing_store_has_no_sessions(tmp_path: Path) -> None:
    assert claude.load_sessions(tmp_path / "nowhere") == []


def test_config_dir_defaults_to_dot_claude_in_home(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv("CLAUDE_CONFIG_DIR")

    assert claude.config_dir() == tmp_path / ".claude"
