import importlib.util
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch


spec = importlib.util.spec_from_file_location(
    "rekey_secrets", Path(__file__).resolve().parents[1] / "rekey-secrets.py"
)
rekey = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rekey)

MASTER = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMpKt3D+3F9hRgxQ2SfCF8w/4imuzx1EvS0KpBptd4iw sam@devtower-intel"
LAPTOP = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDDdE+EkEkG7BtvLb5mDPC6bPbs0vzw1yq6xcfmv+hao sam@laptop-intel"
RECOVERY = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL85AfBRAEKSNgFe7cM0mmmG3w+e0S5mcEtIQy/P0fgG sam@keys-recovery"


def age_file(path, *stanzas):
    lines = ["age-encryption.org/v1"]
    for stanza in stanzas:
        lines += [f"-> {stanza}", "Zm9v"]
    path.write_bytes(("\n".join(lines) + "\n--- bWFj\n").encode() + b"\x00\xffbody")


def ssh(key):
    return f"ssh-ed25519 {rekey.ssh_tag(key)} c2hhcmVk"


class RekeySecretsTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory()
        self.addCleanup(temp.cleanup)
        self.dir = Path(temp.name)
        patcher = patch.object(rekey, "secrets_dir", self.dir)
        patcher.start()
        self.addCleanup(patcher.stop)

    def test_tag_matches_age_for_a_known_file(self):
        # The master key's stanza in secrets/luks-passphrase-devtower-intel-os.age.
        self.assertEqual(rekey.ssh_tag(MASTER), "RDeX4g")
        self.assertIsNone(rekey.ssh_tag("age1qyqszqgpqyqszqgpqyqszqgpqyqszqgp"))

    def test_plan_sorts_files_by_what_the_identity_can_do(self):
        age_file(self.dir / "mine.age", ssh(MASTER))
        age_file(self.dir / "theirs.age", ssh(LAPTOP))
        age_file(self.dir / "done.age", ssh(MASTER), ssh(RECOVERY))
        rules = {
            "mine.age": [MASTER, RECOVERY],
            "theirs.age": [MASTER, RECOVERY, LAPTOP],
            "done.age": [MASTER, RECOVERY],
            "absent.age": [MASTER],
        }
        plan = dict(rekey.plan(rules, rekey.ssh_tag(MASTER)))
        self.assertEqual(plan, {
            "absent.age": "missing", "done.age": "current",
            "mine.age": "rekey", "theirs.age": "skip",
        })

    def test_all_rekeys_current_files_too(self):
        age_file(self.dir / "done.age", ssh(MASTER))
        plan = rekey.plan({"done.age": [MASTER]}, rekey.ssh_tag(MASTER), rekey_all=True)
        self.assertEqual(plan, [("done.age", "rekey")])

    def test_non_ssh_stanza_cannot_be_compared_so_it_is_rekeyed(self):
        age_file(self.dir / "mixed.age", ssh(MASTER), "X25519 c29tZQ")
        self.assertIsNone(rekey.header_tags(self.dir / "mixed.age"))
        # The identity tag is still unknown to the comparison, so it is skipped
        # rather than guessed at.
        plan = rekey.plan({"mixed.age": [MASTER]}, rekey.ssh_tag(MASTER))
        self.assertEqual(plan, [("mixed.age", "skip")])

    def test_dry_run_runs_no_agenix(self):
        key = self.dir / "id"
        key.write_text("private")
        Path(f"{key}.pub").write_text(MASTER)
        age_file(self.dir / "mine.age", ssh(MASTER))
        with patch.object(rekey, "load_rules", return_value={"mine.age": [MASTER, RECOVERY]}), \
             patch.object(rekey.subprocess, "run") as run, \
             patch("builtins.print"):
            self.assertEqual(rekey.main(["--identity", str(key), "--dry-run"]), 0)
        run.assert_not_called()

    def test_rekey_calls_agenix_with_identity_and_no_editor(self):
        key = self.dir / "id"
        key.write_text("private")
        Path(f"{key}.pub").write_text(MASTER)
        age_file(self.dir / "mine.age", ssh(MASTER))
        age_file(self.dir / "theirs.age", ssh(LAPTOP))
        rules = {"mine.age": [MASTER, RECOVERY], "theirs.age": [LAPTOP, MASTER]}
        with patch.object(rekey, "load_rules", return_value=rules), \
             patch.object(rekey, "agenix_command", return_value=["agenix"]), \
             patch.object(rekey.subprocess, "run") as run, \
             patch("builtins.print"):
            run.return_value.returncode = 0
            self.assertEqual(rekey.main(["--identity", str(key)]), 0)
        run.assert_called_once()
        args, kwargs = run.call_args
        self.assertEqual(args[0], ["agenix", "-e", "mine.age", "-i", str(key)])
        self.assertEqual(kwargs["env"]["EDITOR"], ":")

    def test_failure_is_reported(self):
        key = self.dir / "id"
        key.write_text("private")
        Path(f"{key}.pub").write_text(MASTER)
        age_file(self.dir / "mine.age", ssh(MASTER))
        with patch.object(rekey, "load_rules", return_value={"mine.age": [MASTER, RECOVERY]}), \
             patch.object(rekey, "agenix_command", return_value=["agenix"]), \
             patch.object(rekey.subprocess, "run") as run, \
             patch("builtins.print"):
            run.return_value.returncode = 1
            self.assertEqual(rekey.main(["--identity", str(key)]), 1)

    def test_missing_public_key_is_an_error(self):
        key = self.dir / "id"
        key.write_text("private")
        with patch("builtins.print"):
            self.assertEqual(rekey.main(["--identity", str(key)]), 2)


if __name__ == "__main__":
    unittest.main()
