#!/usr/bin/env python3
"""Drive just-panel on a real pseudo-terminal and check that it behaves.

Usage, from docs/NEOVIM-COURSE/examples/just-panel (pyte renders the screen
so the checks can read it; uv fetches it on first use):

    uv run --no-project --with pyte python smoke.py BINARY SCENARIO [JUSTFILE]

BINARY is a just-panel that cargo built: smoke-all.sh builds the worked
examples, or point it at your own build, for example
rust/target/debug/just-panel. SCENARIO is one of the names in SCENARIOS at
the bottom. JUSTFILE defaults to the course's demo justfile,
../../fixtures/just/justfile, whose recipes only echo, sleep or print the
time; every scenario except `symlink` (which makes its own) expects that
file's recipes.

The pty becomes the child's controlling terminal (os.login_tty), so raw mode,
the alternate screen, job control and Ctrl+C -> SIGINT all behave as they do
in kitty. crossterm asks for the cursor position (ESC[6n) when ratatui clears
the screen; a real terminal answers that, so this script does too.
"""

import os
import re
import select
import shutil
import struct
import sys
import tempfile
import termios
import fcntl
import time
from pathlib import Path

import pyte

ROWS, COLS = 30, 100
DEMO_JUSTFILE = Path(__file__).resolve().parents[2] / "fixtures" / "just" / "justfile"
ESC, ENTER, CTRL_C, BACKSPACE, TAB = b"\x1b", b"\r", b"\x03", b"\x7f", b"\t"
CTRL_Q, CTRL_U, ALT_J = b"\x11", b"\x15", b"\x1bj"
DOWN, UP = b"\x1b[B", b"\x1b[A"


