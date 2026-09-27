Source tapes/_shared/settings.tape
Output media/10-lsp/10-lsp.gif
Output media/10-lsp/10-lsp.mp4
Require nvim
Require cargo
Require rust-analyzer
# One target directory for every capstone tape. rust-analyzer's own
# `cargo clippy` builds into it too, so a second recording is quick.
Env CARGO_TARGET_DIR "/tmp/nvim-course/cargo-target"
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/10-lsp.claude"

# tapes/10-lsp.tape - Lesson 10: rust-analyzer on just-panel. :checkhealth
# vim.lsp, K (hover) on serde_json's Value, gd into serde_json and <C-o>
# back, grr (references) into quickfix, and reading an error with virtual
# text off: the E sign, then ]d and its float.
#
# Records examples/just-panel/JP3 - no tags or course progress needed. JP3
# is the milestone lesson 10 ends with; JP4 changes only sections.rs and adds
# a test fixture, so justfile.rs, the file on screen, is the same in both.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config), in a zsh inside
# the repo so direnv has loaded the flake dev shell. VHS's bash inherits that
# environment, and it has no direnv hook, so the cd into /tmp unloads nothing:
# the recording uses the dev shell's rust-analyzer and cargo, as lesson 10
# does. Any shell with rust-analyzer and cargo on PATH (rustup's, say) also
# works: the worked example is a one-crate workspace with no OpenSSL.
#   cd ~/Repos/personal/nix-config/docs/NEOVIM-COURSE
#   vhs tapes/10-lsp.tape
# `vhs --version` must print 0.12.1, which the config builds: 0.12.0 exits 0
# and writes no GIF, MP4 or PNG (charmbracelet/vhs#787). Afterwards, check
# that media/10-lsp/ really holds the GIF, the MP4 and the six PNGs.
#
# What it touches:
#   - copies the worked example examples/just-panel/JP3 (a mini Cargo
#     workspace: Cargo.toml, Cargo.lock and just-panel/) to
#     /tmp/nvim-course/10-lsp/rust, the repo's own layout, and opens
#     just-panel/src/justfile.rs there. It never reads your capstone and
#     never writes to the repo;
#   - opens, through gd, serde_json's source under ~/.cargo/registry;
#   - deletes one line in the justfile.rs BUFFER to provoke a diagnostic, then
#     undoes it. Nothing is ever written: no :w, no <C-s>, and :qa! at the end.
#     rust-analyzer's own `cargo clippy` writes build output to the shared
#     CARGO_TARGET_DIR (Env above);
#   - copies fixtures/10-lsp/ (one Lua helper) to /tmp/nvim-course/10-lsp;
#   - claudecode.nvim starts its server on every Neovim start (auto_start =
#     true, neovim.nix:830-833) and writes an IDE lock file under
#     $CLAUDE_CONFIG_DIR/ide: the Env above sends it to a throwaway folder, so
#     your real ~/.claude is untouched.
#
# Timing rules:
#   - wait-for-rust-analyzer.lua echoes "rust-analyzer ready" once hover works
#     AND rust-analyzer has been quiet for 8 s. A cold first run (serde and
#     serde_json not yet built in the target directory) builds and
#     clippy-checks the example first; the 600 s wait covers a slow machine.
#   - The hover float is closed with l then h (cursor movement) before gd, so
#     no stale float is left in the gd frame.
#   - NvimCourseWaitForDiagnostic() waits (hidden) until the deleted match arm
#     has produced rust-analyzer's "missing match arm" diagnostic, so ]d never
#     runs before there is something to jump to.
#   - Anchors: "Active Features" and "Root directory" exist only in the
#     health report (the root it shows is /tmp/nvim-course/10-lsp/rust);
#     "derive(Clone, Eq, PartialEq, Hash)" only in serde_json's value/mod.rs
#     (the hover float shows no attributes; the example's Cargo.lock pins
#     serde_json 1.0.151); "N col M" only in the quickfix list; "missing
#     match arm" only in the ]d float.

