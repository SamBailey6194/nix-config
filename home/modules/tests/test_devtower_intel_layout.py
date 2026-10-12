"""Exercise devtower-intel's 40-workspace map and keybinds with Lua mocks.

60-keybinds.lua is loaded first and the device file second, as Hyprland does,
against the REAL 00-vars.lua so the vars.mailWorkspace override is exercised.
"""
from pathlib import Path
import re
import unittest
from lupa import LuaRuntime

HYPR = Path(__file__).resolve().parents[3] / "config/hypr"
LEFT, CENTRE, RIGHT = "desc:AOC U2879G6", "desc:AOC AG271QG4", "desc:AOC 27G2WG3-"


def runtime():
    lua = LuaRuntime()
    lua.globals().vars_path = str(HYPR / "00-vars.lua")
    lua.execute('''
        monitors, workspaces, rules, env, events, launches, focused = {}, {}, {}, {}, {}, {}, {}
        -- binds[submap][key] = action; log keeps bind/unbind order for "global".
        binds, log, submap = { global = {} }, {}, "global"
        active_ws = 1
        package.preload["00-vars"] = function() return dofile(vars_path) end

        -- Any hl.dsp.<a>.<b>(args) returns a tagged table.
        local function action(path)
            return setmetatable({}, {
                __index = function(_, k) return action(path .. "." .. k) end,
                __call = function(_, args) return { path = path, args = args } end,
            })
        end

        hl = {
            monitor = function(r) table.insert(monitors, r) end,
            workspace_rule = function(r) table.insert(workspaces, r) end,
            window_rule = function(r) table.insert(rules, r) end,
            env = function(k, v) env[k] = v end,
            bind = function(key, fn, _)
                binds[submap][key] = fn
                if submap == "global" then table.insert(log, { "bind", key }) end
                return { key = key }
            end,
            unbind = function(key)
                binds.global[key] = nil
                table.insert(log, { "unbind", key })
            end,
            define_submap = function(name, _, fn)
                binds[name] = binds[name] or {}
                local previous = submap
                submap = name
                fn()
                submap = previous
            end,
            on = function(event, fn) events[event] = fn end,
            exec_cmd = function(cmd) table.insert(launches, cmd) end,
            timer = function() end,
            get_active_workspace = function() return { id = active_ws } end,
            get_windows = function() return {} end,
            dispatch = function(a)
                if a.path == "dsp.focus" then
                    active_ws = a.args.workspace
                    table.insert(focused, a.args.workspace)
                end
            end,
            dsp = action("dsp"),
        }
    ''')
    lua.execute((HYPR / "60-keybinds.lua").read_text())
    return lua


