# Recording fixture for lesson 22 (tapes/22-making-the-config-yours.tape).
# Lines 10-105 are copied verbatim from home/modules/neovim.nix at commit
# 6e379a3, and the header is padded so every line number here matches that
# file (the <Tab> entry is on line 61 in both). Edit the REAL file, not this.
# Wrapped as a small function of `lib` so it is a valid Nix expression: the
# language server then has nothing to complain about on camera.
{ lib }:

let
  # ── Keybinds ───────────────────────────────────────────────────────────
  #
  # Single source of truth. This list renders BOTH the vim.keymap.set calls in
  # initLua AND the KEYBINDS.md that the Neovim dev layout shows in its
  # top-right pane (see rust/dev-layout, NVIM_KEYBINDS_REL). Add a binding here
  # and both update together, so the on-screen reference cannot drift from the
  # bindings it claims to document — which is exactly what has happened to the
  # hand-maintained config/hypr/KEYBINDS.md.
  #
  # `docOnly = true` means "documented here, defined elsewhere": the LSP
  # bindings are buffer-local and set inside on_attach, and the conform one
  # needs a Lua closure. Generating those from a string would be a lie, but
  # leaving them out of the reference would be worse.
  keymaps = [
    { group = "Panels"; lhs = "<leader>e";  rhs = "<cmd>Neotree toggle filesystem left<CR>"; desc = "Toggle file tree (left)"; }
    { group = "Panels"; lhs = "<leader>b";  rhs = "<cmd>Neotree toggle buffers left<CR>";    desc = "Toggle buffer list (left)"; }
    { group = "Panels"; lhs = "<leader>o";  rhs = "<cmd>AerialToggle<CR>";     desc = "Toggle outline (left)"; }
    { group = "Panels"; lhs = "<leader>t";  rhs = "<cmd>ToggleTerm<CR>";       desc = "Toggle terminal (bottom)"; }

    { group = "Find";   lhs = "<leader>ff"; rhs = "<cmd>Telescope find_files<CR>"; desc = "Find files"; }
    { group = "Find";   lhs = "<leader>fg"; rhs = "<cmd>Telescope live_grep<CR>";  desc = "Live grep"; }
    { group = "Find";   lhs = "<leader>fb"; rhs = "<cmd>Telescope buffers<CR>";    desc = "Buffers"; }
    { group = "Find";   lhs = "<leader>fh"; rhs = "<cmd>Telescope help_tags<CR>";  desc = "Help tags"; }

    { group = "Git";    lhs = "<leader>gs"; rhs = "<cmd>Neotree toggle git_status right<CR>"; desc = "Git status panel (right)"; }
    { group = "Git";    lhs = "<leader>gg"; rhs = "<cmd>Neogit<CR>";                desc = "Full git UI (Neogit)"; }
    { group = "Git";    lhs = "<leader>gd"; rhs = "<cmd>DiffviewOpen<CR>";          desc = "Diff view"; }
    { group = "Git";    lhs = "<leader>gq"; rhs = "<cmd>DiffviewClose<CR>";         desc = "Close diff view"; }
    { group = "Git";    lhs = "<leader>gh"; rhs = "<cmd>DiffviewFileHistory %<CR>"; desc = "History of this file"; }

    { group = "AI";     lhs = "<leader>cc"; rhs = "<cmd>ClaudeCode<CR>";           desc = "Toggle Claude Code"; }
    { group = "AI";     lhs = "<leader>cb"; rhs = "<cmd>ClaudeCodeAdd %<CR>";      desc = "Send buffer to Claude"; }
    { group = "AI";     lhs = "<leader>cs"; rhs = "<cmd>ClaudeCodeSend<CR>";       desc = "Send selection to Claude"; mode = "v"; }
    { group = "AI";     lhs = "<leader>co"; rhs = "<cmd>CodexToggle<CR>";          desc = "Toggle Codex CLI"; }

    { group = "Code";   lhs = "<leader>ca"; desc = "Code action";        docOnly = true; }
    { group = "Code";   lhs = "<leader>cf"; desc = "Format buffer";      docOnly = true; }
    { group = "Code";   lhs = "<leader>rn"; desc = "Rename symbol";      docOnly = true; }
    { group = "Code";   lhs = "gd";         desc = "Go to definition";   docOnly = true; }
    { group = "Code";   lhs = "gD";         desc = "Go to declaration";  docOnly = true; }
    { group = "Code";   lhs = "gi";         desc = "Go to implementation"; docOnly = true; }
    { group = "Code";   lhs = "gr";         desc = "References";         docOnly = true; }
    { group = "Code";   lhs = "K";          desc = "Hover docs";         docOnly = true; }
    { group = "Code";   lhs = "<leader>k";  desc = "Signature help";     docOnly = true; }

    { group = "Diagnostics"; lhs = "<leader>xx"; rhs = "<cmd>Trouble diagnostics toggle<CR>";              desc = "All diagnostics"; }
    { group = "Diagnostics"; lhs = "<leader>xw"; rhs = "<cmd>Trouble diagnostics toggle filter.buf=0<CR>"; desc = "Buffer diagnostics"; }
    { group = "Diagnostics"; lhs = "<leader>ld"; desc = "Line diagnostic";     docOnly = true; }
    { group = "Diagnostics"; lhs = "[d";         desc = "Previous diagnostic"; docOnly = true; }
    { group = "Diagnostics"; lhs = "]d";         desc = "Next diagnostic";     docOnly = true; }

    { group = "Buffers"; lhs = "<Tab>";      rhs = "<cmd>bnext<CR>";     desc = "Next buffer"; }
    { group = "Buffers"; lhs = "<S-Tab>";    rhs = "<cmd>bprevious<CR>"; desc = "Previous buffer"; }
    { group = "Buffers"; lhs = "<leader>x";  rhs = "<cmd>bdelete<CR>";   desc = "Close buffer"; }
    { group = "Buffers"; lhs = "<C-s>";      rhs = "<cmd>w<CR>";         desc = "Save"; }
    { group = "Buffers"; lhs = "<C-q>";      rhs = "<cmd>q<CR>";         desc = "Quit"; }
    { group = "Buffers"; lhs = "<leader>h";  rhs = "<cmd>nohlsearch<CR>"; desc = "Clear search highlight"; }

    { group = "Windows"; lhs = "<C-h>"; rhs = "<C-w>h"; desc = "Window left"; }
    { group = "Windows"; lhs = "<C-j>"; rhs = "<C-w>j"; desc = "Window down"; }
    { group = "Windows"; lhs = "<C-k>"; rhs = "<C-w>k"; desc = "Window up"; }
    { group = "Windows"; lhs = "<C-l>"; rhs = "<C-w>l"; desc = "Window right"; }
  ];

  # Lua single-quoted string literal. Backslash first, or it would double the
  # backslashes this very function just inserted for the quotes.
  luaStr = str: "'" + lib.replaceStrings [ "\\" "'" ] [ "\\\\" "\\'" ] str + "'";

  generated = builtins.filter (k: !(k.docOnly or false)) keymaps;

  renderKeymap = k:
    let
      mode = k.mode or "n";
    in
    "vim.keymap.set(${luaStr mode}, ${luaStr k.lhs}, ${luaStr k.rhs}, "
    + "{ desc = ${luaStr k.desc}, noremap = true, silent = true })";

  keymapLua = lib.concatMapStringsSep "\n      " renderKeymap generated;

  keymapGroups = lib.unique (map (k: k.group) keymaps);

  renderGroup = group:
    let
      rows = lib.filter (k: k.group == group) keymaps;
      row = k: "| `${k.lhs}` | ${k.desc} |";
    in
    "## ${group}\n\n| Key | Action |\n| --- | --- |\n"
    + lib.concatMapStringsSep "\n" row rows;

  keybindsMarkdown = ''
    # Neovim keybinds

    Leader is `<Space>`. Generated from `home/modules/neovim.nix` — do not edit
    by hand; the file is rewritten on every `nixos-rebuild`.

  '' + lib.concatMapStringsSep "\n\n" renderGroup keymapGroups + "\n";
in
{
  inherit keymaps keymapLua keybindsMarkdown;
}