# --- Setup (hidden) --------------------------------------------------------
Hide
# If a copy fails, the chain stops before cd, nvim cannot find the file and
# the "The justfile model" Wait times out.
Type `L=/tmp/nvim-course/10-lsp && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/10-lsp/. "$L" && cp -r examples/just-panel/JP3/. "$L/rust" && cd "$L/rust" && clear`
Enter
Wait
# A file argument skips the dock layout; -i NONE keeps ShaDa out of it.
Type "nvim -i NONE just-panel/src/justfile.rs"
Enter
Wait+Screen /The justfile model/
Sleep 1s
Type ":source /tmp/nvim-course/10-lsp/wait-for-rust-analyzer.lua"
Enter
Wait+Screen@600s /rust-analyzer ready/
Sleep 500ms
Type@10ms ":echo 'Lesson 10 - checkhealth, K, gd and <C-o>, grr, and ]d with virtual text off'"
Enter
Show

Sleep 2s

# --- 1. Which server, which binary, which settings -------------------------
Type ":checkhealth vim.lsp"
Enter
Wait+Screen /Active Features/
Sleep 1s
# "Version:" occurs only in the Active Clients section; k goes up to the
# client's name line and zt scrolls it to the top.
Type "/Version:"
Enter
Type "kzt"
Wait+Screen /Root directory/
Sleep 2s
Screenshot media/10-lsp/checkhealth.png
Sleep 200ms
# q closes the report's tab page (Neovim's health buffer map).
Type "q"
Wait+Screen /The justfile model/
Sleep 1.5s

# --- 2. Hover: K on serde_json's Value ------------------------------------
# \zs puts the cursor on the V of Value.
Type "/Option<\zsValue>"
Enter
Sleep 1s
Type "K"
Wait+Screen /Represents any valid JSON value/
Sleep 2.5s
Screenshot media/10-lsp/hover.png
Sleep 200ms
# Moving the cursor closes the float.
Type "lh"
Sleep 1s

# --- 3. gd into serde_json, <C-o> back --------------------------------------
Type "gd"
Wait+Screen /derive\(Clone, Eq, PartialEq, Hash\)/
Sleep 2.5s
Screenshot media/10-lsp/definition.png
Sleep 200ms
Ctrl+O
Wait+Screen /pub default: Option<Value>/
Sleep 2s

# --- 4. References: grr on the `recipe` field -------------------------------
# grr (Neovim 0.12 default) rather than the config's gr, which waits out
# 'timeoutlen' first; both fill the same quickfix list.
Type "/pub recipe"
Enter
Type "w"
Sleep 1s
Type "grr"
Wait+Screen /\|\d+ col \d+/
Sleep 2.5s
Screenshot media/10-lsp/references.png
Sleep 200ms
Type ":cclose"
Enter
Sleep 1s
# Space h: clear the search highlight (<leader>h).
Type " h"
Sleep 1s

# --- 5. An error you cannot see: delete a match arm (buffer only) ----------
Type "/ParameterKind::Plus =>"
Enter
Sleep 800ms
Type "dd"
Sleep 500ms
# Hidden: wait for rust-analyzer's diagnostic instead of guessing a Sleep.
Hide
Type ":lua NvimCourseWaitForDiagnostic('missing match arm')"
Enter
Wait+Screen@60s /diagnostic arrived/
Type@10ms ":echo 'Virtual text is off: an E in the sign column and an underline, no message'"
Enter
Show
Sleep 2.5s
Screenshot media/10-lsp/sign.png
Sleep 200ms

# ]d from the top of the file jumps to the first diagnostic and opens its
# float (the config's ]d, neovim.nix:354).
Type "gg"
Sleep 1s
Type "]d"
Wait+Screen /missing match arm/
Sleep 3s
Screenshot media/10-lsp/diagnostic-float.png
Sleep 200ms

# Put the line back. The buffer is never saved.
Type "u"
Sleep 2s

# --- Teardown (hidden) ------------------------------------------------------
# :qa! discards the (already undone) change and lets claudecode.nvim remove
# its lock file.
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 300ms
