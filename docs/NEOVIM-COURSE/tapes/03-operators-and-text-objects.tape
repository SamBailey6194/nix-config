Source tapes/_shared/settings.tape
Output media/03-operators-and-text-objects/03-operators-and-text-objects.gif
Output media/03-operators-and-text-objects/03-operators-and-text-objects.mp4
Require nvim

# tapes/03-operators-and-text-objects.tape - Lesson 03: c/d with text objects
# (iw, i", it/at, i{, a(), visual block I and A, Comment.nvim (gcip, gcc and
# dot), and nvim-autopairs closing a quote as you type.
#
# Run from docs/NEOVIM-COURSE/ on laptop-intel (full config):
#   vhs tapes/03-operators-and-text-objects.tape
#
# Why a Python fixture and not Markdown: Comment.nvim needs a comment syntax
# (plain text has none) and the lesson is about Python-shaped brackets and
# quotes. pyright and ruff attach to it (neovim.nix:397-409), so:
#   - the fixture (a copy of practice/03-text-objects.py) passes ruff check,
#     ruff format --check and pyright, and every finished edit below keeps it
#     valid, so no diagnostic signs appear (gcc and . comment Filter fields,
#     which nothing reads);
#   - block $A's Insert mode is the one invalid moment (only line 37 has its
#     default yet), so its <Esc> and pyright's recheck after it run hidden;
#   - the setup waits 3 s after the file opens for the servers to settle;
#   - the file is NEVER saved: saving would run ruff format (format on save).
#
# Clipboard: c and d write to the system clipboard (clipboard=unnamedplus,
# neovim.nix:257), so recording this tape replaces what you had copied with
# fixture text. Nothing presses " in Normal mode, so which-key's register
# list (which shows the clipboard) never appears.
#
# Completion: typing in Insert mode may open nvim-cmp's menu. The tape never
# presses Enter in Insert mode (Enter would accept the first item,
# neovim.nix:305); Escape closes the menu and leaves Insert mode.
#
# Privacy: CLAUDE_CONFIG_DIR points at a throwaway sibling of the fixture
# copy, so the IDE lock file claudecode.nvim writes on every start
# (auto_start = true, neovim.nix:830-833) never lands in ~/.claude/ide.
#
# Needs VHS 0.12.1, which the config builds: 0.12.0 runs this tape, exits 0
# and writes NOTHING (charmbracelet/vhs#787), so `vhs --version` must print
# 0.12.1 (Appendix B). Then check that
# media/03-operators-and-text-objects/ holds the GIF, the MP4 and all seven PNGs.
Env CLAUDE_CONFIG_DIR "/tmp/nvim-course/03-operators-and-text-objects.claude"

# --- Setup (hidden).
Hide
Type `L=/tmp/nvim-course/03-operators-and-text-objects && rm -rf "$L" "$L.claude" && mkdir -p "$L" && cp -r fixtures/03-operators-and-text-objects/. "$L" && cd "$L" && clear`
Enter
Wait
# A file argument skips the bare-start dock layout; -i NONE keeps ShaDa out.
Type "nvim -i NONE 03-text-objects.py"
Enter
Wait+Screen /Lesson 03 kata/
Sleep 3s
Type@10ms ":echo 'Lesson 03 - operator + text object: ciw, ci quote, cit, di{, block I/A, gc, autopairs'"
Enter
Show

Sleep 1.5s

# ciw changes the word under the cursor.
Type "15G0"
Sleep 700ms
Type "fC"
Sleep 700ms
Type "ciw"
Sleep 600ms
Type "Kitty"
Sleep 400ms
Escape
Sleep 900ms

# ci" from the start of the line, before the string: i" looks forward to the
# first string on the line. The 0 matters: 14G alone keeps the column
# (Neovim's default nostartofline), which after Kitty is inside the string.
Type "14G0"
Sleep 700ms
Type 'ci"'
Sleep 700ms
Type "Parse the just dump"
Sleep 400ms
Escape
Sleep 1.2s
Screenshot media/03-operators-and-text-objects/ciw-ci-quote.png
Sleep 200ms

# it / at: the text inside a tag, or the whole element.
Type "26G0"
Sleep 700ms
Type "fi"
Sleep 700ms
Type "cit"
Sleep 600ms
Type "session browser"
Sleep 400ms
Escape
Sleep 900ms
Type "0fj"
Sleep 700ms
Type "dat"
Sleep 1.2s
Screenshot media/03-operators-and-text-objects/tags.png
Sleep 200ms
Type "u"
Sleep 900ms

# i{ on a multi-line dict empties it; u brings it back.
Type "20G"
Sleep 700ms
Type "di{"
Sleep 1.2s
Screenshot media/03-operators-and-text-objects/di-brace.png
Sleep 200ms
Type "u"
Sleep 1s

# a( takes the brackets too.
Type "51G0"
Sleep 800ms
Type "f("
Sleep 700ms
Type "da("
Sleep 1.2s
Type "u"
Sleep 1s

# Visual block I: the same text in front of three lines. zz (lesson 02) only
# centres the view: coming up from line 51, 29G alone scrolls line 29 to the
# top row and hides the COMMANDS = [ line above it.
Type '29Gzz0f"l'
Sleep 800ms
Ctrl+V
Sleep 600ms
Type "2j"
Sleep 900ms
Type "I"
Sleep 400ms
Type "just "
Sleep 400ms
Escape
Sleep 1.2s
Screenshot media/03-operators-and-text-objects/block-insert.png
Sleep 200ms

# Visual block $A: the same text after three ragged line ends. In Insert mode
# only line 37 has its default, so pyright flags lines 38-39 (no default after
# a default) and shows those E signs the moment <Esc> lands, for about 0.4 s
# until it rechecks. The <Esc> and that settle run hidden: the recording cuts
# from Insert mode on line 37 to all three lines filled in. Lesson section 5
# warns readers about the flash.
Type "37G0"
Sleep 700ms
Ctrl+V
Sleep 600ms
Type "2j$"
Sleep 900ms
Type "A"
Sleep 400ms
Type " = None"
Sleep 700ms
Hide
Escape
Sleep 1.5s
Show
Sleep 500ms
Screenshot media/03-operators-and-text-objects/block-append.png
Sleep 200ms

# Comment.nvim: gcip comments the paragraph (the Filter class); u undoes it.
# gcc comments one line and . repeats it on the next: Filter's query and
# source, which nothing reads (Session's source and id would break label()
# and resume_command() and show E signs); u u undoes both.
Type "36G"
Sleep 700ms
Type "gcip"
Sleep 1.2s
Screenshot media/03-operators-and-text-objects/gcip.png
Sleep 200ms
Type "u"
Sleep 900ms
Type "37G"
Sleep 700ms
Type "gcc"
Sleep 900ms
Type "j"
Sleep 500ms
Type "."
Sleep 1.2s
Type@500ms "uu"
Sleep 900ms

# nvim-autopairs: typing " inserts the closing " too; typing " again steps
# over it.
Type "31G"
Sleep 700ms
Type "o"
Sleep 500ms
Type '"'
Sleep 1.2s
Screenshot media/03-operators-and-text-objects/autopairs.png
Sleep 200ms
Type "lint"
Sleep 600ms
Type '",'
Sleep 700ms
Escape
Sleep 1.5s

# --- Teardown (hidden). :qa! discards everything (no save, so no ruff
# format) and lets claudecode.nvim remove its lock file from the throwaway
# $CLAUDE_CONFIG_DIR/ide.
Hide
Escape
Sleep 300ms
Type ":qa!"
Enter
Sleep 300ms
