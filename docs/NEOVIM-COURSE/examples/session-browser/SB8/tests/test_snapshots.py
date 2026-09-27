"""What the screen looks like, compared with an SVG committed next to the tests.

After a deliberate change to the layout, review the new picture and accept it
with `uv run pytest --snapshot-update`.
"""

import pytest
from textual.pilot import Pilot

from session_browser.app import SessionBrowser

pytestmark = pytest.mark.usefixtures("pinned_stores")


async def wait_for_sessions(pilot: Pilot[None]) -> None:
    await pilot.app.workers.wait_for_complete()
    await pilot.pause()


def test_oldest_session_selected(snap_compare) -> None:
    # The last row is the one with [/bold] in its title and messages, so the
    # picture also shows that markup is displayed, never interpreted.
    assert snap_compare(
        SessionBrowser(),
        terminal_size=(116, 34),
        run_before=wait_for_sessions,
        press=["G"],
    )
