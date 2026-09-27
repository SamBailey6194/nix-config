"""The Textual app: the session list, the preview and the key bindings."""

import argparse
import re
import sys
from datetime import datetime
from pathlib import Path

from textual import work
from textual.app import App, ComposeResult
from textual.binding import Binding
from textual.containers import Horizontal, VerticalScroll
from textual.content import Content
from textual.widgets import DataTable, Footer, Header, Input, Static, Tab, Tabs

from session_browser.models import Session, Source
from session_browser.sources import claude, codex, kitty

RECENT_MESSAGES = {
    Source.CLAUDE: claude.recent_messages,
    Source.CODEX: codex.recent_messages,
}
"""How to read a session's last few messages. Kitty sessions have none."""

MESSAGE_CHARS = 600
"""Longer messages are cut in the preview; the full text is in the file."""

UNPRINTABLE = re.compile(r"[\x00-\x08\x0b-\x1f\x7f-\x9f]")
"""Control characters, bar tab and newline: see printable()."""


class SessionTable(DataTable):
    """The session list, with Vim's keys for moving about.

    Bindings on the focused widget are checked before the app's, and these
    are added to DataTable's own (arrows, Page Up/Down, Enter), not swapped
    for them.
    """

    BINDINGS = [
        Binding("j", "cursor_down", "Move", key_display="j/k"),
        Binding("k", "cursor_up", "Up", show=False),
        Binding("g", "scroll_top", "Top", show=False),
        Binding("G", "scroll_bottom", "Bottom", show=False),
    ]


class SessionBrowser(App[None]):
    """Every Claude Code, Codex and Kitty session, newest first."""

    TITLE = "Session browser"
    CSS_PATH = "app.tcss"
    BINDINGS = [
        Binding("slash", "focus_search", "Search", key_display="/"),
        Binding("l", "next_source", "Source", key_display="h/l"),
        Binding("h", "previous_source", "Previous source", show=False),
        # Escape has to live here, on the app: the search box has no binding
        # for it, so the key bubbles up from the Input to the app.
        Binding("escape", "focus_table", "Back to the list", show=False),
        Binding("q", "quit", "Quit"),
    ]

    def __init__(self, kitty_dir: Path | None = None) -> None:
        super().__init__()
        self.kitty_dir = kitty_dir
        self.sessions: dict[str, Session] = {}

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal(id="filters"):
            yield Tabs(
                Tab("All", id="all"),
                *(Tab(source.name.title(), id=source.value) for source in Source),
            )
            yield Input(
                placeholder="/ to search titles and folders", id="search", compact=True
            )
        with Horizontal():
            yield SessionTable(id="sessions", cursor_type="row")
            with VerticalScroll(id="preview-pane"):
                # Titles and messages are full of [square brackets], which
                # Textual would otherwise read as style markup: at best the
                # text changes colour, at worst "[/bold]" raises MarkupError.
                yield Static(id="preview", markup=False)
        yield Footer()

    def on_mount(self) -> None:
        table = self.query_one(SessionTable)
        table.add_column("Source", width=6)
        table.add_column("Title", width=30)
        table.add_column("Project", width=15)
        table.add_column("Updated", width=16)
        table.loading = True
        self.load_sessions()

    @work(thread=True, exclusive=True)
    def load_sessions(self) -> None:
        """Read all three stores in a thread, so the window draws at once."""
        sessions = [
            *claude.load_sessions(),
            *codex.load_sessions(),
            *kitty.load_sessions(self.kitty_dir),
        ]
        sessions.sort(key=lambda session: session.updated, reverse=True)
        # Widgets belong to the app's thread: hand the result back to it.
        self.call_from_thread(self.show_sessions, sessions)

    def show_sessions(self, sessions: list[Session]) -> None:
        self.sessions = {session.key: session for session in sessions}
        table = self.query_one(SessionTable)
        table.loading = False
        # While it was loading the table could not take focus, so Textual gave
        # it to the preview pane. Move it to where the keys are meant to go.
        table.focus()
        self.refresh_table()

    def refresh_table(self) -> None:
        """Fill the table with the sessions the tab and the search allow."""
        source = self.query_one(Tabs).active
        search = self.query_one(Input).value
        shown = [s for s in self.sessions.values() if matches(s, source, search)]
        table = self.query_one(SessionTable)
        table.clear()
        for session in shown:
            table.add_row(
                session.source.name.title(),
                # A plain str cell is parsed as markup too; Content is not.
                Content(printable(session.title)),
                Content(printable(session.project)),
                format_time(session.updated),
                key=session.key,
            )
        if not shown:
            self.query_one("#preview", Static).update("")
        self.sub_title = f"{len(shown)} of {len(self.sessions)} sessions"

    def on_tabs_tab_activated(self) -> None:
        self.refresh_table()

    def on_input_changed(self) -> None:
        self.refresh_table()

    def on_input_submitted(self) -> None:
        self.action_focus_table()

    def on_data_table_row_highlighted(self, event: DataTable.RowHighlighted) -> None:
        # Moving the cursor in an empty table (Up, Page Down) still posts this
        # event, for row -1 and with no row key at all, whatever the type hint
        # says.
        if event.row_key is None:
            return
        session = self.sessions.get(event.row_key.value or "")
        if session is not None:
            # Reading the preview is quick enough to do right here: at most the
            # first 30 lines and the last 256 KiB of one file.
            text = printable(preview_text(session))
            self.query_one("#preview", Static).update(text)

    def action_focus_search(self) -> None:
        self.query_one(Input).focus()

    def action_focus_table(self) -> None:
        self.query_one(SessionTable).focus()

    def action_next_source(self) -> None:
        self.query_one(Tabs).action_next_tab()

    def action_previous_source(self) -> None:
        self.query_one(Tabs).action_previous_tab()


