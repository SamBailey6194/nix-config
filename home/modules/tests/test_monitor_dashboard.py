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
            binds, active_ws, exec_rules, swaps = {}, 1, {}, {}
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
                    if action.swap then
                        table.insert(swaps, action)
                        action.window.at, action.target.at = action.target.at, action.window.at
                    elseif action.window then
                        action.window.workspace = {id=action.workspace}
                    elseif action.workspace then
                        active_ws = action.workspace
                    end
                end,
                env = function() end,
                unbind = function() end,
                define_submap = function(_, _, fn) fn() end,
                dsp = { focus = function(x) return x end,
                        window = {move = function(x) return x end,
                                  swap = function(x) x.swap = true; return x end},
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

    def test_two_nonoverlapping_vertical_panes_and_reopen_without_duplicates(self):
        self.lua.execute((DEVICES / "devtower-intel-dashboard.lua").read_text())
        self.lua.execute('''
            assert(#rules == 6)
            monitor_w, monitor_h = 1080, 1920
            local dashboard = binds["SUPER + Escape"]
            local bottom = 0
            for i = 1, 2 do
                local rule = rules[i]
                assert(rule.workspace == "1 silent" and rule.float)
                local width = assert(load("return " .. rule.size[1]))()
                local height = assert(load("return " .. rule.size[2]))()
                local y = assert(load("return " .. rule.move[2]))()
                assert(width == 1060 and y >= bottom and y + height <= monitor_h - 10)
                bottom = y + height
            end
            -- The second pane ends on the bottom margin.
            assert(bottom == monitor_h - 10)
            dashboard(); dashboard()
            assert(#launches == 2 and active_ws == 1)
            assert(launches[1]:find("btop") and launches[2]:find("nvtop"))
            for _, cmd in ipairs(launches) do assert(not cmd:find("KEYBINDS"), cmd) end
            for _, class in ipairs({"ws1-monitor", "ws1-gpu"}) do
                windows[class] = {class=class, workspace={id=1}}
                events["window.open"](windows[class])
            end
            dashboard(); assert(#launches == 2)
            windows["ws1-monitor"].workspace.id = 9
            dashboard(); assert(windows["ws1-monitor"].workspace.id == 1)
            windows["ws1-gpu"] = nil
            dashboard(); assert(#launches == 3)
        ''')

    def test_ws2_four_terminals_tile_instead_of_floating(self):
        self.lua.execute((DEVICES / "devtower-intel-dashboard.lua").read_text())
        self.lua.execute('''
            local grid = {}
            for _, rule in ipairs(rules) do
                if rule.name:find("ws2%-term") then table.insert(grid, rule) end
            end
            assert(#grid == 4)
            for i, rule in ipairs(grid) do
                assert(rule.name == "intel-dashboard-ws2-term-" .. i)
                assert(rule.match.class == "^ws2-term-" .. i .. "$")
                assert(rule.workspace == "2 silent")
                assert(rule.opacity == "0.95 0.95")
                -- Tiled by dwindle: no float, size or move.
                assert(rule.float == nil and rule.size == nil and rule.move == nil)
            end
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
            -- 5 login apps, then 2 dashboard panes and 4 terminals.
            assert(#launches == 11 and active_ws == 2)
            assert(launches[6]:find("ws1%-monitor") and launches[11]:find("ws2%-term%-4"))
        ''')

    def test_login_apps_open_silently_on_their_workspaces(self):
        self.lua.execute((DEVICES / "devtower-intel-dashboard.lua").read_text())
        self.lua.execute('''
            events["hyprland.start"]()
            local expected = {
                ["kitty --class yazi yazi"] = "3 silent",
                ["kitty --class aerc -e aerc"] = "4 silent",
                ["kitty --class khal -e khal interactive"] = "4 silent",
                ["zen-beta"] = "12 silent",
                ["brave"] = "15 silent",
            }
            for cmd, ws in pairs(expected) do
                assert(exec_rules[cmd] and exec_rules[cmd].workspace == ws, cmd)
            end
            -- No Claws Mail, Teams, Zoom or keybind sheets at login.
            for _, cmd in ipairs(launches) do
                assert(not cmd:find("claws") and not cmd:find("teams") and not cmd:find("zoom"), cmd)
                assert(not cmd:find("KEYBINDS"), cmd)
            end
        ''')

    def test_aerc_is_swapped_left_of_khal_once_both_tile_on_ws4(self):
        self.lua.execute((DEVICES / "devtower-intel-dashboard.lua").read_text())
        self.lua.execute('''
            local function win(class, x)
                return {class=class, workspace={id=4}, floating=false, fullscreen=0, at={x=x, y=50}}
            end
            windows["khal"] = win("khal", 10)
            events["window.open"](windows["khal"]); assert(#swaps == 0)
            windows["aerc"] = win("aerc", 1290)
            events["window.open"](windows["aerc"])
            assert(#swaps == 1 and windows["aerc"].at.x == 10 and windows["khal"].at.x == 1290)
            -- Already in order: no further swap.
            events["window.open"](windows["aerc"]); assert(#swaps == 1)
            -- A floated pane is never swapped.
            windows["aerc"].at.x, windows["khal"].at.x = 1290, 10
            windows["khal"].floating = true
            events["window.open"](windows["aerc"]); assert(#swaps == 1)
        ''')


if __name__ == "__main__":
    unittest.main()
