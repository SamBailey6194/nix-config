"""Every module in the package imports cleanly, stubs included."""

import importlib

import pytest

MODULES = [
    "session_browser",
    "session_browser.actions",
    "session_browser.app",
    "session_browser.models",
    "session_browser.sources",
    "session_browser.sources.claude",
    "session_browser.sources.codex",
    "session_browser.sources.kitty",
]


@pytest.mark.parametrize("name", MODULES)
def test_module_imports(name: str) -> None:
    importlib.import_module(name)
