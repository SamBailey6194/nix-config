"""Exercise devtower-intel's 40-workspace map, keybinds and overflow with Lua mocks.

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
        -- windows: what hl.get_windows() sees; live: what hl.get_workspaces() sees.
        windows, live, moves = {}, {}, {}
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
            -- 60-keybinds.lua and the device file both handle window.open.
            on = function(event, fn)
                events[event] = events[event] or {}
                table.insert(events[event], fn)
            end,
            exec_cmd = function(cmd) table.insert(launches, cmd) end,
            timer = function() end,
            get_active_workspace = function() return { id = active_ws } end,
            get_windows = function(q)
                local found = {}
                for _, w in ipairs(windows) do
                    if not q or q.class == nil or w.class == q.class then
                        table.insert(found, w)
                    end
                end
                return found
            end,
            get_workspaces = function() return live end,
            dispatch = function(a)
                if a.path == "dsp.focus" then
                    active_ws = a.args.workspace
                    table.insert(focused, a.args.workspace)
                elseif a.path == "dsp.window.move" then
                    table.insert(moves, a.args)
                end
            end,
            dsp = action("dsp"),
        }
    ''')
    lua.execute((HYPR / "60-keybinds.lua").read_text())
    lua.execute('''
        function fire(event, arg)
            for _, fn in ipairs(events[event] or {}) do fn(arg) end
        end
    ''')
    return lua


class DevtowerIntelLayoutTests(unittest.TestCase):
    def setUp(self):
        self.lua = runtime()
        self.lua.execute((HYPR / "devices/devtower-intel.lua").read_text())
        self.g = self.lua.globals()

    def test_forty_workspaces_on_the_right_monitors(self):
        ws = [r for r in self.g.workspaces.values() if int(r.workspace) <= 40]
        self.assertEqual(len(ws), 40)
        left = {12, 13, 16, 20, 29, 30}
        for rule in ws:
            wid = int(rule.workspace)
            expected = RIGHT if wid == 1 else LEFT if wid in left else CENTRE
            self.assertEqual(rule.monitor, expected, wid)
            # One default per monitor, and empty workspaces are not persisted.
            self.assertEqual(bool(rule.default), wid in (1, 2, 12), wid)
            self.assertFalse(rule.persistent, wid)
        self.assertEqual(sorted(int(r.workspace) for r in ws), list(range(1, 41)))

    def test_overflow_workspaces_41_to_99_on_centre_without_a_default(self):
        ws = [r for r in self.g.workspaces.values() if int(r.workspace) > 40]
        self.assertEqual(sorted(int(r.workspace) for r in ws), list(range(41, 100)))
        for rule in ws:
            self.assertEqual(rule.monitor, CENTRE, rule.workspace)
            self.assertFalse(rule.default, rule.workspace)
            self.assertFalse(rule.persistent, rule.workspace)

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
            "zen-beta": "12", "librewolf": "13", "firefox-devedition": "14",
            "brave-browser": "15", "aerc": "4", "aerc-keybinds": "4",
            "claws-mail": "4", "yazi": "3", "thunar": "3", "teams-for-linux": "11",
            "resolve": "20", "nixcfg-nvim": "31", "libreoffice-writer": "5",
            "libreoffice-calc": "6", "libreoffice-base": "10", "vlc": "16",
            "affinity-designer": "17", "affinity-publisher": "19",
            "termfilechooser": "unset",
            # Parked, then moved on by the window.open overflow handler.
            "unassigned-app": "special:unassigned silent",
            # nixcfg-term has no rule of its own any more.
            "nixcfg-term": "special:unassigned silent",
        }.items():
            destination = None
            for rule in rules:
                if rule.match.title is None and re.fullmatch(rule.match["class"], cls):
                    destination = rule.workspace
            self.assertEqual(destination, expected, cls)

    def test_creative_workspaces_20_to_30(self):
        # By rule name, so the Craft class strings can change independently.
        by_name = {r.name: r.workspace for r in self.g.rules.values()}
        for name, expected in {
            "intel-resolve": "20", "intel-craft-photo": "21",
            "intel-craft-vector": "22", "intel-craft-light": "23",
            "intel-craft-pdf": "24", "intel-craft-design": "25",
            "intel-craft-sound": "26", "intel-craft-word": "27",
            "intel-craft-deck": "28", "intel-craft-effect": "29",
            "intel-craft-film": "30",
        }.items():
            self.assertEqual(by_name.get(name), expected, name)
        self.assertNotIn("intel-craft-art", by_name, "ArtCraft has no Linux build")
        # 20 is Resolve's alone, and the removed nix-config terminal rule
        # stays removed.
        on_20 = [n for n, ws in by_name.items() if ws == "20"]
        self.assertEqual(on_20, ["intel-resolve"])
        self.assertNotIn("intel-nixcfg-term", by_name)

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

    def test_mail_layout_follows_the_device_override_to_4(self):
        self.lua.execute('binds.global["SUPER + E"]()')
        self.assertEqual(self.g.active_ws, 4)


class OverflowTests(unittest.TestCase):
    """The window.open handler that moves parked windows on from the holding
    special workspace."""

    def setUp(self):
        self.lua = runtime()
        self.lua.execute((HYPR / "devices/devtower-intel.lua").read_text())
        self.g = self.lua.globals()
        self.lua.execute('''
            parked = { id = -98, name = "special:unassigned", special = true }
            function open(w)
                table.insert(windows, w)
                fire("window.open", w)
                return moves[#moves]
            end
        ''')

    def test_unassigned_window_takes_41_when_nothing_is_open(self):
        move = self.lua.eval(
            'open({ address = "0x1", pid = 10, class = "unknown", '
            'floating = false, workspace = parked })')
        self.assertEqual((move.workspace, move.follow), (41, True))
        self.assertEqual(move.window.address, "0x1")

    def test_first_free_workspace_skips_busy_ones(self):
        # 41 and 42 hold windows; 43 exists but is empty; 44 is busy too.
        self.lua.execute('''
            live = {
                { id = 2, windows = 4 }, { id = 41, windows = 1 },
                { id = 42, windows = 2 }, { id = 43, windows = 0 },
                { id = 44, windows = 1 },
                { id = -98, name = "special:unassigned", windows = 1 },
            }
        ''')
        move = self.lua.eval(
            'open({ address = "0x2", pid = 11, class = "unknown", '
            'floating = false, workspace = parked })')
        self.assertEqual((move.workspace, move.follow), (43, True))
        self.lua.execute('live[4].windows = 1')
        move = self.lua.eval(
            'open({ address = "0x3", pid = 12, class = "unknown", '
            'floating = false, workspace = parked })')
        self.assertEqual(move.workspace, 45)

    def test_floating_dialog_joins_its_process_workspace(self):
        # The same process has windows on 31 and 14; 14 is active, so it wins.
        self.lua.execute('''
            active_ws = 14
            live = { { id = 31, windows = 1 }, { id = 14, windows = 1 } }
            table.insert(windows, { address = "0xa", pid = 20, workspace = { id = 31 } })
            table.insert(windows, { address = "0xb", pid = 20, workspace = { id = 14 } })
        ''')
        move = self.lua.eval(
            'open({ address = "0xc", pid = 20, class = "picker", '
            'floating = true, workspace = parked })')
        self.assertEqual((move.workspace, move.follow), (14, True))
        # With neither active, the first one found is used.
        self.lua.execute('active_ws = 7')
        move = self.lua.eval(
            'open({ address = "0xd", pid = 20, class = "picker", '
            'floating = true, workspace = parked })')
        self.assertEqual(move.workspace, 31)

    def test_dialog_ignores_special_workspaces_and_tiled_windows_get_their_own(self):
        self.lua.execute('''
            live = { { id = 31, windows = 1 } }
            table.insert(windows, { address = "0xe", pid = 30,
                workspace = { id = -99, name = "special:scratch", special = true } })
        ''')
        # Only a special workspace for this pid: the dialog gets a free one.
        move = self.lua.eval(
            'open({ address = "0xf", pid = 30, class = "dialog", '
            'floating = true, workspace = parked })')
        self.assertEqual(move.workspace, 41)
        # A second tiled Zed project does not pile onto the layout on 31.
        self.lua.execute('''
            table.insert(windows, { address = "0x10", pid = 40, workspace = { id = 31 } })
        ''')
        move = self.lua.eval(
            'open({ address = "0x11", pid = 40, class = "dev.zed.Zed", '
            'floating = false, workspace = parked })')
        self.assertEqual(move.workspace, 41)

    def test_windows_that_were_not_parked_are_left_alone(self):
        for workspace in ('{ id = 3 }', '{ id = 41 }',
                          '{ id = -99, name = "special:scratch", special = true }'):
            self.lua.eval(
                f'open({{ address = "0x20", pid = 50, class = "yazi", '
                f'floating = false, workspace = {workspace} }})')
        self.assertEqual(len(self.g.moves), 0)


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
