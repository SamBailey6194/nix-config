"""The app, driven through Pilot the way you would drive it with the keyboard."""

import json
from collections.abc import Iterator
from contextlib import contextmanager
from pathlib import Path

import pytest
from textual.coordinate import Coordinate
from textual.pilot import Pilot
from textual.widgets import Input, Static

from session_browser.actions import Launch
from session_browser.app import SessionBrowser, SessionTable

NEWEST = "claude:c2a8e5f0-6b4d-4a19-8e3c-7f1b2d4a6c85"
OLDEST = "claude:e5b3d7a9-1f2c-4d6e-b8a0-3c5e7f9b1d26"  # its folder does not exist

pytestmark = pytest.mark.usefixtures("pinned_stores")


async def wait_for_sessions(pilot: Pilot[None]) -> None:
    """Let the loading worker finish and the table fill."""
    await pilot.app.workers.wait_for_complete()
    await pilot.pause()


def row_keys(table: SessionTable) -> list[str]:
    return [
        table.coordinate_to_cell_key(Coordinate(row, 0)).row_key.value or ""
        for row in range(table.row_count)
    ]


def record_notifications(
    app: SessionBrowser, monkeypatch: pytest.MonkeyPatch
) -> list[tuple[str, str]]:
    """Swap app.notify for a recorder of (severity, message) pairs."""
    notes: list[tuple[str, str]] = []

    def notify(message: str, *, severity: str = "information", **_: object) -> None:
        notes.append((severity, message))

    monkeypatch.setattr(app, "notify", notify)
    return notes


def record_suspends(app: SessionBrowser, monkeypatch: pytest.MonkeyPatch) -> list[str]:
    """Swap app.suspend, which needs a real terminal, for a recorder that,
    like Textual 8.2.8's, only gets to "resume" if its block ends normally."""
    steps: list[str] = []

    @contextmanager
    def suspend() -> Iterator[None]:
        steps.append("suspend")
        yield
        steps.append("resume")

    monkeypatch.setattr(app, "suspend", suspend)
    return steps


def install_program(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch, name: str, content: bytes
) -> None:
    """Make an executable file called `name` the only program on PATH.

    Only: if the fake cannot run, subprocess goes on down PATH, and the tests
    must never start the real claude.
    """
    program = tmp_path / "bin" / name
    program.parent.mkdir(exist_ok=True)
    program.write_bytes(content)
    program.chmod(0o755)
    monkeypatch.setenv("PATH", str(program.parent))


async def test_lists_every_session_newest_first() -> None:
    app = SessionBrowser()
    async with app.run_test() as pilot:
        await wait_for_sessions(pilot)
        keys = row_keys(app.query_one(SessionTable))

        assert len(keys) == 9
        assert (keys[0], keys[-1]) == (NEWEST, OLDEST)
        assert app.sub_title == "9 of 9 sessions"


async def test_h_and_l_switch_the_source_tab() -> None:
    app = SessionBrowser()
    async with app.run_test() as pilot:
        await wait_for_sessions(pilot)
        table = app.query_one(SessionTable)
        counts = []
        for key in "llllh":
            await pilot.press(key)
            counts.append(table.row_count)

        # Claude, Codex, Kitty, round to All, back to Kitty.
        assert counts == [4, 3, 2, 9, 2]


async def test_search_matches_title_or_folder_ignoring_case() -> None:
    app = SessionBrowser()
    async with app.run_test() as pilot:
        await wait_for_sessions(pilot)
        await pilot.press("slash", *"PANEL")

        # A title, a title and folder, and a folder alone mention just-panel.
        assert app.query_one(Input).value == "PANEL"
        assert app.query_one(SessionTable).row_count == 3


async def test_escape_leaves_the_search_box() -> None:
    app = SessionBrowser()
    async with app.run_test() as pilot:
        await wait_for_sessions(pilot)
        await pilot.press("slash", "q")

        # In the search box q is just a letter: the app is still running.
        assert isinstance(app.focused, Input)
        assert app.is_running

        await pilot.press("escape")

        assert isinstance(app.focused, SessionTable)


async def test_enter_in_the_search_box_goes_to_the_list() -> None:
    launches: list[Launch] = []
    app = SessionBrowser(launcher=launches.append)
    async with app.run_test() as pilot:
        await wait_for_sessions(pilot)
        await pilot.press("slash", *"codex", "enter")

        assert isinstance(app.focused, SessionTable)
        assert launches == []


async def test_vim_keys_move_the_cursor() -> None:
    app = SessionBrowser()
    async with app.run_test() as pilot:
        await wait_for_sessions(pilot)
        table = app.query_one(SessionTable)
        rows = []
        for key in "jjkGg":
            await pilot.press(key)
            rows.append(table.cursor_row)

        assert rows == [1, 2, 1, 8, 0]