class DevtowerIntelLayoutTests(unittest.TestCase):
    def setUp(self):
        self.lua = runtime()
        self.lua.execute((HYPR / "devices/devtower-intel.lua").read_text())
        self.g = self.lua.globals()

    def test_forty_workspaces_on_the_right_monitors(self):
        ws = list(self.g.workspaces.values())
        self.assertEqual(len(ws), 40)
        left = {11, 12, 15, 19, 29, 30}
        for rule in ws:
            wid = int(rule.workspace)
            expected = RIGHT if wid == 1 else LEFT if wid in left else CENTRE
            self.assertEqual(rule.monitor, expected, wid)
            # One default per monitor, and empty workspaces are not persisted.
            self.assertEqual(bool(rule.default), wid in (1, 2, 11), wid)
            self.assertFalse(rule.persistent, wid)
        self.assertEqual(sorted(int(r.workspace) for r in ws), list(range(1, 41)))

    def test_shift_bank_is_unbound_before_it_is_rebound_to_focus(self):
        log = [(e[1], e[2]) for e in self.g.log.values()]
        for i in range(1, 11):
            key = f"SUPER + SHIFT + {i % 10}"
            unbind = log.index(("unbind", key))
            self.assertIn(("bind", key), log[:unbind], "60-keybinds bound it first")
            self.assertIn(("bind", key), log[unbind + 1:], "rebound after unbind")
            a = self.g.binds["global"][key]
            self.assertEqual((a.path, a.args.workspace), ("dsp.focus", 10 + i), key)

    def test_ctrl_and_alt_banks_focus_21_to_40_and_super_0_is_still_10(self):
        for prefix, offset in (("", 0), ("CTRL + ", 20), ("ALT + ", 30)):
            for i in range(1, 11):
                a = self.g.binds["global"][f"SUPER + {prefix}{i % 10}"]
                self.assertEqual((a.path, a.args.workspace), ("dsp.focus", offset + i))
        a = self.g.binds["global"]["SUPER + 0"]
        self.assertEqual(a.args.workspace, 10)

    def test_move_window_submap_covers_1_to_40_and_escape_resets(self):
        enter = self.g.binds["global"]["SUPER + period"]
        self.assertEqual((enter.path, enter.args), ("dsp.submap", "move-window"))
        sub = self.g.binds["move-window"]
        for prefix, offset in (("", 0), ("SHIFT + ", 10), ("CTRL + ", 20), ("ALT + ", 30)):
            for i in range(1, 11):
                a = sub[f"{prefix}{i % 10}"]
                self.assertEqual((a.path, a.args.workspace), ("dsp.window.move", offset + i))
        self.assertEqual((sub["escape"].path, sub["escape"].args), ("dsp.submap", "reset"))

    def test_catch_all_comes_first_and_specific_rules_win(self):
        rules = list(self.g.rules.values())
        catch_all = [i for i, r in enumerate(rules) if r.match["class"] == ".*"]
        self.assertEqual(catch_all, [0], "catch-all registered before every specific rule")
        # Apply matching class-only rules in registration order, as Hyprland does.
        for cls, expected in {
            "zen-beta": "11", "librewolf": "12", "firefox-devedition": "13",
            "brave-browser": "14", "aerc": "3", "aerc-keybinds": "3",
            "claws-mail": "3", "yazi": "2", "teams-for-linux": "10",
            "resolve": "19", "nixcfg-nvim": "31", "libreoffice-calc": "5",
            "termfilechooser": "unset", "unassigned-app": "20",
        }.items():
            destination = None
            for rule in rules:
                if rule.match.title is None and re.fullmatch(rule.match["class"], cls):
                    destination = rule.workspace
            self.assertEqual(destination, expected, cls)

    def test_creative_workspaces_19_to_30(self):
        # By rule name, so the Craft class strings can change independently.
        by_name = {r.name: r.workspace for r in self.g.rules.values()}
        for name, expected in {
            "intel-resolve": "19", "intel-craft-photo": "21",
            "intel-craft-vector": "22", "intel-craft-light": "23",
            "intel-craft-pdf": "24", "intel-craft-design": "25",
            "intel-craft-sound": "26", "intel-craft-word": "27",
            "intel-craft-deck": "28", "intel-craft-effect": "29",
            "intel-craft-film": "30",
        }.items():
            self.assertEqual(by_name.get(name), expected, name)
        self.assertNotIn("intel-craft-art", by_name, "ArtCraft has no Linux build")
        # 20 is the spare: only the catch-all sends windows there.
        on_20 = [n for n, ws in by_name.items() if ws == "20"]
        self.assertEqual(on_20, ["intel-default-catch-all"])

    def test_craft_rules_match_the_packaged_app_ids(self):
        # app_ids from pkgs/craft-apps (desktop file id / StartupWMClass).
        rules = list(self.g.rules.values())
        by_name = {r.name: r for r in rules}
        expected = {
            "photo": ("21", ("ai.storyteller.photocraft", "photocraft")),
            "vector": ("22", ("ai.storyteller.vectorcraft",)),
            "light": ("23", ("ai.storyteller.lightcraft",)),
            "pdf": ("24", ("ai.storyteller.pdfcraft",)),
            "design": ("25", ("ai.storyteller.designcraft",)),
            "sound": ("26", ("ai.storyteller.soundcraft",)),
            "word": ("27", ("ai.storyteller.wordcraft",)),
            "deck": ("28", ("ai.storyteller.deckcraft",)),
            "effect": ("29", ("ai.storyteller.effectcraft",)),
            "film": ("30", ("ai.storyteller.filmcraft",)),
        }
        for app, (ws, ids) in expected.items():
            rule = by_name[f"intel-craft-{app}"]
            self.assertEqual(rule.workspace, ws, app)
            for app_id in ids:
                self.assertTrue(re.fullmatch(rule.match["class"], app_id), app_id)
                # Last matching rule wins, as in Hyprland.
                destination = None
                for r in rules:
                    if r.match.title is None and re.fullmatch(r.match["class"], app_id):
                        destination = r.workspace
                self.assertEqual(destination, ws, app_id)
            # Dots are escaped, so a look-alike id does not match.
            self.assertIsNone(re.fullmatch(rule.match["class"], f"aiXstoryteller.{app}craft"))

    def test_dev_layout_env(self):
        self.assertEqual(self.g.env["DEV_LAYOUT_NIX_CONFIG_WS"], "31")
        self.assertEqual(self.g.env["DEV_LAYOUT_POOL_FIRST"], "32")
        self.assertEqual(self.g.env["DEV_LAYOUT_POOL_LAST"], "40")

    def test_mail_layout_follows_the_device_override_to_3(self):
        self.lua.execute('binds.global["SUPER + E"]()')
        self.assertEqual(self.g.active_ws, 3)


class LaptopRegressionTests(unittest.TestCase):
    def test_mail_layout_stays_on_6_without_the_device_file(self):
        lua = runtime()
        lua.execute('binds.global["SUPER + E"]()')
        self.assertEqual(lua.globals().active_ws, 6)
        # SUPER + SHIFT + N still moves windows to 1-10 there.
        a = lua.globals().binds["global"]["SUPER + SHIFT + 1"]
        self.assertEqual((a.path, a.args.workspace), ("dsp.window.move", 1))


if __name__ == "__main__":
    unittest.main()
