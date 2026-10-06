import importlib.util
from pathlib import Path
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "guard", Path(__file__).parents[1] / "nix-source-guard.py"
)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class NixSourceGuardTests(unittest.TestCase):
    def test_repository_paths_and_worktrees_are_blocked(self):
        with tempfile.TemporaryDirectory() as directory:
            repo = Path(directory) / "repo"
            repo.mkdir()
            (repo / ".git").write_text("gitdir: /some/worktree")
            for reference in ["path:.", "path:./rust#foo", f"path:{repo}#foo",
                              "path:$PWD#foo", f"path:{repo}/new%20dir#foo"]:
                with self.subTest(reference=reference):
                    self.assertTrue(guard.violation(f"nix eval '{reference}'", repo))

    def test_git_flakes_and_filtered_copies_are_allowed(self):
        with tempfile.TemporaryDirectory() as directory:
            for reference in [".#foo", "git+file:///repo#foo", f"path:{directory}#foo"]:
                with self.subTest(reference=reference):
                    self.assertFalse(guard.violation(f"nix eval '{reference}'", directory))


if __name__ == "__main__":
    unittest.main()
