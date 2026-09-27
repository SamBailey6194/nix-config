Source tapes/_shared/settings.tape
Output media/20-session-browser-actions/20-session-browser-actions.gif
Output media/20-session-browser-actions/20-session-browser-actions.mp4
Require nvim
Require uv
# The browser and claudecode.nvim both read these: the synthetic stores (and
# claudecode.nvim's IDE lock file) stay inside the throwaway copy.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/20-session-browser-actions/stores/claude"
Env CODEX_HOME "/tmp/nvim-course/20-session-browser-actions/stores/codex"
# The app shows times in local time; pin the zone lessons 18 and 19 use.
Env TZ "Europe/London"

# tapes/20-session-browser-actions.tape - Lesson 20: session-browser SB7.
# build_launch() and run() in Neovim, then the browser on synthetic sessions:
# Enter hands the terminal to a stand-in claude and codex and gets it back,
# Enter on a Kitty row starts a stand-in kitty detached, and c copies the
# command. Finally the stand-ins' output behind the app, and their log.
#
# Records examples/session-browser/SB7 - no tags or course progress needed.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/20-session-browser-actions.tape
# `vhs --version` must print 0.12.1, which the config builds: 0.12.0 exits 0
# and writes no GIF, MP4 or PNG (charmbracelet/vhs#787). Afterwards, check
# that media/20-session-browser-actions/ really holds the GIF, the MP4 and the
# seven PNGs.
#
# The tape never reads your capstone or writes to the repo. Its hidden setup
# copies the worked example examples/session-browser/SB7 (a uv project) to
# /tmp/nvim-course/20-session-browser-actions/python/session-browser and works
# only there: `uv sync --frozen` creates the copy's own .venv from its
# uv.lock. If the copy or uv sync fails, the setup never prints READY and VHS
# stops with a Wait timeout.
#
# NOTHING REAL CAN START, AND NOTHING PRIVATE IS SHOWN:
#   - The stores are copies of fixtures/sessions/ (synthetic), pointed at by
#     the Env lines above and by --kitty-sessions-dir.
#   - The browser runs with HOME set to a throwaway folder (it creates
#     ~/.claude/tmp and falls back to ~ for missing folders) and with PATH set
#     to the stand-in scripts from fixtures/20-session-browser-actions/bin
#     ALONE. subprocess tries the next PATH entry when a program cannot be
#     executed, so the real claude, codex and kitty must not be on it at all.
#     The stand-ins use shell built-ins only; they print what they were given,
#     log it to $HOME/launches.log and (claude, codex) wait for Enter.
#   - Empty folders /tmp/nvim-course/nix-config/{rust/just-panel,
#     python/session-browser} are created so that every fixture session except
#     the textual-prototype one finds its folder, as on a real machine.
#   - The Kitty files get a fixed date (a fresh copy would be stamped "now" and
#     jump to the top of the list).
#   - c writes an OSC 52 clipboard sequence. Whether VHS's headless browser
#     passes it to your clipboard is unverified: check afterwards.
#
# The browser is started through a shell function called session-browser, so
# the line typed on camera stays short; lesson 20 step 5 spells out the same
# command in full.
#
# Anchors: "READY" (the setup's own echo), "class Launch" (actions.py, line
# 16), "9 of 9 sessions" / "3 of 9" / "2 of 9" (the browser's header after
# loading, per tab), "stub claude" / "stub codex" (the stand-ins' output on
# the normal screen), "Copied" (the notification title) and "kitty --session"
# (the log). None of them appears in a caption or a typed line.

