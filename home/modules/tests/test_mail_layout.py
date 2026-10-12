"""Exercise the SUPER + E mail layout (aerc + keybind sheet) with Lua mocks."""
from pathlib import Path
import unittest
from lupa import LuaRuntime

KEYBINDS = Path(__file__).resolve().parents[3] / "config/hypr/60-keybinds.lua"


class MailLayoutTests(unittest.TestCase):
    def setUp(self):
        self.lua = LuaRuntime()
        self.lua.execute('''
            events, launches, windows, timers, binds, swaps, focused = {}, {}, {}, {}, {}, {}, {}
            active_ws = 3
            package.preload["00-vars"] = function() return { mod = "SUPER" } end

            -- Any hl.dsp.<a>.<b>(args) the file builds at load time returns
            -- a tagged table, so the non-mail binds load without real actions.
            local function action(path)
                return setmetatable({}, {
                    __index = function(_, k) return action(path .. "." .. k) end,
                    __call = function(_, args) return { path = path, args = args } end,
                })
            end

            hl = {
                bind = function(key, fn, _) binds[key] = fn end,
                on = function(event, fn) events[event] = fn end,
                exec_cmd = function(cmd) table.insert(launches, cmd) end,
                timer = function(fn, _) table.insert(timers, fn) end,
                get_active_workspace = function() return { id = active_ws } end,
                get_windows = function(q)
                    return windows[q.class] and { windows[q.class] } or {}
                end,
                dispatch = function(a)
                    if a.path == "dsp.focus" then
                        active_ws = a.args.workspace
                        table.insert(focused, a.args.workspace)
                    elseif a.path == "dsp.window.move" then
                        a.args.window.workspace = { id = a.args.workspace }
                    elseif a.path == "dsp.window.swap" then
                        local w, t = a.args.window, a.args.target
                        w.at, t.at = t.at, w.at
                        table.insert(swaps, a)
                    end
                end,
                dsp = action("dsp"),
            }

            function open(class, x, y)
                windows[class] = { class = class, workspace = { id = 6 },
                                   at = { x = x, y = y }, floating = false, fullscreen = 0 }
                events["window.open"](windows[class])
            end
        ''')
        self.lua.execute(KEYBINDS.read_text())

    def test_launches_both_panes_once_and_focuses_workspace_6(self):
        self.lua.execute('''
            local mail = binds["SUPER + E"]
            mail(); mail()
            assert(#launches == 2, "a double press must not launch twice")
            assert(launches[1] == "kitty --class aerc -e aerc")
            assert(launches[2]:find("--class aerc%-keybinds") and launches[2]:find("aerc/KEYBINDS.md"))
            assert(active_ws == 6 and #focused == 1, "focus 6 once, then stay")
        ''')

    def test_reopens_only_the_missing_pane_and_moves_strays_back(self):
        self.lua.execute('''
            local mail = binds["SUPER + E"]
            mail()
            open("aerc", 0, 0); open("aerc-keybinds", 960, 0)
            windows["aerc-keybinds"] = nil           -- `q` in the sheet
            windows["aerc"].workspace.id = 9         -- aerc moved away
            mail()
            assert(#launches == 3 and launches[3]:find("aerc%-keybinds"))
            assert(windows["aerc"].workspace.id == 6)
        ''')

    def test_aerc_ends_up_first_side_by_side_and_stacked(self):
        self.lua.execute('''
            local mail = binds["SUPER + E"]
            mail()
            -- Landscape: the sheet came out on the left.
            open("aerc-keybinds", 0, 0); open("aerc", 960, 0)
            assert(#swaps == 1 and windows["aerc"].at.x == 0)

            -- Portrait (devtower-intel's ws6 monitor): the sheet came out on top.
            windows = {}; swaps = {}
            open("aerc-keybinds", 0, 0); open("aerc", 0, 960)
            assert(#swaps == 1 and windows["aerc"].at.y == 0)

            -- Already in order: no swap.
            windows = {}; swaps = {}
            open("aerc", 0, 0); open("aerc-keybinds", 0, 960)
            assert(#swaps == 0)
        ''')

    def test_diagonal_panes_settle_after_one_swap(self):
        self.lua.execute('''
            local mail = binds["SUPER + E"]
            mail()
            -- Claws shares ws6, so aerc sits bottom-left and the sheet top-right.
            open("aerc", 0, 540); open("aerc-keybinds", 960, 0)
            mail(); mail(); mail()
            assert(#swaps == 0, "aerc is already left of the sheet")

            windows = {}; swaps = {}
            open("aerc", 960, 0); open("aerc-keybinds", 0, 540)
            mail(); mail(); mail()
            assert(#swaps == 1, "one swap, then stable")
        ''')

    def test_floating_pane_is_never_swapped(self):
        self.lua.execute('''
            binds["SUPER + E"]()
            open("aerc-keybinds", 0, 0)
            windows["aerc-keybinds"].floating = true
            open("aerc", 960, 0)
            assert(#swaps == 0)
        ''')

    def test_claws_is_on_shift_e(self):
        self.lua.execute('''
            local a = binds["SUPER + SHIFT + E"]
            assert(a.path == "dsp.exec_cmd" and a.args == "claws-mail")
        ''')


if __name__ == "__main__":
    unittest.main()
