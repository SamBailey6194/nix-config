"""Exercise monitor geometry and dashboard launch/reopen logic with Lua mocks."""
from pathlib import Path
import unittest
from lupa import LuaRuntime

DEVICES = Path(__file__).resolve().parents[3] / "config/hypr/devices"


class DashboardTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute('''
            rules, monitors, workspaces, events, launches, windows, timers = {}, {}, {}, {}, {}, {}, {}
            binds, active_ws, exec_rules = {}, 1, {}
            package.preload["00-vars"] = function() return { mod = "SUPER" } end
            hl = {
                monitor = function(r) table.insert(monitors, r) end,
                workspace_rule = function(r) table.insert(workspaces, r) end,
                window_rule = function(r) table.insert(rules, r) end,
                get_active_workspace = function() return {id=active_ws} end,
                -- windows is keyed by class; no filter lists every window.
                get_windows = function(q)
                    if q and q.class then
                        return windows[q.class] and {windows[q.class]} or {}
                    end
                    local all = {}
                    for _, w in pairs(windows) do table.insert(all, w) end
                    return all
                end,
                get_workspaces = function() return {} end,
                exec_cmd = function(cmd, rules)
                    table.insert(launches, cmd)
                    if rules then exec_rules[cmd] = rules end
                end,
                timer = function(fn, _) table.insert(timers, fn) end,
                on = function(event, fn) events[event] = fn end,
                bind = function(key, fn, _) binds[key] = fn end,
                dispatch = function(action)
                    if action.window then
                        action.window.workspace = {id=action.workspace}
                    elseif action.workspace then
                        active_ws = action.workspace
                    end
                end,
                env = function() end,
                unbind = function() end,
                define_submap = function(_, _, fn) fn() end,
                dsp = { focus = function(x) return x end, window = {move = function(x) return x end},
                        submap = function(x) return x end },
            }
        ''')

    def test_requested_monitor_mapping_and_logical_geometry(self):
        self.lua.execute('package.preload["00-vars"] = nil')
        self.lua.globals().package.path = str(DEVICES.parent / "?.lua") + ";" + self.lua.globals().package.path
        self.lua.execute((DEVICES / "devtower-intel.lua").read_text())
        self.lua.execute('''
            -- 1-40 plus the 41-99 overflow workspaces.
            assert(#monitors == 3 and #workspaces == 99)
            assert(monitors[1].scale == 1.5)
            assert(monitors[2].position == "2560x0")
            assert(monitors[3].position == "5120x0" and monitors[3].transform == 1)
        ''')
        # The 40-workspace map, keybinds and window rules are covered in
        # test_devtower_intel_layout.py.

    def test_three_nonoverlapping_vertical_panes_and_reopen_without_duplicates(self):
        self.lua.execute((DEVICES / "devtower-intel-dashboard.lua").read_text())
        self.lua.execute('''
            assert(#rules == 7)
            monitor_w, monitor_h = 1080, 1920
            local dashboard = binds["SUPER + Escape"]
            local bottom = 0
            for i = 1, 3 do
                local rule = rules[i]
                assert(rule.workspace == "1 silent" and rule.float)
                local width = assert(load("return " .. rule.size[1]))()
                local height = assert(load("return " .. rule.size[2]))()
                local y = assert(load("return " .. rule.move[2]))()
                assert(width == 1060 and y >= bottom and y + height <= monitor_h - 10)
                bottom = y + height
            end
            dashboard(); dashboard()
            assert(#launches == 3 and active_ws == 1)
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

    def test_ws2_four_terminals_in_a_two_by_two_grid(self):
        self.lua.execute((DEVICES / "devtower-intel-dashboard.lua").read_text())
        self.lua.execute('''
            local grid = {}
            for _, rule in ipairs(rules) do
                if rule.name:find("ws2%-term") then table.insert(grid, rule) end
            end
            assert(#grid == 4)
            local expected_x = { "10", "18+(monitor_w-28)/2", "10", "18+(monitor_w-28)/2" }
            local expected_y = { "50", "50", "58+(monitor_h-68)/2", "58+(monitor_h-68)/2" }
            for i, rule in ipairs(grid) do
                assert(rule.name == "intel-dashboard-ws2-term-" .. i)
                assert(rule.match.class == "^ws2-term-" .. i .. "$")
                assert(rule.workspace == "2 silent" and rule.float)
                assert(rule.opacity == "0.95 0.95")
                assert(rule.size[1] == "(monitor_w-28)/2" and rule.size[2] == "(monitor_h-68)/2")
                assert(rule.move[1] == expected_x[i] and rule.move[2] == expected_y[i])
            end

            -- On the 2560x1440 centre monitor the panes tile without
            -- overlapping: 10px sides and bottom, 50px top, 8px gaps.
            monitor_w, monitor_h = 2560, 1440
            local function eval(e) return assert(load("return " .. e))() end
            local boxes = {}
            for _, rule in ipairs(grid) do
                table.insert(boxes, { x = eval(rule.move[1]), y = eval(rule.move[2]),
                                      w = eval(rule.size[1]), h = eval(rule.size[2]) })
            end
            assert(boxes[1].x == 10 and boxes[1].y == 50)
            assert(boxes[2].x == boxes[1].x + boxes[1].w + 8)
            assert(boxes[3].y == boxes[1].y + boxes[1].h + 8)
            assert(boxes[4].x + boxes[4].w == monitor_w - 10)
            assert(boxes[4].y + boxes[4].h == monitor_h - 10)
        ''')

    def test_ws2_refills_without_duplicate_launches_while_pending(self):
        self.lua.execute((DEVICES / "devtower-intel-dashboard.lua").read_text())
        self.lua.execute('''
            local grid = binds["SUPER + SHIFT + Escape"]
            grid(); grid()
            assert(#launches == 4 and active_ws == 2)
            for i, cmd in ipairs(launches) do
                -- Plain login shells in $HOME, no -e command.
                assert(cmd == "kitty --directory ~ --class ws2-term-" .. i)
            end
            for i = 1, 4 do
                local class = "ws2-term-" .. i
                windows[class] = {class=class, workspace={id=2}}
                events["window.open"](windows[class])
            end
            grid(); assert(#launches == 4)
            -- A stray pane is gathered back, a closed one is relaunched once.
            windows["ws2-term-3"].workspace.id = 41
            windows["ws2-term-2"] = nil
            grid(); grid()
            assert(windows["ws2-term-3"].workspace.id == 2)
            assert(#launches == 5 and launches[5] == "kitty --directory ~ --class ws2-term-2")
            -- The pending flag clears on its 5 s timer if no window opens.
            for _, fn in ipairs(timers) do fn() end
            grid(); assert(#launches == 6)
        ''')

    def test_login_builds_both_groups_and_ends_on_the_centre_terminals(self):
        self.lua.execute((DEVICES / "devtower-intel-dashboard.lua").read_text())
        self.lua.execute('''
            events["hyprland.start"]()
            -- 4 login apps, then 3 dashboard panes and 4 terminals.
            assert(#launches == 11 and active_ws == 2)
            assert(launches[5]:find("ws1%-keybinds") and launches[11]:find("ws2%-term%-4"))
        ''')

    def test_login_apps_open_silently_on_their_workspaces(self):
        self.lua.execute((DEVICES / "devtower-intel-dashboard.lua").read_text())
        self.lua.execute('''
            events["hyprland.start"]()
            local expected = {
                ["kitty --class yazi yazi"] = "3 silent",
                ["kitty --class aerc -e aerc"] = "4 silent",
                ["kitty --class aerc-keybinds -e less ~/.config/aerc/KEYBINDS.md"] = "4 silent",
                ["zen-beta"] = "12 silent",
            }
            for cmd, ws in pairs(expected) do
                assert(exec_rules[cmd] and exec_rules[cmd].workspace == ws, cmd)
            end
            -- No Claws Mail, Teams or Zoom at login.
            for _, cmd in ipairs(launches) do
                assert(not cmd:find("claws") and not cmd:find("teams") and not cmd:find("zoom"), cmd)
            end
        ''')


if __name__ == "__main__":
    unittest.main()
