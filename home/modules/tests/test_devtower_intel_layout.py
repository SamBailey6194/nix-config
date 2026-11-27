"""Exercise the shared 50-workspace map, keybinds and overflow with Lua mocks,
then each device file on top: devtower-intel's monitor placement and
laptop-intel's single screen.

60-keybinds.lua and 70-windowrules.lua are loaded first and the device file
last, as Hyprland does, against the REAL 00-vars.lua.
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
            config = function() end,
            device = function() end,
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
    lua.execute((HYPR / "70-windowrules.lua").read_text())
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
        left = {12, 13, 16, 20, 21, 22, 23}
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

    def test_shift_bank_focuses_11_to_20_and_nothing_unbinds_it(self):
        log = [(e[1], e[2]) for e in self.g.log.values()]
        self.assertFalse([e for e in log if e[0] == "unbind"])
        for i in range(1, 11):
            a = self.g.binds["global"][f"SUPER + SHIFT + {i % 10}"]
            self.assertEqual((a.path, a.args.workspace), ("dsp.focus", 10 + i))

    def test_ctrl_alt_and_ctrl_shift_banks_focus_21_to_50_and_super_0_is_still_10(self):
        for prefix, offset in (("", 0), ("CTRL + ", 20), ("ALT + ", 30), ("CTRL + SHIFT + ", 40)):
            for i in range(1, 11):
                a = self.g.binds["global"][f"SUPER + {prefix}{i % 10}"]
                self.assertEqual((a.path, a.args.workspace), ("dsp.focus", offset + i))
        a = self.g.binds["global"]["SUPER + 0"]
        self.assertEqual(a.args.workspace, 10)

    def test_move_window_submap_covers_1_to_50_and_escape_resets(self):
        enter = self.g.binds["global"]["SUPER + period"]
        self.assertEqual((enter.path, enter.args), ("dsp.submap", "move-window"))
        sub = self.g.binds["move-window"]
        for prefix, offset in (("", 0), ("SHIFT + ", 10), ("CTRL + ", 20), ("ALT + ", 30),
                               ("CTRL + SHIFT + ", 40)):
            for i in range(1, 11):
                a = sub[f"{prefix}{i % 10}"]
                self.assertEqual((a.path, a.args.workspace), ("dsp.window.move", offset + i))
        self.assertEqual((sub["escape"].path, sub["escape"].args), ("dsp.submap", "reset"))

    def test_catch_all_comes_first_and_specific_rules_win(self):
        # Float, opacity and size rules set no workspace; only placement counts.
        rules = [r for r in self.g.rules.values() if r.workspace is not None]
        catch_all = [i for i, r in enumerate(rules) if r.match["class"] == ".*"]
        self.assertEqual(catch_all, [0], "catch-all registered before every specific rule")
        # Apply matching class-only rules in registration order, as Hyprland does.
        for cls, expected in {
            "zen-beta": "12", "librewolf": "13", "firefox-devedition": "14",
            "brave-browser": "15", "aerc": "4", "aerc-keybinds": "4",
            "yazi": "3", "teams-for-linux": "11", "zoom": "11", "Slack": "11",
            "resolve": "20", "nixcfg-nvim": "31",
            "libreoffice-startcenter": "5", "libreoffice-writer": "5",
            "libreoffice-impress": "6", "libreoffice-calc": "7",
            "org.pwmt.zathura": "8", "libreoffice-math": "10",
            "libreoffice-base": "10", "vlc": "16", "gimp": "17",
            "libreoffice-draw": "18", "REAPER": "24",
            "org.audacityteam.Audacity": "24", "Audacity 4": "24",
            "Blender": "25", "Chromium": "30", "chromium": "30",
            "replit": "41",
            "termfilechooser": "unset",
            # No rules of their own any more: parked, then overflow (51+).
            "affinity-designer": "special:unassigned silent",
            "designer.exe": "special:unassigned silent",
            "claws-mail": "special:unassigned silent",
            "thunar": "special:unassigned silent",
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
        # The nix-config Zed window needs its title as well as its class.
        editor = {r.name: r for r in rules}["workspace-nixcfg-editor"]
        self.assertEqual((editor.workspace, editor.match.title), ("31", "^(nix-config)$"))

    def test_paired_workspaces_5_to_30(self):
        # By rule name, so the class strings can change independently.
        by_name = {r.name: r.workspace for r in self.g.rules.values()
                   if r.workspace is not None}
        expected = {
            "workspace-office-startcenter": "5", "workspace-office-writer": "5",
            "workspace-craft-word": "5",
            "workspace-office-impress": "6", "workspace-craft-deck": "6",
            "workspace-office-calc": "7", "workspace-craft-grid": "7",
            "workspace-craft-pdf": "8", "workspace-viewer-zathura": "8",
            "workspace-craft-design": "9",
            "workspace-office-math": "10", "workspace-office-base": "10",
            "workspace-comms-slack": "11",
            "workspace-craft-photo": "17", "workspace-creative-gimp": "17",
            "workspace-office-draw": "18", "workspace-craft-vector": "18",
            "workspace-craft-light": "19",
            "workspace-resolve": "20", "workspace-craft-film": "21",
            "workspace-craft-effect": "22", "workspace-craft-ani": "23",
            "workspace-craft-sound": "24", "workspace-creative-reaper": "24",
            "workspace-creative-audacity": "24",
            "workspace-creative-blender": "25",
            "workspace-craft-material": "26", "workspace-craft-texture": "27",
            "workspace-craft-cad": "28", "workspace-craft-fig": "29",
            "workspace-testing-playwright": "30",
        }
        for name, ws in expected.items():
            self.assertEqual(by_name.get(name), ws, name)
        # Nothing else on 5-10 or 17-30 (11-16 are comms, browsers, viewers).
        paired = {n for n, ws in by_name.items()
                  if ws.isdigit() and (5 <= int(ws) <= 10 or 17 <= int(ws) <= 30)}
        self.assertEqual(paired, {n for n, ws in expected.items()
                                  if not 11 <= int(ws) <= 16})
        # 41 is Replit alone; nothing on 42-50: they are spares.
        self.assertEqual([n for n, ws in by_name.items() if ws == "41"], ["workspace-dev-replit"])
        self.assertFalse([n for n, ws in by_name.items() if ws.isdigit() and 42 <= int(ws) <= 50])
        self.assertNotIn("workspace-craft-art", by_name, "ArtCraft has no Linux build")
        # Affinity stays installed but has no workspace; Thunar and Claws Mail
        # are gone; the removed nix-config terminal rule stays removed.
        for name in ("workspace-affinity-designer", "workspace-affinity-photo",
                     "workspace-affinity-publisher", "workspace-files-thunar",
                     "workspace-mail-claws", "workspace-nixcfg-term"):
            self.assertNotIn(name, by_name)

    def test_playwright_rule_matches_chromium_only(self):
        rule = {r.name: r for r in self.g.rules.values()}["workspace-testing-playwright"]
        for cls in ("chromium", "Chromium", "chromium-browser"):
            self.assertTrue(re.fullmatch(rule.match["class"], cls), cls)
        for cls in ("brave-browser", "google-chrome", "firefox-devedition"):
            self.assertIsNone(re.fullmatch(rule.match["class"], cls), cls)

    def test_craft_rules_match_the_packaged_app_ids(self):
        # Classes seen with hyprctl clients, plus the shipped StartupWMClass.
        rules = [r for r in self.g.rules.values() if r.workspace is not None]
        by_name = {r.name: r for r in rules}
        expected = {
            "photo": ("17", ("ai.storyteller.photocraft", "photocraft")),
            "vector": ("18", ("ai.storyteller.vectorcraft",)),
            "light": ("19", ("ai.storyteller.lightcraft",)),
            "pdf": ("8", ("ai.storyteller.pdfcraft",)),
            "design": ("9", ("ai.storyteller.designcraft",)),
            "sound": ("24", ("ai.storyteller.soundcraft",)),
            "word": ("5", ("ai.storyteller.wordcraft",)),
            "deck": ("6", ("ai.storyteller.deckcraft",)),
            "effect": ("22", ("ai.storyteller.effectcraft",)),
            "film": ("21", ("ai.storyteller.filmcraft",)),
            "cad": ("28", ("ai.storyteller.cadcraft",)),
            "fig": ("29", ("ai.storyteller.figcraft",)),
            "grid": ("7", ("ai.storyteller.gridcraft",)),
            "ani": ("23", ("ai.storyteller.anicraft",)),
            "material": ("26", ("ai.storyteller.materialcraft", "materialcraft", "MaterialCraft")),
            "texture": ("27", ("ai.storyteller.texturecraft", "texturecraft", "TextureCraft")),
        }
        for app, (ws, ids) in expected.items():
            rule = by_name[f"workspace-craft-{app}"]
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

    def test_every_app_in_the_map_has_a_key(self):
        enter = self.g.binds["global"]["SUPER + A"]
        self.assertEqual((enter.path, enter.args), ("dsp.submap", "launch"))
        launch = self.g.binds["launch"]
        self.assertEqual((launch["escape"].path, launch["escape"].args), ("dsp.submap", "reset"))
        commands = {k: a.args for k, a in launch.items() if a.path == "dsp.exec_cmd"}
        # Rule name -> the command that opens it, through SUPER + A or a direct key.
        opens = {
            "office-startcenter": "libreoffice", "office-writer": "libreoffice --writer",
            "craft-word": "wordcraft", "office-impress": "libreoffice --impress",
            "craft-deck": "deckcraft", "office-calc": "libreoffice --calc",
            "craft-grid": "gridcraft", "viewer-zathura": "zathura", "craft-pdf": "pdfcraft",
            "craft-design": "designcraft", "office-math": "libreoffice --math",
            "office-base": "libreoffice --base", "comms-slack": "slack",
            "viewer-vlc": "vlc", "viewer-mpv": "mpv --player-operation-mode=pseudo-gui",
            "creative-gimp": "gimp", "craft-photo": "photocraft",
            "office-draw": "libreoffice --draw", "craft-vector": "vectorcraft",
            "craft-light": "lightcraft", "resolve": "davinci-resolve-studio",
            "craft-film": "filmcraft", "craft-effect": "effectcraft", "craft-ani": "anicraft",
            "craft-sound": "soundcraft", "creative-reaper": "reaper",
            "creative-audacity": "audacity", "creative-blender": "blender",
            "craft-material": "materialcraft", "craft-texture": "texturecraft",
            "craft-cad": "cadcraft", "craft-fig": "figcraft",
            "dev-replit": "replit",
        }
        self.assertEqual(sorted(commands.values()), sorted(opens.values()))
        # Apps with a direct key of their own, or no key by design.
        direct = {
            "files-yazi": "SUPER + F", "mail-aerc": "SUPER + E",
            "comms-teams-for-linux": "SUPER + T", "comms-zoom": "SUPER + C",
            "browser-zen": "SUPER + W", "browser-brave": "SUPER + SHIFT + W",
            "browser-librewolf": "SUPER + ALT + W",
            "browser-firefox-devedition": "SUPER + CTRL + W",
            "nixcfg-editor": "SUPER + SHIFT + Z", "nixcfg-nvim": "SUPER + SHIFT + RETURN",
        }
        for key in direct.values():
            self.assertIn(key, self.g.binds["global"], key)
        no_key = {"mail-aerc-keybinds", "mail-calendar", "viewer-imv",
                  "testing-playwright", "popup-file-picker", "popup-ripdrag"}
        names = {a.name for a in self.lua.eval('require("00-vars")').workspaceAssignments.values()}
        self.assertEqual(names, set(opens) | set(direct) | no_key)
        # SUPER + A itself was free: nothing else claims it.
        self.assertEqual(sum(1 for e in self.g.log.values() if e[2] == "SUPER + A"), 1)

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

    def test_unassigned_window_takes_51_when_nothing_is_open(self):
        # 41-50 are keyed spares, so
        # overflow starts after them even while they are empty.
        move = self.lua.eval(
            'open({ address = "0x1", pid = 10, class = "unknown", '
            'floating = false, workspace = parked })')
        self.assertEqual((move.workspace, move.follow), (51, True))
        self.assertEqual(move.window.address, "0x1")

    def test_first_free_workspace_skips_busy_ones(self):
        # 51 and 52 hold windows; 53 exists but is empty; 54 is busy too.
        # 41 (a spare in use) being busy or 47 (a spare) being empty changes nothing.
        self.lua.execute('''
            live = {
                { id = 2, windows = 4 }, { id = 41, windows = 1 },
                { id = 47, windows = 0 },
                { id = 51, windows = 1 },
                { id = 52, windows = 2 }, { id = 53, windows = 0 },
                { id = 54, windows = 1 },
                { id = -98, name = "special:unassigned", windows = 1 },
            }
        ''')
        move = self.lua.eval(
            'open({ address = "0x2", pid = 11, class = "unknown", '
            'floating = false, workspace = parked })')
        self.assertEqual((move.workspace, move.follow), (53, True))
        self.lua.execute('live[6].windows = 1')
        move = self.lua.eval(
            'open({ address = "0x3", pid = 12, class = "unknown", '
            'floating = false, workspace = parked })')
        self.assertEqual(move.workspace, 55)

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
        self.assertEqual(move.workspace, 51)
        # A second tiled Zed project does not pile onto the layout on 31.
        self.lua.execute('''
            table.insert(windows, { address = "0x10", pid = 40, workspace = { id = 31 } })
        ''')
        move = self.lua.eval(
            'open({ address = "0x11", pid = 40, class = "dev.zed.Zed", '
            'floating = false, workspace = parked })')
        self.assertEqual(move.workspace, 51)

    def test_windows_that_were_not_parked_are_left_alone(self):
        for workspace in ('{ id = 3 }', '{ id = 51 }',
                          '{ id = -99, name = "special:scratch", special = true }'):
            self.lua.eval(
                f'open({{ address = "0x20", pid = 50, class = "yazi", '
                f'floating = false, workspace = {workspace} }})')
        self.assertEqual(len(self.g.moves), 0)


class LaptopIntelTests(unittest.TestCase):
    """The same shared map on one screen, plus laptop-intel's ws1 dashboard."""

    def setUp(self):
        self.lua = runtime()
        self.lua.execute((HYPR / "devices/laptop-intel.lua").read_text())
        self.g = self.lua.globals()

    def destination(self, cls):
        found = None
        for r in self.g.rules.values():
            if r.workspace is not None and r.match.title is None \
                    and re.fullmatch(r.match["class"], cls):
                found = r.workspace
        return found

    def test_no_monitor_placement(self):
        self.assertEqual(len(self.g.workspaces), 0)

    def test_shared_map_applies_and_the_dashboard_wins_ws1(self):
        for cls, ws in {"yazi": "3", "aerc": "4", "libreoffice-writer": "5",
                        "zen-beta": "12", "ai.storyteller.filmcraft": "21",
                        "nixcfg-nvim": "31", "ws1-keybinds": "1 silent",
                        "ws1-monitor": "1 silent",
                        "unassigned-app": "special:unassigned silent"}.items():
            self.assertEqual(self.destination(cls), ws, cls)

    def test_same_keys_and_mail_workspace(self):
        a = self.g.binds["global"]["SUPER + SHIFT + 1"]
        self.assertEqual((a.path, a.args.workspace), ("dsp.focus", 11))
        a = self.g.binds["move-window"]["CTRL + SHIFT + 0"]
        self.assertEqual((a.path, a.args.workspace), ("dsp.window.move", 50))
        self.lua.execute('binds.global["SUPER + E"]()')
        self.assertEqual(self.g.active_ws, 4)
        self.assertEqual(self.g.env["DEV_LAYOUT_NIX_CONFIG_WS"], "31")


if __name__ == "__main__":
    unittest.main()