def matches(session: Session, source: str, search: str) -> bool:
    """Is the session in the chosen tab, with the search text in its title
    or folder? Case is ignored; an empty search matches everything."""
    if source != "all" and session.source != source:
        return False
    search = search.casefold()
    folder = str(session.cwd or "")
    return search in session.title.casefold() or search in folder.casefold()


def preview_text(session: Session) -> str:
    """The preview pane as plain text: what the session is, then its tail."""
    source = session.source.name.title()
    lines = [
        session.title,
        "",
        f"Source   {source}" + (f" ({session.detail})" if session.detail else ""),
        f"Updated  {format_time(session.updated)}",
        f"Folder   {tilde(session.cwd) if session.cwd else '(unknown)'}",
        f"File     {tilde(session.path)}",
    ]
    read_messages = RECENT_MESSAGES.get(session.source)
    if read_messages is None:
        return "\n".join(lines)
    try:
        messages = read_messages(session.path)
    except OSError as error:
        lines += ["", f"Could not read the conversation: {error.strerror}"]
        messages = []
    for message in messages:
        speaker = "You" if message.role == "user" else source
        text = message.text
        if len(text) > MESSAGE_CHARS:
            text = text[: MESSAGE_CHARS - 1] + "…"
        lines += ["", f"{speaker}:", text]
    return "\n".join(lines)


def format_time(when: datetime) -> str:
    """Local time, to the minute: 2026-09-24 10:47."""
    return when.astimezone().strftime("%Y-%m-%d %H:%M")


def tilde(path: Path) -> str:
    """The path with your home directory written as ~, as a shell shows it."""
    home = Path.home()
    return str("~" / path.relative_to(home)) if path.is_relative_to(home) else str(path)


def printable(text: str) -> str:
    """The text with each control character, bar tab and newline, shown as �.

    Content and markup=False stop Textual reading [brackets] as style, but the
    characters themselves still go to your terminal as they are. An escape
    sequence in a title or a message would be obeyed, not shown: it could
    clear the screen, rename the window or write to your clipboard.
    """
    return UNPRINTABLE.sub("\N{REPLACEMENT CHARACTER}", text)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Browse, search and resume Claude Code, Codex and Kitty sessions."
    )
    parser.add_argument(
        "--kitty-sessions-dir",
        type=Path,
        metavar="DIR",
        help="where your kitty session files live (default: "
        "$SESSION_BROWSER_KITTY_DIR, else ~/.local/share/kitty/sessions)",
    )
    args = parser.parse_args()
    app = SessionBrowser(kitty_dir=args.kitty_sessions_dir)
    app.run()
    # run() returns normally even when the app crashed; its return code is 1
    # then, and passing it on lets your shell and scripts see the failure.
    sys.exit(app.return_code)