class Session:
    def __init__(self, argv):
        self.master, self.slave = os.openpty()
        fcntl.ioctl(self.slave, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
        self.before = termios.tcgetattr(self.slave)
        env = {k: v for k, v in os.environ.items() if not k.startswith("JUST_")}
        env["TERM"] = "xterm-256color"
        self.pid = os.fork()
        if self.pid == 0:
            os.close(self.master)
            os.login_tty(self.slave)
            os.execvpe(argv[0], argv, env)
        self.raw = b""
        self.screen = pyte.Screen(COLS, ROWS)
        self.stream = pyte.ByteStream(self.screen)
        self.status = None
        self.results = []

    def pump(self, seconds):
        end = time.time() + seconds
        while time.time() < end:
            ready, _, _ = select.select([self.master], [], [], 0.02)
            if ready:
                data = os.read(self.master, 65536)
                self.raw += data
                for _ in range(data.count(b"\x1b[6n")):
                    os.write(self.master, b"\x1b[1;1R")
                self.stream.feed(data)
            if self.status is None:
                pid, status = os.waitpid(self.pid, os.WNOHANG)
                if pid:
                    self.status = status

    def send(self, keys, pause=0.3):
        os.write(self.master, keys)
        self.pump(pause)

    def text(self):
        return "\n".join(line.rstrip() for line in self.screen.display)

    def check(self, label, ok):
        self.results.append((label, bool(ok)))
        print(("PASS  " if ok else "FAIL  ") + label)
        if not ok:
            print(self.text())

    def expect(self, needle, label=None):
        self.check(label or f"screen shows {needle!r}", needle in self.text())

    def refute(self, needle, label=None):
        self.check(label or f"screen hides {needle!r}", needle not in self.text())

    def expect_raw(self, pattern, label):
        self.check(label, re.search(pattern, self.raw) is not None)

    def finish(self, timeout=3):
        self.pump(0.1)
        end = time.time() + timeout
        while self.status is None and time.time() < end:
            self.pump(0.1)
        self.check("process exited", self.status is not None)
        if self.status is None:
            os.kill(self.pid, 9)
            return
        self.check(f"exit code 0 (got {os.waitstatus_to_exitcode(self.status)})",
                   os.waitstatus_to_exitcode(self.status) == 0)
        after = termios.tcgetattr(self.slave)
        self.check("termios restored (cooked mode, echo, signals)", after == self.before)
        last_enter = self.raw.rfind(b"\x1b[?1049h")
        last_leave = self.raw.rfind(b"\x1b[?1049l")
        self.check("left the alternate screen last", last_leave > last_enter >= 0)
        last_hide = self.raw.rfind(b"\x1b[?25l")
        last_show = self.raw.rfind(b"\x1b[?25h")
        self.check("cursor visible at exit", last_show > last_hide)


def scenario_navigate(s):
    """JP5: list + detail, j/k/Down/Up, g/G, q."""
    s.pump(1.5)
    s.expect(" Recipes ")
    s.expect("Default recipe shows help", "detail shows the first recipe")
    s.send(b"jj")
    s.expect("Rekey all secrets", "j j selects the third recipe")
    s.send(b"G")
    s.expect("Create BTRFS snapshot", "G selects the last recipe")
    s.expect("Uses sudo", "detail flags sudo")
    s.send(b"g")
    s.expect("Default recipe shows help", "g selects the first recipe")
    s.send(b"k")
    s.expect("Default recipe shows help", "k at the top stays put")
    s.send(DOWN)
    s.expect("Edit an encrypted secret", "Down moves like j")
    s.refute("_stamp", "private recipe is hidden")
    print("---- screen before q ----\n" + s.text() + "\n-------------------------")
    s.send(b"q")
    s.finish()


def scenario_ctrl_c(s):
    """In raw mode Ctrl+C is a key press: the panel quits cleanly."""
    s.pump(1.5)
    s.expect(" Recipes ")
    s.send(CTRL_C)
    s.finish()


def scenario_filter_help(s):
    """JP6: section headers, / filter (Enter keeps, Esc clears), ? help."""
    s.pump(1.5)
    s.expect("Secrets Management", "section header shown")
    s.expect("Storage Management / Backups", "sub-section header shown")
    s.send(b"/")
    s.send(b"lint", 0.5)
    s.expect("/lint", "status line shows the filter being typed")
    s.send(CTRL_U)
    s.refute("/lintu", "Ctrl+U types nothing into the filter")
    s.expect("lint-rust")
    s.refute("rebuild", "non-matching recipes are hidden")
    s.refute("Secrets Management", "empty sections lose their header")
    s.expect("Development", "matching section keeps its header")
    s.send(ENTER)
    s.expect("filter: lint", "Enter keeps the filter")
    s.send(b"j")
    s.expect("Lint Rust code", "j moves within the filtered list")
    s.send(ESC, 0.5)
    s.expect("rebuild", "Esc clears the filter")
    s.expect("Lint Rust code", "selection stays on the same recipe")
    s.send(b"?")
    s.expect(" Keys ", "? opens the help popup")
    s.expect("Enter keeps it, Esc clears it", "the longest help line is not cut off")
    print("---- help popup ----\n" + s.text() + "\n--------------------")
    s.send(b"x")
    s.refute(" Keys ", "any key closes the help")
    s.send(b"q")
    s.finish()


def scenario_run(s):
    """JP7: run recipes in the real terminal and come back."""
    s.pump(1.5)
    # check: no parameters, nothing to confirm.
    s.send(b"jjjj")
    s.expect("Test configuration syntax", "check selected")
    s.send(ENTER, 2.0)
    s.expect_raw(rb"demo: all checks passed", "check ran and printed its output")
    s.expect_raw(rb"exit status: 0", "pause line shows the exit status")
    s.expect_raw(rb"Press Enter to return", "pause before returning")
    s.send(ENTER, 1.0)
    s.expect(" Recipes ", "TUI is back after Enter")
    s.expect("check: exit 0", "status line shows the last exit code")

    # fuzz: parameter prompt with a pre-filled default, then Ctrl+C mid-run.
    s.send(b"jj")
    s.expect("Run a fuzz target", "fuzz selected")
    s.send(ENTER)
    s.expect("TARGET", "prompt lists TARGET")
    s.expect('default "5"', "prompt shows the default")
    s.send(b"demo")
    s.send(ENTER, 2.2)
    s.expect_raw(rb"fuzzing demo, second 2", "fuzz is running with the typed value")
    s.send(CTRL_C, 1.0)
    s.expect_raw(rb"was terminated", "Ctrl+C interrupted the recipe")
    s.expect_raw(rb"exit status: 130", "just exited 130")
    s.check("just-panel survived Ctrl+C", s.status is None)
    s.send(ENTER, 1.0)
    s.expect("fuzz: exit 130", "status line shows 130")

    # rebuild: variadic prompt, then the sudo confirmation.
    s.send(b"gjjj")
    s.expect("Rebuild current system", "rebuild selected")
    s.send(ENTER)
    s.expect("ARGS", "prompt lists ARGS")
    s.send(b"--boot")
    s.send(ENTER)
    s.expect("uses sudo", "confirmation explains why")
    print("---- confirmation ----\n" + s.text() + "\n----------------------")
    s.send(b"y", 2.0)
    s.expect_raw(rb"would run: sudo nixos-rebuild boot", "rebuild ran with --boot")
    s.send(ENTER, 1.0)
    s.expect("rebuild: exit 0")

    # update: [confirm] attribute; n cancels without running anything.
    s.send(b"jj")
    s.expect("Update flake inputs", "update selected")
    s.send(ENTER)
    s.expect("Update every flake input?", "confirmation shows the [confirm] prompt")
    before = len(s.raw)
    s.send(b"n", 0.5)
    s.check("n cancels: nothing ran", b"nix flake update" not in s.raw[before:])
    s.send(ENTER)
    before = len(s.raw)
    s.send(b"y", 1.0)
    s.expect_raw(rb"\$ just update", "y runs update")
    s.check("--yes: just does not ask again",
            b"would run: nix flake update" in s.raw[before:] and b"not confirmed" not in s.raw[before:])
    s.send(ENTER, 1.0)
    s.expect("update: exit 0")

    # edit-secret: a required parameter left blank is refused in the prompt.
    s.send(b"g")
    s.send(b"j")
    s.expect("Edit an encrypted secret", "edit-secret selected")
    s.send(ENTER)
    s.send(ENTER)
    s.expect("SECRET is required", "blank required parameter is refused")
    s.send(ESC, 0.5)
    s.refute("just edit-secret", "Esc closes the prompt")
    s.send(b"q")
    s.finish()


def scenario_ctrl_keys(s):
    """Ctrl and Alt make a different key: crossterm reports Ctrl+Q as `q`
    plus CONTROL, and Alt+J as `j` plus ALT, and neither may act as the
    plain letter."""
    s.pump(1.5)
    s.send(CTRL_Q)
    s.check("Ctrl+Q does not quit", s.status is None)
    s.send(ALT_J)
    s.expect("Default recipe shows help", "Alt+J does not move")
    s.send(b"q")
    s.finish()


def scenario_typeahead(s):
    """JP7: keys that arrived before a run are dropped when the panel comes
    back, so a double-tapped Enter runs the recipe once, not twice."""
    s.pump(1.5)
    s.send(b"jjjj")
    s.expect("Test configuration syntax", "check selected")
    mark = len(s.raw)
    # Both presses in one write, so the panel reads them together.
    s.send(ENTER + ENTER, 2.0)
    s.expect_raw(rb"Press Enter to return", "check ran")
    s.send(ENTER, 2.0)
    s.check("a double Enter runs check once",
            s.raw[mark:].count(b"$ just check") == 1)
    s.expect("check: exit 0", "back in the list")
    s.send(b"q")
    s.finish()


def symlinked_justfile():
    """A justfile reached through a symlink from another directory, with one
    recipe that prints where it runs."""
    root = tempfile.mkdtemp(prefix="just-panel-smoke-")
    os.mkdir(f"{root}/real")
    os.mkdir(f"{root}/link")
    with open(f"{root}/real/justfile", "w") as justfile:
        justfile.write("# Print the working directory\nwhere:\n    @pwd\n")
    os.symlink(f"{root}/real/justfile", f"{root}/link/justfile")
    return f"{root}/link/justfile"


def scenario_symlink(s):
    """JP7: through a symlink, recipes run where just runs them: in the
    directory of the path given, not of the file it points to."""
    s.pump(1.5)
    s.send(ENTER, 1.5)
    link_dir = os.path.realpath(os.path.dirname(s.justfile))
    real_dir = os.path.realpath(os.path.dirname(os.path.realpath(s.justfile)))
    s.expect_raw(re.escape(f"\n{link_dir}\r\n".encode()),
                 "the recipe ran in the symlink's directory")
    s.check("not in the target's directory", f"\n{real_dir}\r\n".encode() not in s.raw)
    s.send(ENTER, 1.0)
    s.send(b"q")
    s.finish()
    shutil.rmtree(os.path.dirname(os.path.dirname(s.justfile)))


SCENARIOS = {
    "navigate": scenario_navigate,
    "ctrl-c": scenario_ctrl_c,
    "ctrl-keys": scenario_ctrl_keys,
    "filter-help": scenario_filter_help,
    "run": scenario_run,
    "typeahead": scenario_typeahead,
    "symlink": scenario_symlink,
}

if __name__ == "__main__":
    if len(sys.argv) not in (3, 4) or sys.argv[2] not in SCENARIOS:
        sys.exit(f"usage: smoke.py BINARY SCENARIO [JUSTFILE]\n"
                 f"scenarios: {', '.join(SCENARIOS)}")
    binary, name = sys.argv[1:3]
    justfile = sys.argv[3] if len(sys.argv) == 4 else str(DEMO_JUSTFILE)
    if name == "symlink":
        justfile = symlinked_justfile()
    session = Session([binary, "--justfile", justfile])
    session.justfile = justfile
    SCENARIOS[name](session)
    failed = [label for label, ok in session.results if not ok]
    print(f"== {name}: {len(session.results) - len(failed)}/{len(session.results)} checks passed")
    sys.exit(1 if failed else 0)
