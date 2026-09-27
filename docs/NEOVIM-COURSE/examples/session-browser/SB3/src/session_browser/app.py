"""The Textual app: the session list, the preview and the key bindings."""

from textual.app import App, ComposeResult
from textual.widgets import Footer, Header


class SessionBrowser(App[None]):
    """For now just the frame: a title bar, a key bar and a way out."""

    TITLE = "Session browser"
    BINDINGS = [("q", "quit", "Quit")]

    def compose(self) -> ComposeResult:
        yield Header()
        yield Footer()


def main() -> None:
    SessionBrowser().run()
