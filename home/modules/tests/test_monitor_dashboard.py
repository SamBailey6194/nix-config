"""Exercise monitor geometry and dashboard launch/reopen logic with Lua mocks."""
from pathlib import Path
import re
import unittest
from lupa import LuaRuntime

DEVICES = Path(__file__).resolve().parents[3] / "config/hypr/devices"


class DashboardTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute('''
            rules, monitors, workspaces, events, launches, windows, timers = {}, {}, {}, {}, {}, {}, {}
            package.preload["00-vars"] = function() return { mod = "SUPER" } end
            hl = {
                monitor = function(r) table.insert(monitors, r) end,
                workspace_rule = function(r) table.insert(workspaces, r) end,
                window_rule = function(r) table.insert(rules, r) end,
                get_active_workspace = function() return {id=1} end,
                get_windows = function(q) return windows[q.class] and {windows[q.class]} or {} end,
                exec_cmd = function(cmd) table.insert(launches, cmd) end,
                timer = function(fn, _) table.insert(timers, fn) end,
                on = function(event, fn) events[event] = fn end,
                bind = function(_, fn, _) dashboard = fn end,
                dispatch = function(action)
                    if action.window then action.window.workspace = {id=action.workspace} end
                end,
                dsp = { focus = function(x) return x end, window = {move = function(x) return x end} },
            }
        ''')

    def test_requested_monitor_mapping_and_logical_geometry(self):
        self.lua.execute('package.preload["00-vars"] = nil')
        self.lua.globals().package.path = str(DEVICES.parent / "?.lua") + ";" + self.lua.globals().package.path
        self.lua.execute((DEVICES / "devtower-intel.lua").read_text())
        self.lua.execute('''
            assert(#monitors == 3 and #workspaces == 10)
            assert(monitors[1].scale == 1.5)
            assert(monitors[2].position == "2560x0")
            assert(monitors[3].position == "5120x0" and monitors[3].transform == 1)
            local expected = {"right", "centre", "centre", "centre", "centre", "right", "left", "centre", "centre", "centre"}
            local outputs = {left=monitors[1].output, centre=monitors[2].output, right=monitors[3].output}
            for _, rule in ipairs(workspaces) do
                assert(rule.monitor == outputs[expected[tonumber(rule.workspace)]])
                assert(not rule.persistent)
            end
        ''')
        # Apply matching rules in registration order, as Hyprland does.
        for cls, expected in {
            "brave-browser": "10", "firefox-devedition": "10",
            "zen-beta": "7", "librewolf": "10", "resolve": "8",
            "claws-mail": "6", "unassigned-app": "10",
        }.items():
            destination = None
            for _, rule in self.lua.globals().rules.items():
                if rule.match.title is None and re.fullmatch(rule.match['class'], cls):
                    destination = rule.workspace
            self.assertEqual(destination, expected, cls)

    def test_three_nonoverlapping_vertical_panes_and_reopen_without_duplicates(self):
        self.lua.execute((DEVICES / "devtower-intel-dashboard.lua").read_text())
        self.lua.execute('''
            assert(#rules == 3)
            monitor_w, monitor_h = 1080, 1920
            local bottom = 0
            for _, rule in ipairs(rules) do
                local width = assert(load("return " .. rule.size[1]))()
                local height = assert(load("return " .. rule.size[2]))()
                local y = assert(load("return " .. rule.move[2]))()
                assert(width == 1060 and y >= bottom and y + height <= monitor_h - 10)
                bottom = y + height
            end
            dashboard(); dashboard()
            assert(#launches == 3)
            assert(launches[1]:find("less") and launches[2]:find("btop") and launches[3]:find("nvtop"))
            for _, class in ipairs({"ws1-keybinds", "ws1-monitor", "ws1-gpu"}) do
                windows[class] = {class=class, workspace={id=1}}
                events["window.open"](windows[class])
            end
            dashboard(); assert(#launches == 3)
            windows["ws1-monitor"].workspace.id = 9
            dashboard(); assert(windows["ws1-monitor"].workspace.id == 1)
            windows["ws1-gpu"] = nil
            dashboard(); assert(#launches == 4)
        ''')


if __name__ == "__main__":
    unittest.main()