async def test_enter_resumes_claude_with_its_tmpdir(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    launches: list[Launch] = []
    app = SessionBrowser(launcher=launches.append)
    notes = record_notifications(app, monkeypatch)
    async with app.run_test() as pilot:
        await wait_for_sessions(pilot)
        await pilot.press("G", "enter")

    [launch] = launches
    assert launch.argv == ("claude", "--resume", OLDEST.removeprefix("claude:"))
    assert launch.env == {"TMPDIR": str(tmp_path / ".claude" / "tmp")}
    # The session's folder is gone, so it starts in HOME and says so.
    assert launch.cwd == tmp_path
    assert [severity for severity, _ in notes] == ["warning"]


async def test_enter_resumes_codex() -> None:
    launches: list[Launch] = []
    app = SessionBrowser(launcher=launches.append)
    async with app.run_test() as pilot:
        await wait_for_sessions(pilot)
        await pilot.press("l", "l", "enter")

    [launch] = launches
    assert launch.argv == ("codex", "resume", "019a4d5e-6f7a-7b92-8c3d-4e5f6a7b8c93")
    assert launch.env == {}
    assert not launch.detach


async def test_enter_opens_kitty_sessions_detached(pinned_stores: Path) -> None:
    launches: list[Launch] = []
    app = SessionBrowser(launcher=launches.append)
    async with app.run_test() as pilot:
        await wait_for_sessions(pilot)
        await pilot.press("h", "enter")

    [launch] = launches
    session_file = pinned_stores / "kitty" / "just-panel.kitty-session"
    assert launch.argv == ("kitty", "--session", str(session_file))
    assert launch.detach


async def test_missing_program_is_reported(monkeypatch: pytest.MonkeyPatch) -> None:
    def not_installed(launch: Launch) -> None:
        raise FileNotFoundError(launch.argv[0])

    app = SessionBrowser(launcher=not_installed)
    notes = record_notifications(app, monkeypatch)
    async with app.run_test() as pilot:
        await wait_for_sessions(pilot)
        await pilot.press("enter")

        assert app.is_running
        assert notes[-1] == (
            "error",
            "Could not find 'claude'. Is it installed and on PATH?",
        )


async def test_a_program_that_cannot_start_gives_the_terminal_back(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    # On PATH and executable, but not something the kernel can run.
    install_program(tmp_path, monkeypatch, "claude", b"\x00 not a program")
    app = SessionBrowser()
    steps = record_suspends(app, monkeypatch)
    notes = record_notifications(app, monkeypatch)
    async with app.run_test() as pilot:
        await wait_for_sessions(pilot)
        await pilot.press("enter")

        assert steps == ["suspend", "resume"]
        assert notes[-1] == ("error", "Could not start 'claude': Exec format error.")
        assert app.is_running


async def test_a_program_that_fails_is_reported(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    install_program(tmp_path, monkeypatch, "claude", b"#!/bin/sh\nexit 3\n")
    app = SessionBrowser()
    steps = record_suspends(app, monkeypatch)
    notes = record_notifications(app, monkeypatch)
    async with app.run_test() as pilot:
        await wait_for_sessions(pilot)
        await pilot.press("enter")

        assert steps == ["suspend", "resume"]
        assert notes[-1] == (
            "warning",
            "claude exited with status 3. Quit the browser to read what it printed.",
        )


async def test_moving_in_an_empty_list_is_harmless() -> None:
    launches: list[Launch] = []
    app = SessionBrowser(launcher=launches.append)
    async with app.run_test() as pilot:
        await wait_for_sessions(pilot)
        await pilot.press("slash", *"nosuchsession", "escape")
        await pilot.press("k", "up", "G", "pagedown", "enter", "c")

        assert app.query_one(SessionTable).row_count == 0
        assert launches == []
        assert app.is_running


async def test_c_copies_the_resume_command(tmp_path: Path) -> None:
    app = SessionBrowser()
    async with app.run_test() as pilot:
        await wait_for_sessions(pilot)
        await pilot.press("G", "c")

        # The session's folder is gone, hence the cd to HOME.
        assert app.clipboard == (
            f"cd {tmp_path} && TMPDIR={tmp_path}/.claude/tmp "
            f"claude --resume {OLDEST.removeprefix('claude:')}"
        )


async def test_preview_shows_brackets_as_text() -> None:
    app = SessionBrowser()
    async with app.run_test() as pilot:
        await wait_for_sessions(pilot)
        await pilot.press("G")
        preview = str(app.query_one("#preview", Static).render())

        assert preview.startswith("Why [/bold] crashes Static")
        assert "text such as [session titles] must be escaped" in preview


async def test_escape_sequences_are_shown_not_sent(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
) -> None:
    # OSC 52: a terminal that allows it would put "hi" on your clipboard.
    osc52 = "\x1b]52;c;aGk=\x1b\\"
    entry = {"type": "ai-title", "aiTitle": f"Paste {osc52}"}
    store = tmp_path / "escape"
    transcript = store / "projects" / "-tmp-x" / "0e5c.jsonl"
    transcript.parent.mkdir(parents=True)
    transcript.write_text(json.dumps(entry) + "\n")
    monkeypatch.setenv("CLAUDE_CONFIG_DIR", str(store))  # its only Claude session
    app = SessionBrowser()
    async with app.run_test() as pilot:
        await wait_for_sessions(pilot)
        await pilot.press("l")  # the Claude tab
        title = str(app.query_one(SessionTable).get_row_at(0)[1])
        preview = str(app.query_one("#preview", Static).render())

        replaced = "\N{REPLACEMENT CHARACTER}"
        assert title == f"Paste {replaced}]52;c;aGk={replaced}\\"
        assert preview.startswith(title)
