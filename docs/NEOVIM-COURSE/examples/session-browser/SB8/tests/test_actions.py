"""Building and running the commands that resume sessions."""

import signal
import time
from datetime import UTC, datetime
from pathlib import Path

import pytest

from session_browser.actions import Launch, build_launch, run
from session_browser.models import Session, Source

WHEN = datetime(2026, 9, 24, 9, 47, tzinfo=UTC)


def make_session(source: Source, cwd: Path | None, path: str = "s.jsonl") -> Session:
    return Session(source, "abc-123", "A title", cwd, WHEN, Path(path))


def test_claude_resumes_by_id_in_the_session_folder(tmp_path: Path) -> None:
    launch = build_launch(make_session(Source.CLAUDE, tmp_path))

    assert launch.argv == ("claude", "--resume", "abc-123")
    assert launch.cwd == tmp_path
    assert not launch.detach


def test_claude_gets_the_alias_tmpdir_and_it_exists(tmp_path: Path) -> None:
    launch = build_launch(make_session(Source.CLAUDE, tmp_path))

    tmpdir = tmp_path / ".claude" / "tmp"  # HOME is tmp_path in tests
    assert launch.env == {"TMPDIR": str(tmpdir)}
    assert tmpdir.is_dir()


def test_codex_resumes_by_id_in_the_session_folder(tmp_path: Path) -> None:
    launch = build_launch(make_session(Source.CODEX, tmp_path))

    assert launch == Launch(("codex", "resume", "abc-123"), tmp_path)


def test_kitty_opens_the_session_file_detached(tmp_path: Path) -> None:
    file = tmp_path / "work.kitty-session"

    launch = build_launch(make_session(Source.KITTY, tmp_path, str(file)))

    assert launch.argv == ("kitty", "--session", str(file))
    assert launch.detach


def test_missing_folder_falls_back_to_home(tmp_path: Path) -> None:
    launch = build_launch(make_session(Source.CODEX, tmp_path / "gone"))

    assert launch.cwd == tmp_path  # HOME


def test_shell_command_quotes_what_needs_quoting() -> None:
    launch = Launch(
        ("claude", "--resume", "abc-123"),
        Path("/tmp/my project"),
        {"TMPDIR": "/home/me/.claude/tmp"},
    )

    assert launch.shell_command() == (
        "cd '/tmp/my project' && TMPDIR=/home/me/.claude/tmp claude --resume abc-123"
    )


def test_run_waits_and_passes_cwd_and_env(tmp_path: Path) -> None:
    run(
        Launch(("sh", "-c", 'echo "$GREETING" > out.txt'), tmp_path, {"GREETING": "hi"})
    )

    assert (tmp_path / "out.txt").read_text() == "hi\n"


def test_run_returns_the_exit_status(tmp_path: Path) -> None:
    assert run(Launch(("sh", "-c", "exit 3"), tmp_path)) == 3
    # A detached command has not finished yet, so there is no status to give.
    assert run(Launch(("sh", "-c", "exit 3"), tmp_path, detach=True)) is None


def test_run_detached_returns_straight_away(tmp_path: Path) -> None:
    started = time.monotonic()

    run(Launch(("sh", "-c", "touch started; sleep 2"), tmp_path, detach=True))

    assert time.monotonic() - started < 1
    while not (tmp_path / "started").exists():
        assert time.monotonic() - started < 5, "the detached command never ran"
        time.sleep(0.05)


def test_ctrl_c_during_a_command_does_not_reach_the_browser(tmp_path: Path) -> None:
    before = signal.getsignal(signal.SIGINT)

    # The command sends SIGINT to its parent, as Ctrl+C in a shared terminal
    # would. Without the guard in run(), pytest itself would be interrupted.
    run(Launch(("sh", "-c", "kill -INT $PPID"), tmp_path))

    assert signal.getsignal(signal.SIGINT) == before


def test_the_command_itself_still_gets_ctrl_c(tmp_path: Path) -> None:
    # If run() ignored SIGINT outright, the child would inherit that, survive
    # the signal and create the file.
    run(Launch(("sh", "-c", "kill -INT $$; touch survived"), tmp_path))

    assert not (tmp_path / "survived").exists()


def test_run_reports_a_missing_program(tmp_path: Path) -> None:
    with pytest.raises(FileNotFoundError):
        run(Launch(("no-such-program-for-the-course",), tmp_path))