# --- Setup (hidden: Hide is the first non-Set command, so none of this is
# recorded). Everything that uses a relative path runs before the cd.
Hide
Type `L=/tmp/nvim-course/20-session-browser-actions && rm -rf "$L" && mkdir -p "$L/home" /tmp/nvim-course/nix-config/rust/just-panel /tmp/nvim-course/nix-config/python/session-browser && cp -r fixtures/20-session-browser-actions/. "$L" && cp -r fixtures/sessions/. "$L/stores" && chmod -R u+w "$L" && chmod +x "$L"/bin/* && touch -d "2026-09-20 12:00:00 UTC" "$L"/stores/kitty/*.kitty-session`
Enter
Wait
# RE""ADY prints READY, but the typed line itself never matches /READY/.
Type `P="$L/python/session-browser" && mkdir -p "$L/python" && cp -r examples/session-browser/SB7/. "$P" && (cd "$P" && uv sync --frozen -q) && cd "$L" && clear && echo RE""ADY`
Enter
Wait+Screen@180s /READY/
# A file argument skips the bare-start dock layout; -i NONE keeps ShaDa out.
Type `nvim -i NONE "$P/src/session_browser/actions.py"`
Enter
Wait+Screen /class Launch/
Sleep 2s
Type@10ms ":echo 'Lesson 20 - build_launch and run, then Enter and c in the browser'"
Enter
Show

Sleep 1.5s

# build_launch(): one match on the source, three Launch values.
Type "/def build_launch"
Sleep 500ms
Enter
Sleep 500ms
Type "zt"
Sleep 2s
Screenshot media/20-session-browser-actions/build-launch.png
Sleep 200ms
Sleep 1.5s

# run(): detached with a reaper thread, or blocking under the Ctrl+C guard.
Type "/if launch.detach"
Sleep 500ms
Enter
Sleep 500ms
Type "zt"
Sleep 2s
Screenshot media/20-session-browser-actions/run.png
Sleep 200ms
Sleep 1.5s

# --- Leave Neovim and define the short command (hidden). A clean quit lets
# claudecode.nvim remove its lock file.
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 500ms
Wait
Type `session-browser() { HOME="$L/home" PATH="$L/bin" "$P/.venv/bin/session-browser" "$@"; }`
Enter
Wait
Type "clear"
Enter
Wait
Show

Sleep 500ms
Type "# claude, codex and kitty are stand-ins here: nothing real starts"
Enter
Sleep 1s
Type "session-browser --kitty-sessions-dir stores/kitty"
Sleep 500ms
Enter
Wait+Screen@60s /9 of 9 sessions/
Sleep 2.5s
Screenshot media/20-session-browser-actions/browser.png
Sleep 200ms

# Enter on the first row (Claude): the browser steps aside and the stand-in
# claude owns the terminal until Enter.
Enter
Wait+Screen /stub claude/
Sleep 3s
Screenshot media/20-session-browser-actions/suspended.png
Sleep 200ms
Enter
Wait+Screen /9 of 9 sessions/
Sleep 2s

# l l: the Codex tab. Enter: the stand-in codex, in the session's folder.
Type "l"
Sleep 800ms
Type "l"
Wait+Screen /3 of 9 sessions/
Sleep 1.5s
Enter
Wait+Screen /stub codex/
Sleep 2.5s
Enter
Wait+Screen /3 of 9 sessions/
Sleep 1.5s

# l: the Kitty tab. Enter starts kitty detached: the browser just carries on.
Type "l"
Wait+Screen /2 of 9 sessions/
Sleep 1.5s
Enter
Sleep 2s

# l: back to All. G: the last row (its folder is missing). c: copy.
Type "l"
Wait+Screen /9 of 9 sessions/
Sleep 1s
Type "G"
Sleep 1.5s
Type "c"
Wait+Screen /Copied/
Sleep 2s
Screenshot media/20-session-browser-actions/copied.png
Sleep 200ms
Sleep 1.5s

# q: what the stand-ins printed is still on the normal screen.
Type "q"
Wait
Sleep 1.5s
Screenshot media/20-session-browser-actions/behind.png
Sleep 200ms
Sleep 1s

# The log: exactly what each program was given, and in which folder.
Type "cat home/launches.log"
Sleep 500ms
Enter
Wait+Screen /kitty --session/
Sleep 3s
Screenshot media/20-session-browser-actions/launches.png
Sleep 200ms

# --- Teardown (hidden). Neovim was already quit above, so there is nothing
# left to close: the tape just stops recording at the bash prompt.
Hide
Type "clear"
Enter
Sleep 300ms
