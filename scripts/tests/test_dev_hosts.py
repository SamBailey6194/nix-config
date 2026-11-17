import importlib.util
import json
from pathlib import Path

import pytest

SPEC = importlib.util.spec_from_file_location("dev_hosts", Path(__file__).resolve().parent.parent / "dev-hosts.py")
dev_hosts = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(dev_hosts)


@pytest.fixture
def data(tmp_path):
    path = tmp_path / "dev-hosts.json"
    path.write_text('{\n  "slugs": []\n}\n')
    return path


def slugs(path):
    return json.loads(path.read_text())["slugs"]


def test_add_sorts_and_is_idempotent(data):
    assert dev_hosts.main(["add", "zeta"], data) == 0
    assert dev_hosts.main(["add", "alpha-2"], data) == 0
    assert dev_hosts.main(["add", "zeta"], data) == 0
    assert slugs(data) == ["alpha-2", "zeta"]


@pytest.mark.parametrize("bad", ["Upper", "under_score", "-lead", "trail-", "a.b", "", "x" * 64, "<%PROJECT_SLUG%>"])
def test_add_refuses_invalid_labels(data, bad):
    assert dev_hosts.main(["add", bad], data) == 1
    assert slugs(data) == []


def test_remove(data):
    dev_hosts.main(["add", "shop"], data)
    assert dev_hosts.main(["remove", "shop"], data) == 0
    assert slugs(data) == []
    assert dev_hosts.main(["remove", "shop"], data) == 1


def test_usage_errors(data):
    assert dev_hosts.main([], data) == 2
    assert dev_hosts.main(["add"], data) == 2
    assert dev_hosts.main(["frob", "x"], data) == 2


def test_rejects_malformed_file(data):
    data.write_text('{"slugs": "shop"}')
    with pytest.raises(ValueError):
        dev_hosts.main(["list"], data)
