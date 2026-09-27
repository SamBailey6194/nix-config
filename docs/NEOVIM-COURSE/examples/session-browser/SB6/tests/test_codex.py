"""The Codex source, run against the synthetic rollouts in fixtures/."""

import shutil
from datetime import UTC, datetime
from pathlib import Path

import pytest

from session_browser.models import Message, Session, Source
from session_browser.sources import codex

REVIEW = "019a2b3c-4d5e-7f60-8a1b-2c3d4e5f6a71"
CLIPPY = "019a3c4d-5e6f-7a81-9b2c-3d4e5f6a7b82"
UNNAMED = "019a4d5e-6f7a-7b92-8c3d-4e5f6a7b8c93"


@pytest.fixture
def sessions() -> dict[str, Session]:
    return {session.id: session for session in codex.load_sessions()}


def test_lists_your_threads_but_not_subagents(sessions: dict[str, Session]) -> None:
    assert sorted(sessions) == sorted([REVIEW, CLIPPY, UNNAMED])
    assert all(session.source is Source.CODEX for session in sessions.values())


def test_title_comes_from_the_index(sessions: dict[str, Session]) -> None:
    assert sessions[REVIEW].title == "Review the Codex source parser"


def test_title_falls_back_to_the_first_prompt(sessions: dict[str, Session]) -> None:
    title = sessions[UNNAMED].title

    # Not the <environment_context> message: Codex injects that one.
    assert title == "Explain what ~/.codex/session_index.jsonl is for."


def test_updated_is_the_last_activity_not_the_index_time(
    sessions: dict[str, Session],
) -> None:
    assert sessions[REVIEW].updated == datetime(
        2026, 9, 24, 10, 31, 9, 877000, tzinfo=UTC
    )


def test_cwd_and_branch_come_from_session_meta(sessions: dict[str, Session]) -> None:
    session = sessions[CLIPPY]

    assert session.cwd == Path("/tmp/nvim-course/nix-config/rust/just-panel")
    assert session.detail == "git branch main"


def test_recent_messages_are_what_was_said(sessions: dict[str, Session]) -> None:
    messages = codex.recent_messages(sessions[CLIPPY].path)

    assert messages == [
        Message(
            "user",
            "Run cargo clippy on just-panel and suggest fixes for the warnings.",
        ),
        Message(
            "assistant",
            "Two warnings: a needless borrow in app.rs and a redundant clone in "
            "dump.rs. Both are safe to fix.",
        ),
    ]


def test_missing_store_has_no_sessions(tmp_path: Path) -> None:
    assert codex.load_sessions(tmp_path / "nowhere") == []


def test_codex_home_defaults_to_dot_codex_in_home(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv("CODEX_HOME")

    assert codex.codex_home() == tmp_path / ".codex"


def test_reads_zstd_compressed_rollouts(
    sessions: dict[str, Session], tmp_path: Path
) -> None:
    zstd = pytest.importorskip("compression.zstd")  # Python 3.14 and later
    original = sessions[CLIPPY].path
    day = tmp_path / "sessions" / "2026" / "09" / "25"
    day.mkdir(parents=True)
    with zstd.open(day / f"{original.name}.zst", "wb") as file:
        file.write(original.read_bytes())
    shutil.copy(original.parents[4] / "session_index.jsonl", tmp_path)

    [session] = codex.load_sessions(tmp_path)

    assert session.title == "Suggest clippy fixes for just-panel"
    assert len(codex.recent_messages(session.path)) == 2


def test_damaged_zstd_rollout_is_skipped(tmp_path: Path) -> None:
    zstd = pytest.importorskip("compression.zstd")  # Python 3.14 and later
    day = tmp_path / "sessions" / "2026" / "09" / "25"
    day.mkdir(parents=True)
    whole = zstd.compress(b'{"type": "session_meta"}\n' * 100)
    (day / "rollout-2026-09-25T10-00-00-cut.jsonl.zst").write_bytes(whole[:20])
    (day / "rollout-2026-09-25T10-00-01-junk.jsonl.zst").write_bytes(b"not zstd")

    assert codex.load_sessions(tmp_path) == []
    with pytest.raises(OSError, match="damaged zstd file"):
        codex.recent_messages(day / "rollout-2026-09-25T10-00-01-junk.jsonl.zst")
