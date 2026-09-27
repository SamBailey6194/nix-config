"""Shared pytest fixtures."""

import os
import shutil
import time
from collections.abc import Iterator
from datetime import UTC, datetime
from pathlib import Path

import pytest

FIXTURES = Path(__file__).parent / "fixtures"

KITTY_MTIME = datetime(2026, 9, 20, 12, tzinfo=UTC).timestamp()


@pytest.fixture(autouse=True)
def synthetic_stores(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> None:
    """Point every test at the synthetic fixtures, never at your real sessions.

    HOME moves as well, so anything that falls back to ~/.claude finds an empty
    temporary directory instead of your history.
    """
    monkeypatch.setenv("HOME", str(tmp_path))
    monkeypatch.setenv("CLAUDE_CONFIG_DIR", str(FIXTURES / "claude"))
    monkeypatch.setenv("CODEX_HOME", str(FIXTURES / "codex"))
    monkeypatch.setenv("SESSION_BROWSER_KITTY_DIR", str(FIXTURES / "kitty"))


@pytest.fixture
def pinned_stores(tmp_path: Path, monkeypatch: pytest.MonkeyPatch) -> Iterator[Path]:
    """A copy of the fixtures that looks the same on every machine.

    A git checkout stamps the Kitty files with the time you cloned, and the app
    shows times in your timezone, so both are pinned: the Kitty files to noon on
    20 September 2026 and the clock to UTC. The copy lives inside HOME, so the
    preview shows its paths as ~/... wherever the repository is.
    """
    root = tmp_path / "stores"
    shutil.copytree(FIXTURES, root)
    for path in (root / "kitty").iterdir():
        os.utime(path, (KITTY_MTIME, KITTY_MTIME))
    monkeypatch.setenv("CLAUDE_CONFIG_DIR", str(root / "claude"))
    monkeypatch.setenv("CODEX_HOME", str(root / "codex"))
    monkeypatch.setenv("SESSION_BROWSER_KITTY_DIR", str(root / "kitty"))
    monkeypatch.setenv("TZ", "UTC")
    time.tzset()  # TZ is only read when asked to
    yield root
    monkeypatch.undo()
    time.tzset()
