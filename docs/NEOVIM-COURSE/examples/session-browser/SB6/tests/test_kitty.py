"""The Kitty source, run against the synthetic session files in fixtures/."""

import os
from datetime import UTC, datetime
from pathlib import Path

import pytest

from session_browser.models import Session, Source
from session_browser.sources import kitty


@pytest.fixture
def sessions() -> dict[str, Session]:
    return {session.title: session for session in kitty.load_sessions()}


def test_lists_session_files_by_name(sessions: dict[str, Session]) -> None:
    assert sorted(sessions) == ["just-panel", "session-browser"]
    assert all(session.source is Source.KITTY for session in sessions.values())


def test_cwd_is_the_first_cd(sessions: dict[str, Session]) -> None:
    assert sessions["just-panel"].cwd == Path(
        "/tmp/nvim-course/nix-config/rust/just-panel"
    )


def test_detail_counts_tabs_and_windows(sessions: dict[str, Session]) -> None:
    # just-panel launches three windows before its first new_tab: that is a tab.
    assert sessions["just-panel"].detail == "2 tabs, 4 windows"
    assert sessions["session-browser"].detail == "1 tab, 3 windows"


def test_updated_is_the_file_modification_time(
    sessions: dict[str, Session],
) -> None:
    session = sessions["session-browser"]
    mtime = os.stat(session.path).st_mtime

    # Compare datetimes, not floats: a datetime keeps whole microseconds and the
    # file system nanoseconds, so .timestamp() is often a little off st_mtime.
    assert session.updated == datetime.fromtimestamp(mtime, tz=UTC)


def test_relative_cd_is_read_from_the_file_directory(tmp_path: Path) -> None:
    (tmp_path / "work.kitty-session").write_text("cd src\nlaunch\n")
    (tmp_path / "home.session").write_text("cd ~/notes\nlaunch\n")
    (tmp_path / "notes.txt").write_text("cd /not/a/session\n")

    sessions = {s.title: s for s in kitty.load_sessions(tmp_path)}

    assert sorted(sessions) == ["home", "work"]
    assert sessions["work"].cwd == tmp_path / "src"
    assert sessions["home"].cwd == tmp_path / "notes"  # HOME is tmp_path in tests


def test_lines_are_split_the_way_kitty_splits_them(tmp_path: Path) -> None:
    # A tab after the keyword, and a user who does not exist on this machine.
    (tmp_path / "tabbed.kitty-session").write_text("cd\t/tmp/work\nlaunch\tzsh\n")
    (tmp_path / "shared.kitty-session").write_text("cd ~nobody-here/work\nlaunch\n")

    sessions = {s.title: s for s in kitty.load_sessions(tmp_path)}

    assert sessions["tabbed"].cwd == Path("/tmp/work")
    assert sessions["tabbed"].detail == "1 tab, 1 window"
    # Left as it is, like kitty does, so it is relative to the file's folder.
    assert sessions["shared"].cwd == tmp_path / "~nobody-here" / "work"


def test_sessions_dir_defaults_to_kittys_own(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    monkeypatch.delenv("SESSION_BROWSER_KITTY_DIR")

    assert kitty.sessions_dir() == tmp_path / ".local/share/kitty/sessions"
