"""~/Data, the bind mount of /mnt/data on devtower-intel, and what follows it.

Static checks of the declarations; the evaluated units are checked with
`nix eval` against a copy with dataPair.data.partUuid filled in.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[3]
PAIR = (ROOT / "hosts/devtower-intel/data-pair.nix").read_text()


def block(text, start):
    """The text from `start` to the matching closing brace of its attrset."""
    i = text.index(start)
    # The brace that ends `start` opens the attrset (not one inside ${...}).
    depth, j = 0, text.index("{", i + len(start) - 1)
    for k in range(j, len(text)):
        depth += {"{": 1, "}": -1}.get(text[k], 0)
        if depth == 0:
            return text[i:k + 1]
    raise AssertionError(f"unbalanced {start}")


class DataHomeMountTests(unittest.TestCase):
    def test_bind_mount_is_inside_the_wd_switch(self):
        data_on = block(PAIR, "(lib.mkIf dataOn {")
        self.assertIn("fileSystems.${dataHome}", data_on)
        self.assertIn('dataHome = "${user.home}/Data";', PAIR)
        self.assertIn("user = config.users.users.sam-desktop;", PAIR)

    def test_bind_mount_depends_on_mnt_data_and_never_blocks_boot(self):
        mount = block(PAIR, "fileSystems.${dataHome} = {")
        self.assertIn('device = "/mnt/data";', mount)
        self.assertIn('depends = [ "/mnt/data" ];', mount)
        options = re.search(r"options = \[(.*?)\];", mount, re.S).group(1)
        self.assertEqual(re.findall(r'"([^"]+)"', options),
                         ["bind", "nofail", "x-systemd.after=systemd-tmpfiles-setup.service"])
        # Exactly these: x-systemd.wanted-by would make nofail meaningless
        # (systemd.mount(5)), so /mnt/data wants ~/Data through a drop-in.
        self.assertIn("Wants=${dataHomeMount}", block(PAIR, 'systemd.units."mnt-data.mount" = {'))

    def test_mountpoint_belongs_to_the_user(self):
        # Read-only while empty: with the WD absent, writes must fail rather
        # than land on /home underneath the later bind.
        self.assertIn('"d ${dataHome} 0555 ${user.name} ${user.group} -"', PAIR)

    def test_scanner_skips_data_home_and_keeps_its_defaults(self):
        self.assertIn("options ? security.malwareScanner", PAIR)
        self.assertIn("excludePaths.default ++ [ dataHome ]", PAIR)
        self.assertIn("realTimeMonitoring.excludePaths.default ++ [ dataHome ]", PAIR)


class FollowersTests(unittest.TestCase):
    def test_git_identity_for_both_paths(self):
        git = (ROOT / "home/modules/git.nix").read_text()
        # The volume layout is lowercase: NTFS ignores case, git's gitdir
        # match does not.
        for area, config in [("business", "syntek"), ("personal", "personal")]:
            for root in ["/mnt/data", "~/Data"]:
                pattern = f"gitdir:{root}/{area}/"
                self.assertRegex(git, re.escape(f'includeIf."{pattern}"')
                                 + r' = \{\s*path = "~/.gitconfig-' + config + '";')
        self.assertNotRegex(git, r"gitdir:(/mnt/data|~/Data)/[A-Z]")

    def test_yazi_goes_to_data_home_only_where_mounted(self):
        fm = (ROOT / "home/modules/file-manager.nix").read_text()
        self.assertIn('dataDir = if hostMounts ? ${dataHome} then dataHome else davinci;', fm)
        self.assertIn('run = "cd ${dataDir}"', fm)
        self.assertIn('run = "cd ${davinci}/Affinity"', fm)


if __name__ == "__main__":
    unittest.main()
