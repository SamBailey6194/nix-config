import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location(
    "guard", Path(__file__).parents[1] / "git-no-verify-guard.py"
)
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)


class GitNoVerifyGuardTests(unittest.TestCase):
    def test_hook_skipping_commands_are_blocked(self):
        for command in [
            "git commit --no-verify -m wip",
            "git commit -m wip --no-verify",
            "git commit --no-ver -m wip",
            "git commit -n -m wip",
            "git commit -anm wip",
            "git push --no-verify",
            "git push origin main --no-verify",
            "/usr/bin/git commit --no-verify",
            "git -C rust commit --no-verify",
            "git -c core.hooksPath=/dev/null commit -m wip",
            "FOO=1 git commit --no-verify",
            "cd repo && git add -A && git commit --no-verify -m wip && git push",
            "git add x; git commit -n",
            "git commit -m 'unbalanced --no-verify",
        ]:
            with self.subTest(command=command):
                self.assertTrue(guard.violation(command))

    def test_normal_git_commands_are_allowed(self):
        for command in [
            "git commit -m wip",
            "git commit -m 'mention -n and --no-verify in a message'",
            "git commit -m -n",
            "git commit -Snokey -m wip",
            "git commit --message --no-verify",
            "git push -n origin main",
            "git push -u origin media-tools",
            "git log --no-verify",
            "cd repo && git add -A && git commit -m wip && git push",
            "git commit -F - <<'EOF'\nSubject\n\nSkip with --no-verify -n never\nEOF",
            "git commit -- -n",
        ]:
            with self.subTest(command=command):
                self.assertFalse(guard.violation(command))


if __name__ == "__main__":
    unittest.main()
