"""Turn a session into the command that resumes or opens it."""

import os
import shlex
import signal
import subprocess
import threading
from collections.abc import Callable
from dataclasses import dataclass, field
from pathlib import Path

from session_browser.models import Session, Source


@dataclass(frozen=True, slots=True)
class Launch:
    """A command to run for a session, and how to run it."""

    argv: tuple[str, ...]
    cwd: Path
    env: dict[str, str] = field(default_factory=dict)
    """Variables to set on top of the browser's own environment."""
    detach: bool = False
    """Start it alongside the browser instead of handing it the terminal."""

    def shell_command(self) -> str:
        """The same command as one line to paste into a shell."""
        assignments = [
            f"{name}={shlex.quote(value)}" for name, value in self.env.items()
        ]
        command = " ".join([*assignments, shlex.join(self.argv)])
        return f"cd {shlex.quote(str(self.cwd))} && {command}"


type Launcher = Callable[[Launch], None]
"""Something that runs a Launch. The app's real one needs a real terminal."""


def build_launch(session: Session) -> Launch:
    """The command that resumes a Claude or Codex session or reopens a Kitty one."""
    # A session can outlive its folder (a deleted worktree, an experiment in
    # /tmp). Starting in the home directory beats not starting at all.
    cwd = session.cwd if session.cwd and session.cwd.is_dir() else Path.home()
    match session.source:
        case Source.CLAUDE:
            env = {"TMPDIR": str(claude_tmpdir())}
            return Launch(("claude", "--resume", session.id), cwd, env)
        case Source.CODEX:
            # Run from the session's own folder: started anywhere else, Codex
            # stops to ask which directory the resumed session should use.
            return Launch(("codex", "resume", session.id), cwd)
        case Source.KITTY:
            # kitty opens its own window, so the browser can keep running.
            path = str(session.path.resolve())
            return Launch(("kitty", "--session", path), cwd, detach=True)


def claude_tmpdir() -> Path:
    """The TMPDIR your `claude` alias sets, created if it is missing.

    On NixOS, home/modules/shell.nix aliases `claude` to
    `TMPDIR=$HOME/.claude/tmp claude`. Aliases only exist inside an
    interactive shell, and subprocess starts `claude` directly, with no shell
    in between, so the alias never runs: the browser has to set TMPDIR
    itself. Nothing in the NixOS config creates the directory either.
    """
    path = Path.home() / ".claude" / "tmp"
    path.mkdir(parents=True, exist_ok=True)
    return path


def run(launch: Launch) -> int | None:
    """Run the command. Wait for it to exit and return its exit status, or,
    if it is detached, return None straight away.

    Raises FileNotFoundError when the program is not installed, and another
    OSError when it cannot be started at all.
    """
    env = {**os.environ, **launch.env}
    if launch.detach:
        # A session of its own, with no link to this terminal: quitting the
        # browser, or Ctrl+C in its terminal, must not close the new window.
        process = subprocess.Popen(
            launch.argv,
            cwd=launch.cwd,
            env=env,
            start_new_session=True,
            stdin=subprocess.DEVNULL,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        # Collect its exit status when it ends, or it lingers as a zombie
        # process for as long as the browser runs.
        threading.Thread(target=process.wait, daemon=True).start()
        return None
    # The program and the browser share the terminal, so Ctrl+C reaches both.
    # asyncio, which runs Textual, answers Ctrl+C by cancelling the app: the
    # browser would quit as soon as the program did. A handler that does
    # nothing keeps the browser out of it. The program still gets Ctrl+C as
    # usual, because starting a program resets handled signals to defaults.
    previous = signal.signal(signal.SIGINT, lambda signum, frame: None)
    try:
        completed = subprocess.run(launch.argv, cwd=launch.cwd, env=env, check=False)
    finally:
        signal.signal(signal.SIGINT, previous)
    return completed.returncode
