{ config, pkgs, lib, ... }:

let
  # Language servers not carried by nixpkgs, or carried too old — see pkgs/*.nix
  # for why. Same derivations modules/software/development.nix puts on PATH.
  laravel-ls = pkgs.callPackage ../../pkgs/laravel-ls.nix { };
  django-template-lsp = pkgs.callPackage ../../pkgs/django-template-lsp.nix { };
  htmx-lsp = pkgs.callPackage ../../pkgs/htmx-lsp.nix { };

  # ── Keybinds ───────────────────────────────────────────────────────────
  #
  # Single source of truth. This list renders BOTH the vim.keymap.set calls in
  # initLua AND the KEYBINDS.md that Neovim shows in its own keybind pane, the
  # leftmost window of the bare-start layout (<leader>? toggles it). Add a
  # binding here and both update together, so the on-screen reference cannot
  # drift from the bindings it claims to document — which is exactly what has
  # happened to the hand-maintained config/hypr/KEYBINDS.md.
  #
  # `docOnly = true` means "documented here, defined elsewhere": the LSP
  # bindings are buffer-local and set inside on_attach, the conform one needs
  # a Lua closure, and the git panel's `D` is a neo-tree mapping that only
  # exists inside that panel. Generating those from a string would be a lie,
  # but leaving them out of the reference would be worse.
  #
  # <leader>t takes a count because :TermToggle reads v:count, which a <cmd>
  # mapping still sets even though it does not pass the count on as a range:
  # 2<leader>t is terminal 2.
  #
  # <Tab>/<S-Tab> go through :BufCycle rather than a bare :bnext, so they
  # cycle the tabs of the EDITING window even from the keybind pane (where a
  # bare :bnext is an E1513 'winfixbuf' error) or the outline, and they skip
  # Claude's terminal, which lives in its own split rather than as a tab.
  # The one exception is inside the tree and the git panel: neo-tree maps
  # <Tab> there to its own "select node" (marking nodes for a batch copy,
  # move or delete), and a buffer-local mapping wins. That is kept, because
  # <S-Tab>, which neo-tree leaves alone, still cycles from there.
  #
  # <leader>t sits under Buffers, not Panels: a terminal is a tab of the
  # editing window now, not a docked panel.
  #
  # Descriptions stay short on purpose: the keybind pane is sized to the
  # widest line of KEYBINDS.md, so a long one here takes columns from the
  # editing window on every bare start.
  keymaps = [
    { group = "Panels"; lhs = "<leader>e";  rhs = "<cmd>Neotree toggle filesystem left<CR>"; desc = "Toggle file tree (left)"; }
    { group = "Panels"; lhs = "<leader>b";  rhs = "<cmd>Neotree toggle buffers left<CR>";    desc = "Toggle buffer list (left)"; }
    { group = "Panels"; lhs = "<leader>o";  rhs = "<cmd>AerialToggle<CR>";     desc = "Toggle outline (left)"; }
    { group = "Panels"; lhs = "<leader>?";  rhs = "<cmd>KeybindsToggle<CR>";   desc = "Toggle keybind reference (left)"; }

    { group = "Find";   lhs = "<leader>ff"; rhs = "<cmd>Telescope find_files<CR>"; desc = "Find files"; }
    { group = "Find";   lhs = "<leader>fg"; rhs = "<cmd>Telescope live_grep<CR>";  desc = "Live grep"; }
    { group = "Find";   lhs = "<leader>fb"; rhs = "<cmd>Telescope buffers<CR>";    desc = "Buffers"; }
    { group = "Find";   lhs = "<leader>fh"; rhs = "<cmd>Telescope help_tags<CR>";  desc = "Help tags"; }

    { group = "Git";    lhs = "<leader>gs"; rhs = "<cmd>Neotree toggle git_status right<CR>"; desc = "Git status panel (right)"; }
    { group = "Git";    lhs = "D";          desc = "In git panel: diff file at cursor"; docOnly = true; }
    { group = "Git";    lhs = "<leader>gg"; rhs = "<cmd>Neogit<CR>";                desc = "Full git UI (Neogit)"; }
    { group = "Git";    lhs = "<leader>gd"; rhs = "<cmd>DiffviewOpen<CR>";          desc = "Diff view"; }
    { group = "Git";    lhs = "<leader>gq"; rhs = "<cmd>DiffviewClose<CR>";         desc = "Close diff view"; }
    { group = "Git";    lhs = "<leader>gh"; rhs = "<cmd>DiffviewFileHistory %<CR>"; desc = "History of this file"; }

    { group = "AI";     lhs = "<leader>cc"; rhs = "<cmd>ClaudeCode<CR>";           desc = "Toggle Claude Code"; }
    { group = "AI";     lhs = "<leader>cb"; rhs = "<cmd>ClaudeCodeAdd %<CR>";      desc = "Send buffer to Claude"; }
    { group = "AI";     lhs = "<leader>cs"; rhs = "<cmd>ClaudeCodeSend<CR>";       desc = "Send selection to Claude"; mode = "v"; }
    { group = "AI";     lhs = "<leader>co"; rhs = "<cmd>CodexToggle<CR>";          desc = "Toggle Codex CLI tab"; }
    { group = "AI";     lhs = "<leader>cp"; rhs = "<cmd>OpenCodeToggle<CR>";       desc = "Toggle OpenCode tab"; }
    { group = "AI";     lhs = "<leader>cg"; rhs = "<cmd>AntigravityToggle<CR>";    desc = "Toggle Antigravity tab"; }

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

    { group = "Buffers"; lhs = "<Tab>";      rhs = "<cmd>BufCycle<CR>";  desc = "Next buffer (in tree: select node)"; }
    { group = "Buffers"; lhs = "<S-Tab>";    rhs = "<cmd>BufCycle!<CR>"; desc = "Previous buffer"; }
    { group = "Buffers"; lhs = "<leader>t";  rhs = "<cmd>TermToggle<CR>"; desc = "Toggle terminal (2<leader>t: 2nd)"; }
    { group = "Buffers"; lhs = "<leader>x";  rhs = "<cmd>Bdelete<CR>";   desc = "Close buffer, keep the window"; }
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

  # KEYBINDS.md is read raw, in a Neovim pane sized to its widest line, so
  # the tables are padded into aligned columns (the shape prettier would give
  # them) and the prose is wrapped short: the pane's width is taken from the
  # screen the editing window would otherwise have. Padding counts bytes,
  # which equals columns because every key and description here is ASCII.
  repeatStr = n: s: lib.concatStrings (lib.genList (_: s) n);
  padRight = width: s: s + repeatStr (width - lib.stringLength s) " ";

  renderGroup = group:
    let
      rows = lib.filter (k: k.group == group) keymaps;
      keyCell = k: "`${k.lhs}`";
      widest = cells: lib.foldl' lib.max 0 (map lib.stringLength cells);
      keyWidth = widest ([ "Key" ] ++ map keyCell rows);
      descWidth = widest ([ "Action" ] ++ map (k: k.desc) rows);
      line = key: desc: "| ${padRight keyWidth key} | ${padRight descWidth desc} |";
    in
    "## ${group}\n\n"
    + line "Key" "Action" + "\n"
    + "| ${repeatStr keyWidth "-"} | ${repeatStr descWidth "-"} |\n"
    + lib.concatMapStringsSep "\n" (k: line (keyCell k) k.desc) rows;

  keybindsMarkdown = ''
    # Neovim keybinds

    Leader is `<Space>`; `<leader>?` hides this
    pane. Generated from `home/modules/neovim.nix`
    — do not edit by hand; the file is rewritten
    on every `nixos-rebuild`.

  '' + lib.concatMapStringsSep "\n\n" renderGroup keymapGroups + "\n";
in
{
  # Neovim configuration with Lua
  # Reuses the same LSP servers and linters as Zed
  # All LSP servers are in modules/software/development.nix

  programs.neovim = {
    enable = true;
    defaultEditor = false;  # Zed is still the default (EDITOR=zeditor in stages/dev.nix)
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    withRuby = false;    # Not needed — using LSP directly
    withPython3 = false; # Not needed — using LSP directly

    # Neovim plugins
    plugins = with pkgs.vimPlugins; [
      # Plugin manager (lazy.nvim is loaded via init.lua)

      # LSP and completion
      nvim-lspconfig           # LSP configuration
      conform-nvim             # Formatting (prettier/shfmt/ruff, LSP fallback)
      nvim-cmp                 # Completion engine
      cmp-nvim-lsp             # LSP completion source
      cmp-buffer               # Buffer completion source
      cmp-path                 # Path completion source
      cmp-cmdline              # Command line completion
      luasnip                  # Snippet engine
      cmp_luasnip              # Snippet completion source
      friendly-snippets        # Snippet collection

      # Treesitter (better syntax highlighting)
      nvim-treesitter.withAllGrammars

      # File explorer. neo-tree rather than nvim-tree because each of its
      # sources (filesystem, buffers, git_status) carries its own `window
      # .position`, so the panels dock themselves — which is the entire job
      # edgy.nvim was here to do.
      neo-tree-nvim            # File tree + git status, as placed panels
      nui-nvim                 # neo-tree's UI toolkit dependency
      nvim-web-devicons        # Icons

      # Fuzzy finder
      telescope-nvim           # Fuzzy finder
      telescope-fzf-native-nvim # Faster fuzzy matching

      # Git integration
      gitsigns-nvim            # Git signs in gutter
      vim-fugitive             # Git commands

      # UI enhancements
      lualine-nvim             # Status line
      bufferline-nvim          # Buffer line
      indent-blankline-nvim    # Indent guides
      which-key-nvim           # Keybinding hints

      # Theme (Ayu Dark to match Zed)
      ayu-vim

      # Utilities
      comment-nvim             # Easy commenting
      nvim-autopairs           # Auto close brackets
      # No terminal plugin: terminals are plain :terminal buffers shown in
      # the editing window, as tabs (see TERMINALS in initLua). toggleterm's
      # whole job was the docked window this layout no longer has.
      trouble-nvim             # Better diagnostics
      nvim-colorizer-lua       # Color preview

      # Outline — mirrors Zed's outline_panel. Opens on the left, beside the
      # file tree (right of the keybind pane), not under it. At laptop width
      # (170 columns) there is not room for it and the keybind pane both, so
      # opening it makes FIT (in initLua) hide the keybind pane.
      aerial-nvim

      # Full git UI (Neogit, in its own tab) and the diff viewer. The git
      # panel itself, the one open on the right from startup inside a git
      # work tree, is neo-tree's git_status source above, not either of
      # these.
      neogit
      diffview-nvim
      plenary-nvim             # neogit's dependency; telescope pulls it in too

      # Claude Code, as an editor integration rather than a bare shell: it can
      # take the current buffer or selection as context and review diffs in
      # place. Codex has no such plugin and runs in a terminal buffer instead.
      claudecode-nvim

      # Language-specific
      rust-vim                 # Rust support
      vim-nix                  # Nix support
    ];

    # Extra packages needed for plugins/LSP
    extraPackages = with pkgs; [
      # File finder dependencies
      ripgrep
      fd

      # Clipboard support
      wl-clipboard
      xclip
    ];

    # Lua configuration
    initLua = ''
      -- Neovim configuration with Lua
      -- Designed to work alongside Zed, using same LSP servers

      -- ============================================================================
      -- BASIC SETTINGS
      -- ============================================================================

      vim.g.mapleader = ' '
      vim.g.maplocalleader = ' '

      -- Line numbers
      vim.opt.number = true
      vim.opt.relativenumber = true

      -- Tabs and indentation
      vim.opt.tabstop = 2
      vim.opt.shiftwidth = 2
      vim.opt.expandtab = true
      vim.opt.autoindent = true

      -- Line wrapping
      vim.opt.wrap = false

      -- Search settings
      vim.opt.ignorecase = true
      vim.opt.smartcase = true
      vim.opt.hlsearch = true
      vim.opt.incsearch = true

      -- Appearance
      vim.opt.termguicolors = true
      vim.opt.background = 'dark'

      -- Kept after edgy.nvim was dropped, because both earn their place
      -- independently of it:
      --   laststatus = 3  one global statusline instead of one per window,
      --                   so a four-panel layout does not spend four lines
      --                   restating the same thing. lualine is happier too.
      --   splitkeep       keeps the text in the main window still when a
      --                   panel opens or closes at an edge, rather than
      --                   letting the view scroll under the cursor.
      --   splitright      new vertical splits open to the RIGHT, which is
      --                   what puts the git_status panel where Zed's
      --                   git_panel sits.
      vim.opt.laststatus = 3
      vim.opt.splitkeep = 'screen'
      vim.opt.splitright = true
      vim.opt.signcolumn = 'yes'
      vim.opt.cursorline = true

      -- Backspace
      vim.opt.backspace = 'indent,eol,start'

      -- Clipboard
      vim.opt.clipboard = 'unnamedplus'

      -- Split windows
      vim.opt.splitright = true
      vim.opt.splitbelow = true

      -- Swap and backup
      vim.opt.swapfile = false
      vim.opt.backup = false
      vim.opt.undofile = true

      -- Update time
      vim.opt.updatetime = 250
      vim.opt.timeoutlen = 300

      -- Completion
      vim.opt.completeopt = 'menu,menuone,noselect'

      -- ============================================================================
      -- THEME: AYU DARK (matching Zed)
      -- ============================================================================

      vim.g.ayucolor = 'dark'
      vim.cmd('colorscheme ayu')

      -- ============================================================================
      -- LSP CONFIGURATION
      -- Uses system-installed LSP servers from modules/software/development.nix
      -- ============================================================================

      local cmp = require('cmp')
      local luasnip = require('luasnip')

      -- Load friendly-snippets
      require('luasnip.loaders.from_vscode').lazy_load()

      -- Completion setup
      cmp.setup({
        snippet = {
          expand = function(args)
            luasnip.lsp_expand(args.body)
          end,
        },
        mapping = cmp.mapping.preset.insert({
          ['<C-b>'] = cmp.mapping.scroll_docs(-4),
          ['<C-f>'] = cmp.mapping.scroll_docs(4),
          ['<C-Space>'] = cmp.mapping.complete(),
          ['<C-e>'] = cmp.mapping.abort(),
          ['<CR>'] = cmp.mapping.confirm({ select = true }),
          ['<Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_next_item()
            elseif luasnip.expand_or_jumpable() then
              luasnip.expand_or_jump()
            else
              fallback()
            end
          end, { 'i', 's' }),
          ['<S-Tab>'] = cmp.mapping(function(fallback)
            if cmp.visible() then
              cmp.select_prev_item()
            elseif luasnip.jumpable(-1) then
              luasnip.jump(-1)
            else
              fallback()
            end
          end, { 'i', 's' }),
        }),
        sources = cmp.config.sources({
          { name = 'nvim_lsp' },
          { name = 'luasnip' },
        }, {
          { name = 'buffer' },
          { name = 'path' },
        })
      })

      -- LSP keymaps, bound per buffer as each server attaches.
      vim.api.nvim_create_autocmd('LspAttach', {
        desc = 'LSP keymaps',
        callback = function(ev)
          local opts = { buffer = ev.buf, noremap = true, silent = true }

          vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
          vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
          vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
          vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
          vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
          -- <leader>k, not <C-k>: this is buffer-local and was shadowing the
      -- global <C-k> window-up binding in every buffer with a server
      -- attached, which made window-up silently dead exactly where it is
      -- most wanted. Moving the rarer binding is cheaper than losing the
      -- common one.
      vim.keymap.set('n', '<leader>k', vim.lsp.buf.signature_help, opts)
          vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
          vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
          vim.keymap.set('n', '[d', function() vim.diagnostic.jump({ count = -1, float = true }) end, opts)
          vim.keymap.set('n', ']d', function() vim.diagnostic.jump({ count = 1, float = true }) end, opts)
          -- <leader>e belongs to the neo-tree toggle further down; a
          -- buffer-local binding here would shadow it in every buffer with a
          -- server attached.
          vim.keymap.set('n', '<leader>ld', vim.diagnostic.open_float, opts)
        end,
      })

      -- Capabilities applied to every server: nvim-cmp's completion support, plus
      -- one correction.
      --
      -- `diagnostic.dynamicRegistration = false` is load-bearing. Pyright (and
      -- other vscode-languageserver-node servers) decide at initialize time how to
      -- deliver pull diagnostics: if the client claims dynamic registration they
      -- register `textDocument/diagnostic` afterwards via client/registerCapability
      -- with a null documentSelector, which Neovim does not match against a buffer
      -- — so it never pulls, the server never pushes, and Python files show zero
      -- diagnostics while `pyright <file>` on the CLI reports them fine. Declining
      -- dynamic registration makes the server advertise diagnosticProvider
      -- statically in its initialize result, which Neovim does honour.
      local capabilities = require('cmp_nvim_lsp').default_capabilities()
      capabilities.textDocument = capabilities.textDocument or {}
      capabilities.textDocument.diagnostic = {
        dynamicRegistration = false,
        relatedDocumentSupport = false,
      }
      vim.lsp.config('*', { capabilities = capabilities })

      -- Every server below is pinned to the same /nix/store path that Zed uses
      -- (home/modules/editor.nix) and that modules/software/development.nix puts
      -- on PATH, so the two editors run byte-identical servers.

      -- nvim-lspconfig ships each server's defaults as an `lsp/<name>.lua` on the
      -- runtimepath, which Neovim >= 0.11 reads directly. `vim.lsp.config` merges
      -- the overrides below onto those defaults and `vim.lsp.enable` arms the
      -- server; the older `require('lspconfig').<name>.setup{}` path this config
      -- used is deprecated and goes away in nvim-lspconfig v3.
      local function lsp(name, opts)
        if opts then vim.lsp.config(name, opts) end
        vim.lsp.enable(name)
      end

      -- ── Python / Django ──────────────────────────────────────────────
      lsp('pyright', {
        cmd = { '${pkgs.pyright}/bin/pyright-langserver', '--stdio' },
        settings = {
          python = {
            analysis = {
              diagnosticsMode = "workspace",
              typeCheckingMode = "basic",
            }
          }
        }
      })

      lsp('ruff', { cmd = { '${pkgs.ruff}/bin/ruff', 'server' } })

      -- Django templates: {% %} tags, template/static/url names, context vars.
      -- Upstream also claims plain 'html'; restricted to htmldjango so a non-Django
      -- HTML file does not start a server that then reports it cannot find a Django
      -- project. Neovim's own content heuristic promotes templates containing
      -- {% %} / {{ }} to htmldjango, which is what real Django templates look like.
      lsp('djlsp', {
        cmd = { '${django-template-lsp}/bin/djlsp' },
        filetypes = { 'htmldjango' },
      })

      -- ── TypeScript / JavaScript / React / React Native ───────────────
      lsp('ts_ls', { cmd = { '${pkgs.typescript-language-server}/bin/typescript-language-server', '--stdio' } })
      lsp('eslint', { cmd = { '${pkgs.vscode-langservers-extracted}/bin/vscode-eslint-language-server', '--stdio' } })

      -- ── Rust ─────────────────────────────────────────────────────────
      -- rust-analyzer comes from rustup, so it is left to PATH resolution.
      lsp('rust_analyzer', {
        settings = {
          ['rust-analyzer'] = {
            check = {
              command = "clippy"
            },
            cargo = {
              allFeatures = true
            }
          }
        }
      })

      -- ── PHP / Laravel / Livewire / Blade ─────────────────────────────
      -- Blade and Livewire views are served by the same pair: Intelephense for
      -- the PHP inside the template, laravel-ls for routes/views/config/env.
      lsp('intelephense', {
        cmd = { '${pkgs.intelephense}/bin/intelephense', '--stdio' },
        filetypes = { 'php', 'blade' },
        settings = {
          intelephense = {
            files = { maxSize = 5000000 },       -- Laravel vendor/ trees are large
            environment = { includePaths = { 'vendor' } },
          }
        }
      })
      lsp('laravel_ls', { cmd = { '${laravel-ls}/bin/laravel-ls' } })

      -- ── HTML / CSS / JSON / YAML / Tailwind / Emmet ──────────────────
      lsp('html', {
        cmd = { '${pkgs.vscode-langservers-extracted}/bin/vscode-html-language-server', '--stdio' },
        filetypes = { 'html', 'htmldjango', 'blade' },
      })
      lsp('cssls', { cmd = { '${pkgs.vscode-langservers-extracted}/bin/vscode-css-language-server', '--stdio' } })
      lsp('jsonls', { cmd = { '${pkgs.vscode-langservers-extracted}/bin/vscode-json-language-server', '--stdio' } })
      -- SchemaStore's catalog already has fileMatch entries for every YAML shape
      -- in these projects (.github/workflows/*.yml, docker-compose.*.yml,
      -- lefthook.yml, pnpm-workspace.yaml), so enabling it needs no per-schema
      -- map here. vim.lsp.config deep-merges onto nvim-lspconfig's defaults, so
      -- its redhat.telemetry and yaml.format.enable settings survive.
      lsp('yamlls', {
        cmd = { '${pkgs.yaml-language-server}/bin/yaml-language-server', '--stdio' },
        settings = {
          yaml = {
            schemaStore = {
              enable = true,
              url = 'https://www.schemastore.org/api/json/catalog.json',
            },
            validate = true,
            hover = true,
            completion = true,
          },
        },
      })
      lsp('tailwindcss', {
        cmd = { '${pkgs.tailwindcss-language-server}/bin/tailwindcss-language-server', '--stdio' },
        settings = {
          tailwindCSS = {
            emmetCompletions = true,
            -- ':class' and 'x-bind:class' pick up Alpine-bound classes.
            classAttributes = { 'class', 'className', 'ngClass', ':class', 'x-bind:class' },
          }
        }
      })
      lsp('emmet_language_server', {
        cmd = { '${pkgs.emmet-language-server}/bin/emmet-language-server', '--stdio' },
      })

      -- ── htmx ─────────────────────────────────────────────────────────
      -- hx-* attribute completion. Upstream advertises ~40 filetypes including the
      -- whole TS/JS family; narrowed to the markup ones actually written by hand,
      -- because htmx-lsp is explicitly experimental ("use at your own risk") — no
      -- reason to run it on every TypeScript buffer. (Zed has no htmx extension;
      -- this is Neovim-only.)
      --
      -- Built from pkgs/htmx-lsp.nix rather than pkgs.htmx-lsp: the nixpkgs rev
      -- predates the upstream fix for answering requests it has no data for with
      -- a null result *and* a null error, which Neovim rightly rejected as a
      -- malformed message on every buffer close.
      lsp('htmx', {
        cmd = { '${htmx-lsp}/bin/htmx-lsp' },
        filetypes = { 'html', 'htmldjango', 'blade', 'php', 'twig', 'eruby' },
      })

      -- ── Slint ────────────────────────────────────────────────────────
      lsp('slint_lsp', { cmd = { '${pkgs.slint-lsp}/bin/slint-lsp' } })

      -- ── Swift ────────────────────────────────────────────────────────
      lsp('sourcekit', { cmd = { '${pkgs.sourcekit-lsp}/bin/sourcekit-lsp' } })

      -- ── Kotlin ───────────────────────────────────────────────────────
      lsp('kotlin_language_server', { cmd = { '${pkgs.kotlin-language-server}/bin/kotlin-language-server' } })

      -- ── TeX ──────────────────────────────────────────────────────────
      lsp('texlab', {
        cmd = { '${pkgs.texlab}/bin/texlab' },
        settings = {
          texlab = {
            build = {
              executable = 'latexmk',
              args = { '-pdf', '-interaction=nonstopmode', '-synctex=1', '%f' },
              onSave = false,
            },
            chktex = { onOpenAndSave = true },
          }
        }
      })

      -- ── Shell ────────────────────────────────────────────────────────
      lsp('bashls', { cmd = { '${pkgs.bash-language-server}/bin/bash-language-server', 'start' } })

      -- ── Terraform / OpenTofu ─────────────────────────────────────────
      lsp('terraformls', {
        cmd = { '${pkgs.terraform-ls}/bin/terraform-ls', 'serve' },
        init_options = {
          experimentalFeatures = {
            validateOnSave = true,
            prefillRequiredFields = true,
          }
        }
      })
      lsp('tflint', { cmd = { '${pkgs.tflint}/bin/tflint', '--langserver' } })

      -- ── Config / infra languages ─────────────────────────────────────
      lsp('lua_ls', {
        cmd = { '${pkgs.lua-language-server}/bin/lua-language-server' },
        settings = {
          Lua = {
            diagnostics = {
              globals = { 'vim' }
            }
          }
        }
      })
      lsp('nil_ls', { cmd = { '${pkgs.nil}/bin/nil' } })
      lsp('taplo', { cmd = { '${pkgs.taplo}/bin/taplo', 'lsp', 'stdio' } })

      -- nginx and systemd unit files. Both are completion/hover/diagnostics
      -- only — neither formats, so neither belongs in the format-on-save list
      -- at the bottom of this file. Filetypes come from lspconfig's defaults
      -- ('nginx' and 'systemd'), both of which Neovim detects unaided:
      -- nginx.conf, nginx*.conf and any */nginx/*.conf for the first, the unit
      -- file extensions (.service, .timer, .socket...) for the second.
      lsp('nginx_language_server', {
        cmd = { '${pkgs.nginx-language-server}/bin/nginx-language-server' },
      })
      lsp('systemd_lsp', { cmd = { '${pkgs.systemd-lsp}/bin/systemd-lsp' } })

      -- nginx variables are written $host, $request_uri and so on. Without '$'
      -- in 'iskeyword' the cursor sees them as the bare name, and completion and
      -- hover both miss — upstream recommends this exact tweak.
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'nginx',
        desc = 'Treat $ as part of the word so nginx variables resolve',
        callback = function() vim.opt_local.iskeyword:append('$') end,
      })

      -- ── Filetypes Neovim does not detect on its own ──────────────────
      -- Slint has no built-in ftplugin, and *.blade.php would otherwise be read
      -- as plain PHP, losing the blade treesitter grammar and the blade-only
      -- server attachments above.
      vim.filetype.add({
        extension = { slint = 'slint' },
        pattern = { ['.*%.blade%.php'] = 'blade' },
      })

      -- ============================================================================
      -- TREESITTER
      -- ============================================================================

      -- nvim-treesitter's `main` branch — which is what nixpkgs now ships —
      -- removed the `nvim-treesitter.configs` module. The old
      -- `require('nvim-treesitter.configs').setup{}` call therefore threw at
      -- startup and took the rest of init.lua down with it: nvim-tree, telescope,
      -- lualine, bufferline, gitsigns, trouble, which-key and every keymap below
      -- this point silently never loaded.
      --
      -- On main, highlighting and indentation are per-buffer opt-ins. Grammars
      -- still come from nvim-treesitter.withAllGrammars, so nothing is fetched at
      -- runtime and `ensure_installed` has no equivalent.
      vim.api.nvim_create_autocmd('FileType', {
        desc = 'Enable treesitter highlighting/indent for filetypes with a parser',
        callback = function(args)
          local lang = vim.treesitter.language.get_lang(vim.bo[args.buf].filetype)
          if not lang then return end
          if not pcall(vim.treesitter.start, args.buf, lang) then return end
          vim.bo[args.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
        end,
      })

      -- ============================================================================
      -- WORKSPACE: panels, the editing window, and what may replace what
      -- ============================================================================
      --
      -- A bare start fills the whole Kitty window (the dev layout no longer
      -- tiles terminals beside it) with, left to right:
      --
      --   keybind pane | file tree | editing window | git panel
      --
      -- Everything that is not one of the side panels is an editing window,
      -- and files AND terminals are shown there, as buffers — so a terminal
      -- is a tab in the bufferline next to the open files rather than a dock
      -- at the bottom. The helpers below answer the questions that shape
      -- raises: which window is "the" editing window when you are sitting in
      -- a panel, what a window shows once its buffer goes away, and what
      -- happens when only panels are left. neo-tree, Telescope and
      -- bufferline are set up further down and call into them, which is why
      -- this section comes first.
      local ws = {}

      -- The side panels. 'keybinds' is the keybind pane's own filetype, which
      -- is what lets neo-tree, the terminal helper and the quit logic tell it
      -- apart from a file (see KEYBIND PANE below).
      ws.KEYS_FT = 'keybinds'
      ws.panel_filetypes = { ['neo-tree'] = true, aerial = true, [ws.KEYS_FT] = true }

      -- Panel widths, by neo-tree source, used by neo-tree's setup below and
      -- to put them back after the editing window has had to be reopened.
      -- The keybind pane's is measured from its file when it opens.
      ws.widths = { filesystem = 30, buffers = 30, git_status = 40 }
      ws.keys_width = 50

      -- The fewest columns the editing window is left with before the
      -- keybind pane, then the git panel, stand aside (see FIT below). 40
      -- still admits the full layout on the 1920px laptop screen, where
      -- the editing window gets 44 (the sum is in STARTUP LAYOUT).
      ws.min_edit = 40

      local function is_float(win)
        return vim.api.nvim_win_get_config(win).relative ~= ""
      end

      -- A neo-tree opened with position 'current' (`:Neotree current`, or a
      -- directory argument) is not a side panel: it is browsing in place of a
      -- file, and neo-tree's own last-window rule skips it for that reason.
      -- Counting it as a panel would let the quit logic below end Neovim
      -- the moment it was the only window left.
      function ws.is_panel(win)
        local buf = vim.api.nvim_win_get_buf(win)
        local ft = vim.bo[buf].filetype
        if ft == 'neo-tree' and vim.b[buf].neo_tree_position == 'current' then
          return false
        end
        return ws.panel_filetypes[ft] == true
      end

      -- Claude Code's terminal. claudecode-nvim shows it in a split of its
      -- own and toggles that split by finding the window showing the
      -- buffer, so it must never become a tab of the editing window: shown
      -- there, the editing window would stop being one (see below), and
      -- <leader>cc would close it. The plugin is asked rather than the
      -- buffer guessed at; if it is missing or changes its API, no buffer
      -- is Claude's and every terminal is treated alike.
      function ws.is_claude(buf)
        local ok, term = pcall(require, 'claudecode.terminal')
        if not ok or type(term.get_active_terminal_bufnr) ~= 'function' then
          return false
        end
        local got, cbuf = pcall(term.get_active_terminal_bufnr)
        return got and cbuf == buf
      end

      -- What the bufferline shows and <Tab>/<S-Tab> cycle through: every
      -- listed buffer, files and terminals alike, except Claude's.
      function ws.is_tab(buf)
        return vim.fn.buflisted(buf) == 1 and not ws.is_claude(buf)
      end

      -- A window at the side of the layout: a panel, or Claude's split.
      -- The split is claudecode's, not a panel: nothing here opens or
      -- closes it, though restore_widths holds it to claude_width() (see
      -- there). But it is no more a place to edit in than the tree is, so
      -- FIT, the quit logic and <Tab> count it with the panels — the quit
      -- logic only beside a real panel (see QUITTING).
      function ws.is_side(win)
        return ws.is_panel(win) or ws.is_claude(vim.api.nvim_win_get_buf(win))
      end

      -- A window a file or one of our terminals may be put in. Beyond the
      -- panels this rules out floats, winfixbuf windows, diff windows (a
      -- terminal dropped into one would inherit 'diff'), and special buffers
      -- that belong to another plugin: Trouble and Neogit are 'nofile', the
      -- quickfix list is 'quickfix', and claudecode's split holds a terminal
      -- we did not create — replacing its buffer would strand the Claude
      -- session the plugin thinks is still on screen. Any other terminal
      -- (ours, or a `:terminal` you typed) is just what the window shows.
      function ws.is_editing(win)
        if not vim.api.nvim_win_is_valid(win) or is_float(win) or ws.is_panel(win) then
          return false
        end
        if vim.wo[win].winfixbuf or vim.wo[win].diff then
          return false
        end
        local buf = vim.api.nvim_win_get_buf(win)
        local bt = vim.bo[buf].buftype
        if bt == 'terminal' then
          return not ws.is_claude(buf)
        end
        return bt ~= 'nofile' and bt ~= 'quickfix' and bt ~= 'prompt'
      end

      -- The last editing window you were in, per tab. neo-tree keeps a
      -- similar history for itself; this one applies ws.is_editing, so it
      -- never lands on a panel or on Claude's split.
      vim.api.nvim_create_autocmd('WinEnter', {
        desc = 'Remember the last editing window of this tab',
        callback = function()
          local win = vim.api.nvim_get_current_win()
          if ws.is_editing(win) then
            vim.t.last_editing_win = win
          end
        end,
      })

      -- The untouched empty buffer Neovim starts with, or one made by
      -- placeholder() below: nothing in it worth keeping.
      local function is_blank(buf)
        return vim.api.nvim_buf_get_name(buf) == ""
          and vim.bo[buf].buftype == ""
          and not vim.bo[buf].modified
          and vim.api.nvim_buf_line_count(buf) == 1
          and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
      end

      -- Whether `buf` is a terminal whose job is still running.
      local function term_alive(buf)
        if not (buf and vim.api.nvim_buf_is_valid(buf) and vim.bo[buf].buftype == 'terminal') then
          return false
        end
        local chan = vim.bo[buf].channel
        return chan > 0 and vim.fn.jobwait({ chan }, 0)[1] == -1
      end

      -- The empty buffer an editing window shows when there is nothing
      -- else: after the last tab is closed, when the editing window has to
      -- be reopened, or when <leader>t hides the only terminal. It is
      -- listed, so the bufferline says honestly what the window holds
      -- ([No Name]), but 'bufhidden' = wipe removes it the moment anything
      -- replaces it, so it never lingers as a stray empty tab. Typing into
      -- it makes it a real buffer: the wipe is dropped on the first change,
      -- or switching away would refuse (E37) rather than lose the text.
      local function placeholder()
        local buf = vim.api.nvim_create_buf(true, false)
        vim.bo[buf].bufhidden = 'wipe'
        vim.api.nvim_create_autocmd('BufModifiedSet', {
          buffer = buf,
          once = true,
          desc = 'Keep a placeholder buffer once it has been typed into',
          callback = function()
            vim.bo[buf].bufhidden = ""
          end,
        })
        return buf
      end

      -- A panel with no width of ours: aerial, which fits its window to
      -- the symbols it lists (see layout_key below for what that means).
      local function sizes_itself(win)
        local buf = vim.api.nvim_win_get_buf(win)
        return vim.bo[buf].filetype ~= ws.KEYS_FT and not ws.widths[vim.b[buf].neo_tree_source or ""]
      end

      -- The width a panel is meant to have: the one you last gave it by
      -- hand (w:ws_width, see "Widths set by hand" in FIT) unless `own`,
      -- else its own for the keybind pane and neo-tree's sources;
      -- whatever it has now for a panel that sizes itself.
      local function panel_width(win, own)
        if sizes_itself(win) then
          return vim.api.nvim_win_get_width(win)
        end
        local by_hand = not own and vim.w[win].ws_width
        if type(by_hand) == 'number' then
          return by_hand
        end
        local buf = vim.api.nvim_win_get_buf(win)
        if vim.bo[buf].filetype == ws.KEYS_FT then
          return ws.keys_width
        end
        return ws.widths[vim.b[buf].neo_tree_source]
      end

      -- Claude's split in this tab, if it is showing (not as a float).
      local function claude_window()
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if not is_float(w) and ws.is_claude(vim.api.nvim_win_get_buf(w)) then
            return w
          end
        end
      end

      -- The width claudecode gives its split: split_width_percentage (30%)
      -- of the screen, 51 of 170 — also what claudecode itself puts it back
      -- to after a diff. Held to that rather than to whatever it has now,
      -- because 'equalalways' shares out a closing window's columns among
      -- every window without 'winfixwidth', Claude's split among them: the
      -- keybind pane standing aside for it would take it down to 49. Read
      -- from the plugin, falling back to its default if that moves. Given
      -- the split's window, a width you set by hand wins, as for a panel.
      local function claude_width(win)
        local by_hand = win and vim.w[win].ws_width
        if type(by_hand) == 'number' then
          return by_hand
        end
        local ok, term = pcall(require, 'claudecode.terminal')
        local pct = ok and type(term.defaults) == 'table' and term.defaults.split_width_percentage
        if type(pct) ~= 'number' or pct <= 0 or pct >= 1 then
          pct = 0.30
        end
        return math.floor(vim.o.columns * pct)
      end

      -- Notes each side window's width as the one this config left it at
      -- (w:ws_seen), so that the WinResized which follows is not taken
      -- for a width you set by hand (see the end of FIT). It is the width
      -- the window has, not the one it was meant to get: squeezed in
      -- beside two panels you showed yourself, a window can end up short
      -- of it, and FIT leaves some widths as a new window left them.
      local function note_placed()
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if not is_float(w) and ws.is_side(w) then
            vim.w[w].ws_seen = vim.api.nvim_win_get_width(w)
          end
        end
      end

      -- Puts every panel back to its width (panel_width: its own, or the
      -- one you gave it by hand), the rest going to the editing window.
      -- Needed whenever a window closes or opens beside a panel, since
      -- Neovim hands the columns to (or takes them from) whichever
      -- neighbour it likes, 'winfixwidth' notwithstanding.
      --
      -- Claude's split goes back to claude_width(). It sits right of the
      -- git panel, and a window being narrowed hands its spare columns to
      -- the window after it first, 'winfixwidth' windows excepted: left
      -- open to that, putting the git panel back to 40 would widen
      -- Claude's split rather than the editing window. So it is marked
      -- 'winfixwidth' while the panels are set, and sized last, which
      -- takes its columns from (or gives them to) the editing window. The
      -- option is then put back as claudecode left it.
      local function restore_widths()
        local claude = claude_window()
        local claude_fixed
        if claude then
          claude_fixed = vim.wo[claude].winfixwidth
          vim.api.nvim_set_option_value('winfixwidth', true, { win = claude, scope = 'local' })
        end
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if not is_float(w) and ws.is_panel(w) then
            vim.api.nvim_win_set_width(w, panel_width(w))
          end
        end
        if claude and vim.api.nvim_win_is_valid(claude) then
          vim.api.nvim_win_set_width(claude, claude_width(claude))
          vim.api.nvim_set_option_value('winfixwidth', claude_fixed, { win = claude, scope = 'local' })
        end
        note_placed()
      end

      -- Columns the editing area has once every panel in this tab has its
      -- own width and Claude's split has claude_width() (one separator
      -- column each): the split is no panel, but its columns (the width
      -- restore_widths holds it to) come out of the same row. Their own
      -- widths, not ones you set by hand: which panels FIT shows should
      -- not hang on a panel you widened (see the FIT header).
      local function edit_room()
        local room = vim.o.columns
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if not is_float(w) then
            if ws.is_panel(w) then
              room = room - panel_width(w, true) - 1
            elseif ws.is_claude(vim.api.nvim_win_get_buf(w)) then
              room = room - claude_width() - 1
            end
          end
        end
        return room
      end

      -- The tab's tiled windows, as a set, with the width of any panel
      -- that sizes itself. FIT records it, and the screen width, when it
      -- has run, and the events that trigger it compare against both, so
      -- it runs only when a window has actually opened or closed, the
      -- screen width has changed, or aerial has resized itself (see FIT).
      -- That last is the one width change FIT answers: aerial opens at 10
      -- columns and, once the symbols arrive or you add a long heading,
      -- widens itself to fit them (up to 30), which can take the editing
      -- window below ws.min_edit with no window coming or going. Other
      -- width changes are yours, and FIT keeps them (see there).
      --
      -- FIT answers it by closing panels, never by reopening them. The
      -- outline resizes to the file in front of it and to every heading
      -- added or removed, and at in-between widths (140, say) reopening
      -- as well flipped the git panel open and shut with each one. What
      -- it closed comes back the next time a window opens or closes (the
      -- outline itself, say), or the screen widens.
      local function layout_key()
        local ids = {}
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if not is_float(w) then
            table.insert(ids, w)
          end
        end
        table.sort(ids)
        for i, w in ipairs(ids) do
          if ws.is_panel(w) and sizes_itself(w) then
            ids[i] = w .. ':' .. vim.api.nvim_win_get_width(w)
          end
        end
        return table.concat(ids, ',')
      end

      -- The window ids in a layout_key() string.
      local function layout_ids(key)
        local ids = {}
        for id in key:gmatch('(%d+)[^,]*') do
          ids[tonumber(id)] = true
        end
        return ids
      end

      function ws.mark_fitted()
        vim.t.ws_layout = layout_key()
        vim.t.ws_columns = vim.o.columns
      end

      function ws.is_fitted()
        return vim.t.ws_layout == layout_key() and vim.t.ws_columns == vim.o.columns
      end

      -- t:ws_auto_hidden names the panels FIT (below) closed for lack of
      -- room, so it can bring back those and only those. Showing or hiding
      -- one yourself takes it off the list: FIT then leaves it as you set it.
      function ws.forget_auto_hidden(name)
        local hidden = vim.t.ws_auto_hidden
        if type(hidden) == 'table' and hidden[name] then
          hidden[name] = nil
          vim.t.ws_auto_hidden = hidden
        end
      end

      -- t:ws_user_shown names the panels you showed yourself (<leader>?,
      -- <leader>gs), which FIT does not close to make room: closing the
      -- one you have just asked for would make the key seem to do
      -- nothing. The other one stands aside for it instead. The mark goes
      -- when you hide the panel, and on a loss of width you did not ask
      -- for (see FIT). ws.fitting is true while FIT itself opens or closes
      -- panels, so that the neo-tree events the git panel fires then can
      -- tell its doing from yours. ws.closing_own is the panel window
      -- neo-tree or the keybind pane's key is closing just then, which is
      -- not :only closing it (see t:ws_dropped in FIT).
      ws.fitting = false
      ws.closing_own = nil

      function ws.set_user_shown(name, shown)
        local set = type(vim.t.ws_user_shown) == 'table' and vim.t.ws_user_shown or {}
        set[name] = shown or nil
        vim.t.ws_user_shown = set
      end

      -- Reopens the editing window where it belongs, between the left-hand
      -- panels and the right-hand one. Whatever closed it handed its columns
      -- to a neighbouring panel, so the panels are put back to their own
      -- widths afterwards and the new window takes the rest. With no panel
      -- to go by, Claude's split (which claudecode opens at the right-hand
      -- edge) still marks the right, so the window lands left of it rather
      -- than beyond it.
      local function open_editing_window()
        local left, right
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if not is_float(w) and ws.is_panel(w) then
            if vim.b[vim.api.nvim_win_get_buf(w)].neo_tree_position == 'right' then
              right = right or w -- windows are listed left to right
            else
              left = w
            end
          end
        end
        right = right or claude_window()
        local win = vim.api.nvim_open_win(placeholder(), false,
          left and { split = 'right', win = left }
            or right and { split = 'left', win = right }
            or { split = 'right', win = -1 })
        restore_widths()
        return win
      end

      -- Where something asked for from anywhere should go: the current
      -- window if it is an editing window, else the last one you used, else
      -- the first in the layout. Only if the tab has none left at all (a
      -- state the quit logic below normally ends) is one opened;
      -- `create = false` asks without opening one.
      function ws.main_window(create)
        local cur = vim.api.nvim_get_current_win()
        if ws.is_editing(cur) then
          return cur
        end
        -- The tab check covers a window moved out with <C-w>T, which keeps
        -- its id but now belongs to another tab.
        local last = vim.t.last_editing_win
        if last and ws.is_editing(last)
          and vim.api.nvim_win_get_tabpage(last) == vim.api.nvim_get_current_tabpage() then
          return last
        end
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if ws.is_editing(win) then
            return win
          end
        end
        if create == false then
          return nil
        end
        return open_editing_window()
      end

      -- Entering a tab lands you in its editing window, never in a panel.
      -- Plugins that send a file "back" to the previous tab — Diffview's
      -- gf, which the git panel's D leads to, and Neogit's — switch tab and
      -- run :edit in whatever window was current there, and after D that
      -- is the git panel. In a neo-tree panel neo-tree then takes the file
      -- out again with a :bdelete that closes the editing window showing
      -- it, and in the keybind pane the :edit fails outright (E1513). The
      -- price: back from a diff with <leader>gq you are in the editing
      -- window, one <C-l> from the git panel rather than in it.
      vim.api.nvim_create_autocmd('TabEnter', {
        desc = 'Enter a tab in its editing window rather than a panel',
        callback = function()
          if ws.is_panel(vim.api.nvim_get_current_win()) then
            local win = ws.main_window(false)
            if win then
              vim.api.nvim_set_current_win(win)
            end
          end
        end,
      })

      -- What a window should show when `buf` leaves it: `preferred` if that
      -- is still a listed buffer, else the window's alternate file, else the
      -- most recently used listed buffer — files first, then our terminals —
      -- else an empty placeholder (or the blank one already there). Never
      -- nothing: an editing window that closes because its buffer went away
      -- can leave the tab with only panels.
      -- Terminals we did not create are never picked; claudecode's is
      -- listed, and showing it here would put the Claude session in two
      -- windows at once. Nor are ours once their job has exited: one left
      -- on "[Process exited N]" is there to be read where it failed (see
      -- TermClose below), not to be brought back unasked.
      local function show_instead(win, buf, preferred)
        -- Blank buffers are never a choice, only the last resort: a
        -- window opened by open_editing_window has its own placeholder as
        -- its alternate file, and picking that would "show" nothing while a
        -- real tab was available.
        local function rank_of(b)
          if not (b and b > 0 and b ~= buf and vim.api.nvim_buf_is_valid(b) and vim.fn.buflisted(b) == 1)
            or is_blank(b) then
            return nil
          end
          local bt = vim.bo[b].buftype
          if bt == 'terminal' then
            return (vim.b[b].term_label and term_alive(b)) and 1 or nil
          end
          return bt == "" and 2 or 1
        end
        local target = rank_of(preferred) and preferred or nil
        if not target then
          local alt = vim.api.nvim_win_call(win, function()
            return vim.fn.bufnr('#')
          end)
          target = rank_of(alt) and alt or nil
        end
        if not target then
          local best, best_rank = nil, 0
          for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
            local r = rank_of(info.bufnr)
            if r and (r > best_rank or (r == best_rank and info.lastused > best.lastused)) then
              best, best_rank = info, r
            end
          end
          if not best then
            local cur = vim.api.nvim_win_get_buf(win)
            if cur ~= buf and is_blank(cur) then
              return -- already showing nothing; a second empty one adds nothing
            end
          end
          target = best and best.bufnr or placeholder()
        end
        vim.api.nvim_win_set_buf(win, target)
      end

      -- :bdelete, except the windows showing the buffer stay open. Plain
      -- :bdelete closes every window showing the buffer, and the editing
      -- window is usually the only one — so closing a file tab would close
      -- the editing window and leave nothing but panels. Terminals are always
      -- forced (their job is killed); modified files still refuse without !.
      function ws.close_buffer(buf, force)
        if not buf or buf == 0 then
          buf = vim.api.nvim_get_current_buf()
        end
        if not vim.api.nvim_buf_is_valid(buf) then
          return
        end
        local is_term = vim.bo[buf].buftype == 'terminal'
        if vim.bo[buf].modified and not is_term and not force then
          vim.notify(('E89: No write since last change for buffer %d (add ! to override)'):format(buf),
            vim.log.levels.ERROR)
          return
        end
        for _, win in ipairs(vim.fn.win_findbuf(buf)) do
          if ws.is_editing(win) then
            show_instead(win, buf)
          end
        end
        if is_term then
          vim.b[buf].term_closing = true -- see the TermClose handler
        end
        pcall(vim.cmd, ((is_term or force) and 'bdelete! ' or 'bdelete ') .. buf)
      end

      -- In a panel or any other non-editing window, fall back to plain
      -- :bdelete, which is what <leader>x always did there (it closes a
      -- Trouble list, for instance).
      --
      -- A terminal tab whose job is still running asks first. Terminals are
      -- ordinary tabs now, so <Tab> then <leader>x while tidying can land on
      -- Codex mid-task, and ws.close_buffer always kills the job. Plain
      -- :bdelete would refuse outright (E89); a prompt is the same guard
      -- without making you retype it as :Bdelete!, which still skips it.
      vim.api.nvim_create_user_command('Bdelete', function(o)
        if not ws.is_editing(vim.api.nvim_get_current_win()) then
          pcall(vim.cmd, 'bdelete' .. (o.bang and '!' or ""))
          return
        end
        local buf = vim.api.nvim_get_current_buf()
        local label = vim.b[buf].term_label
        if label and not o.bang and term_alive(buf)
          and vim.fn.confirm(('%s is still running. Close it and end the job?'):format(label),
            '&Yes\n&No', 2) ~= 1 then
          return
        end
        ws.close_buffer(buf, o.bang)
      end, { bang = true, desc = 'Delete the current buffer but keep its window open' })

      -- <Tab>/<S-Tab> (see keymaps): the next / previous tab in the editing
      -- window, which also becomes the current one — from the keybind pane,
      -- whose 'winfixbuf' refuses a bare :bnext (E1513), or from the outline,
      -- where :bnext would put a file in the panel. (In the tree and the
      -- git panel neo-tree's own <Tab> wins; <S-Tab> still arrives here.)
      -- With no editing window in the tab it depends where you are. In a
      -- panel or Claude's split one is opened, as a picked file would open
      -- one: acting in place would put the buffer in the panel, or into
      -- Claude's split in place of the Claude session. Anywhere else (a
      -- Diffview tab, say) it acts where you are, as :bnext always did.
      --
      -- The same order as :bnext (buffer number, wrapping), but over
      -- ws.is_tab rather than every listed buffer: a bare :bnext would stop
      -- on Claude's terminal, and with that in the editing window there is
      -- no editing window left for <leader>t or a picked file to use.
      -- Computed rather than done by repeating :bnext past it, so nothing
      -- is shown on the way through.
      vim.api.nvim_create_user_command('BufCycle', function(o)
        local win = ws.main_window(false)
        if not win and ws.is_side(vim.api.nvim_get_current_win()) then
          win = ws.main_window()
        end
        if win then
          vim.api.nvim_set_current_win(win)
        end
        local tabs = vim.tbl_filter(ws.is_tab, vim.api.nvim_list_bufs())
        local n = #tabs
        if n == 0 then
          return
        end
        local step = (o.bang and -1 or 1) * vim.v.count1
        local cur = vim.api.nvim_get_current_buf()
        local at, before = nil, 0
        for i, b in ipairs(tabs) do
          if b == cur then
            at = i
          elseif b < cur then
            before = i
          end
        end
        -- Not a tab itself (Claude's terminal, a help page): step from the
        -- gap it sits in by number, which is where :bnext would go.
        local target = at and tabs[(at - 1 + step) % n + 1]
          or tabs[(before + step + (step > 0 and -1 or 0)) % n + 1]
        if target == cur then
          return
        end
        local ok, err = pcall(vim.cmd.buffer, target)
        if not ok then
          vim.notify((tostring(err):gsub('^Vim:', "")), vim.log.levels.ERROR)
        end
      end, { bang = true, desc = 'Next buffer in the editing window (! for previous)' })

      -- ============================================================================
      -- TERMINALS: buffers in the editing window, one per number, plus Codex
      -- ============================================================================
      --
      -- Replaces toggleterm. <leader>t shows the shell in the editing window
      -- (created on first use, the same one reused after); pressing it again
      -- while that terminal is in front of you steps back to what the window
      -- showed before. A count picks the terminal: 2<leader>t is a second
      -- shell, kept apart from the first. <leader>co does the same with the
      -- `codex` CLI, which keeps running while you are elsewhere, like any
      -- hidden terminal buffer; <leader>cp and <leader>cg do the same for
      -- `opencode` and Antigravity's `agy`. From a panel these all use the
      -- editing window rather than replacing the panel.
      --
      -- Each terminal is a normal listed buffer, so it is a tab in the
      -- bufferline (named by b:term_label: "Terminal", "Terminal 2",
      -- "Codex", "OpenCode", "Antigravity"), and <Tab>/<S-Tab> cycle
      -- through terminals and files alike.
      --
      -- Claude is not one of these: claudecode-nvim (below) is an editor
      -- integration with its own split, not a bare shell, hence the
      -- asymmetry with Codex — and why its terminal is kept off the
      -- bufferline and out of <Tab>'s cycle (ws.is_tab).
      local terms = {} -- key ('shell:1', 'codex', ...) -> buffer

      -- opts.insert = false leaves you in Normal mode (used at startup, so
      -- every <leader> binding works before you have typed into the shell).
      function ws.term(key, label, cmd, opts)
        opts = opts or {}
        local win = ws.main_window()
        local buf = terms[key]

        if term_alive(buf) and vim.api.nvim_win_get_buf(win) == buf then
          if vim.api.nvim_get_current_win() == win then
            show_instead(win, buf, vim.b[buf].term_return)
            return
          end
          -- Showing, but you are in a panel: go to it rather than hide it.
          vim.api.nvim_set_current_win(win)
          if opts.insert ~= false then
            vim.cmd('startinsert')
          end
          return
        end

        if buf and not term_alive(buf) then
          -- One that failed and was kept on its exit status (see TermClose):
          -- asking for it again means a fresh one.
          ws.close_buffer(buf, true)
          buf = nil
        end

        vim.api.nvim_set_current_win(win)
        local prev = vim.api.nvim_win_get_buf(win)
        if buf then
          vim.api.nvim_win_set_buf(win, buf)
        else
          -- Reuse the window's buffer when it is the untouched empty one
          -- Neovim starts with (or a placeholder), the way :edit would, so
          -- a bare start does not leave a stray [No Name] tab beside the
          -- terminal.
          local reuse = is_blank(prev)
          buf = reuse and prev or vim.api.nvim_create_buf(true, false)
          if not reuse then
            vim.api.nvim_win_set_buf(win, buf)
          end
          local ok, job = pcall(vim.fn.jobstart, cmd, { term = true })
          if not ok or job <= 0 then
            vim.notify(('Could not start %s (%s): %s'):format(label, table.concat(cmd, ' '), tostring(job)),
              vim.log.levels.ERROR)
            if not reuse then
              show_instead(win, buf, prev)
              pcall(vim.api.nvim_buf_delete, buf, { force = true })
            end
            return
          end
          -- A placeholder's 'bufhidden' = wipe must not carry over: this
          -- buffer is a terminal now, and hiding it must keep the job.
          vim.bo[buf].bufhidden = ""
          vim.b[buf].term_label = label
          terms[key] = buf
          -- Neovim names a terminal term://{cwd}//{pid}:{cmd}, and
          -- claudecode takes any terminal on screen whose name contains
          -- "claude" for a Claude session it has lost track of. In a
          -- project such as ~/Repos/claude-code-monitor <leader>cc adopted
          -- the startup shell, the next <leader>cc hid it, closing the
          -- editing window, and QUITTING then ended Neovim. So the
          -- directory in its name becomes '.', and the rest of Neovim's
          -- name is kept. The pid keeps it unique: a fixed name can be
          -- taken already (by a terminal a session restored, say), and
          -- :file then refuses it with E95, leaving the path in. The
          -- command is what Neovim's own term:// reader starts when a
          -- session brings the buffer back, and what lualine shows. '.'
          -- rather than no directory, since neo-tree's buffer list reads
          -- it to decide whether a terminal belongs to the project. A
          -- rename leaves the old name behind as an unlisted, unloaded
          -- buffer (Vim's alternate file after :file), which <C-^> would
          -- :edit into a second shell; that is wiped, and keepalt leaves #
          -- as it was. The bufferline shows b:term_label, and <leader>t
          -- finds its terminal in `terms`, so neither goes by the name.
          local old = vim.api.nvim_buf_get_name(buf)
          local tail = old:match('^term://.-//(%d+:.*)$') or (vim.fn.jobpid(job) .. ':' .. cmd[1])
          local renamed, err = pcall(vim.api.nvim_win_call, win, function()
            vim.cmd('silent keepalt file ' .. vim.fn.fnameescape('term://.//' .. tail))
          end)
          if not renamed then
            -- Not fatal: QUITTING still keeps the editing window if Claude
            -- takes this one, but say so rather than leave it unexplained.
            vim.notify(('Could not rename %s to hide its directory from claudecode: %s'):format(label, err),
              vim.log.levels.WARN)
          end
          for _, b in ipairs(renamed and vim.api.nvim_list_bufs() or {}) do
            if b ~= buf and not vim.api.nvim_buf_is_loaded(b) and vim.api.nvim_buf_get_name(b) == old then
              pcall(vim.api.nvim_buf_delete, b, { force = true })
            end
          end
        end
        if prev ~= buf then
          vim.b[buf].term_return = prev
        end
        if opts.insert ~= false then
          vim.cmd('startinsert')
        end
      end

      -- 'shell' split the way :terminal splits it.
      local function shell_argv()
        return vim.split(vim.o.shell, ' ', { trimempty = true })
      end

      function ws.shell(n, opts)
        ws.term('shell:' .. n, n == 1 and 'Terminal' or ('Terminal ' .. n), shell_argv(), opts)
      end

      -- :TermToggle (terminal 1), :2TermToggle or :TermToggle 2 (terminal 2).
      -- From <leader>t the count arrives as v:count instead, see keymaps.
      vim.api.nvim_create_user_command('TermToggle', function(o)
        ws.shell(o.count > 0 and o.count or vim.v.count1)
      end, { count = 0, desc = 'Show or hide shell terminal N in the editing window' })

      vim.api.nvim_create_user_command('CodexToggle', function()
        ws.term('codex', 'Codex', { 'codex' })
      end, { desc = 'Show or hide the Codex CLI in the editing window' })

      -- The other agent CLIs get the same treatment: one tab each, started
      -- in Neovim's cwd (the project) on first use and kept running after.
      for _, agent in ipairs({
        { command = 'OpenCodeToggle', key = 'opencode', label = 'OpenCode', cmd = { 'opencode' } },
        { command = 'AntigravityToggle', key = 'antigravity', label = 'Antigravity', cmd = { 'agy' } },
      }) do
        vim.api.nvim_create_user_command(agent.command, function()
          ws.term(agent.key, agent.label, agent.cmd)
        end, { desc = 'Show or hide the ' .. agent.label .. ' CLI in the editing window' })
      end

      -- Notice agent edits on returning to the editor. checktime preserves
      -- unsaved buffers and reports a conflict instead of overwriting them.
      vim.opt.autoread = true
      vim.api.nvim_create_autocmd({ 'FocusGained', 'TermLeave', 'BufEnter' }, {
        group = vim.api.nvim_create_augroup('AgentFileChanges', { clear = true }),
        callback = function()
          if vim.fn.getcmdwintype() == "" then vim.cmd('checktime') end
        end,
      })

      -- When a terminal's job exits, Neovim's default TermClose handler
      -- deletes the buffer of a shell that exited cleanly — with
      -- nvim_buf_delete, which closes every window showing it. With the
      -- terminal living in the editing window, typing `exit` would close the
      -- editing window. And a terminal that exits any other way lingers as
      -- "[Process exited N]" until a keypress wipes it, which closes the
      -- window just the same.
      --
      -- So the default is swapped for one that keeps the windows. One of
      -- our terminals that exits cleanly is removed via ws.close_buffer and
      -- the window shows another tab. One that fails (Codex refusing an
      -- expired login, a shell ended with `exit 3`) is kept, on its
      -- "[Process exited N]", so the error can actually be read — toggleterm
      -- kept Codex's for the same reason — with a warning naming it. It is a
      -- dead tab, not a broken window: <leader>t / <leader>co replace it
      -- with a fresh one (term_alive), and <leader>x closes it.
      --
      -- Either way the window is dropped to Normal mode if you were typing
      -- in that terminal. Otherwise your next keys would go to whichever
      -- shell replaced it, or, on a dead one, Neovim's own "any key closes
      -- it" would delete the buffer and take the window with it.
      --
      -- Every other terminal keeps Neovim's own rule exactly. The default
      -- is found by its description; if a future Neovim renames it, it
      -- simply stays, and the worst case is the old window-closing
      -- behaviour.
      pcall(function()
        for _, au in ipairs(vim.api.nvim_get_autocmds({ group = 'nvim.terminal', event = 'TermClose' })) do
          if (au.desc or ""):find('Automatically close terminal buffers', 1, true) then
            vim.api.nvim_del_autocmd(au.id)
          end
        end
      end)

      vim.api.nvim_create_autocmd('TermClose', {
        desc = 'Remove exited terminal buffers without closing their windows',
        nested = true,
        callback = function(ev)
          -- Nothing to tidy when Neovim is exiting, or when the job died
          -- because its buffer is already being deleted: by ws.close_buffer
          -- (which marks it), or by anything else — :bd!, a picker's delete
          -- — which Neovim reports as status -1. Whatever deleted it has
          -- dealt with its windows, and "exited with status -1" would be a
          -- warning about something you just did on purpose.
          local status = vim.v.event.status
          if vim.v.exiting ~= vim.NIL or status == -1 or not vim.api.nvim_buf_is_valid(ev.buf)
            or vim.b[ev.buf].term_closing then
            return
          end
          local label = vim.b[ev.buf].term_label
          if label then
            if vim.api.nvim_get_current_buf() == ev.buf then
              vim.cmd('stopinsert')
            end
            if status ~= 0 then
              vim.notify(('%s exited with status %d'):format(label, status), vim.log.levels.WARN)
            else
              ws.close_buffer(ev.buf, true)
            end
            return
          end
          if status ~= 0 then
            return
          end
          local chan = vim.bo[ev.buf].channel
          local argv = chan > 0 and (vim.api.nvim_get_chan_info(chan).argv or {}) or {}
          if table.concat(argv, ' ') == vim.o.shell then
            vim.api.nvim_buf_delete(ev.buf, { force = true })
          end
        end,
      })

      -- ============================================================================
      -- KEYBIND PANE: ~/.config/nvim/KEYBINDS.md, read-only, far left
      -- ============================================================================
      --
      -- The reference generated from the keymaps attrset in neovim.nix. It is
      -- a scratch copy of the file rather than the file itself: an unlisted
      -- 'nofile' buffer never shows in the bufferline, is never followed by
      -- neo-tree's follow_current_file, and cannot be written back over a
      -- file home-manager owns. It is re-read from disk each time it opens.
      --
      -- Its own filetype is the marker everything else keys on (neo-tree's
      -- open_files_do_not_replace_types, ws.is_panel, and through that
      -- Telescope's get_selection_window), and 'winfixbuf' makes :e or
      -- :bnext typed in the pane refuse (E1513) rather than quietly turn the
      -- pane into a file; <Tab>/<S-Tab> go through :BufCycle, which switches
      -- the editing window instead. Highlighting comes from the markdown
      -- treesitter parser, registered for the filetype so the FileType
      -- autocmd above starts it.
      vim.treesitter.language.register('markdown', ws.KEYS_FT)

      local keys = { path = vim.fn.stdpath('config') .. '/KEYBINDS.md' }

      local function keys_window()
        for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if vim.bo[vim.api.nvim_win_get_buf(win)].filetype == ws.KEYS_FT then
            return win
          end
        end
      end

      -- The file's lines, and the width a pane showing them takes: the
      -- widest line and one column of air, with no gutter to pay for — but
      -- never more than a third of the screen; a capped pane wraps instead
      -- (see 'linebreak' below). Nothing when there is no file.
      local function keys_measure()
        if vim.fn.filereadable(keys.path) == 0 then
          return nil
        end
        local lines = vim.fn.readfile(keys.path)
        local widest = 0
        for _, l in ipairs(lines) do
          widest = math.max(widest, vim.fn.strdisplaywidth(l))
        end
        return lines, math.min(widest + 1, math.floor(vim.o.columns / 3))
      end

      -- `quiet` is for startup and FIT: a missing file just means no pane.
      function ws.keys_open(quiet)
        if keys_window() then
          return
        end
        local lines, width = keys_measure()
        if not lines then
          if not quiet then
            vim.notify(keys.path .. ' not found', vim.log.levels.WARN)
          end
          return
        end

        if not (keys.buf and vim.api.nvim_buf_is_loaded(keys.buf)) then
          if keys.buf and vim.api.nvim_buf_is_valid(keys.buf) then
            pcall(vim.api.nvim_buf_delete, keys.buf, { force = true })
          end
          keys.buf = vim.api.nvim_create_buf(false, true) -- unlisted scratch
          pcall(vim.api.nvim_buf_set_name, keys.buf, 'keybinds://KEYBINDS.md')
          vim.bo[keys.buf].filetype = ws.KEYS_FT
        end
        local buf = keys.buf
        vim.bo[buf].modifiable = true
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        vim.bo[buf].modifiable = false
        vim.bo[buf].modified = false
        ws.keys_width = width

        -- win = -1 splits the whole screen, so this lands at the far left
        -- whatever else is open; nothing is focused.
        local win = vim.api.nvim_open_win(buf, false, { split = 'left', win = -1, width = ws.keys_width })
        for opt, val in pairs({
          number = false, relativenumber = false, signcolumn = 'no', foldcolumn = '0',
          statuscolumn = "", cursorline = false, list = false, spell = false,
          wrap = true, linebreak = true, breakindent = true,
          winfixwidth = true, winfixbuf = true,
        }) do
          vim.api.nvim_set_option_value(opt, val, { win = win, scope = 'local' })
        end
      end

      function ws.keys_toggle()
        ws.forget_auto_hidden('keys')
        local win = keys_window()
        if win then
          ws.set_user_shown('keys', false)
          ws.closing_own = win
          pcall(vim.api.nvim_win_close, win, false)
          ws.closing_own = nil
        else
          ws.keys_open(false)
          -- Asked for: FIT makes room by hiding the git panel, not this.
          ws.set_user_shown('keys', keys_window() ~= nil)
        end
      end

      vim.api.nvim_create_user_command('KeybindsToggle', ws.keys_toggle,
        { desc = 'Show or hide the keybind reference pane' })

      -- neo-tree and aerial dock "left" by splitting the whole screen, which
      -- puts them to the left of everything, the keybind pane included —
      -- so reopening the file tree with <leader>e would otherwise leave it
      -- outside the pane. After any window appears the pane is moved back to
      -- the far left, and the panels are given their widths again (the move
      -- re-lays the row, handing the pane's columns to a neighbour).
      --
      -- WinNew alone is not enough: aerial opens its split with :noautocmd,
      -- so no WinNew fires for it. WinResized does, because Neovim raises it
      -- from the main loop once the layout has changed, and :noautocmd cannot
      -- suppress it. Both are cheap no-ops while the pane is already leftmost.
      vim.api.nvim_create_autocmd({ 'WinNew', 'WinResized' }, {
        desc = 'Keep the keybind pane leftmost',
        callback = function()
          vim.schedule(function()
            local win = keys_window()
            if not win or vim.fn.win_screenpos(win)[2] <= 1 then
              return
            end
            vim.api.nvim_win_call(win, function()
              vim.cmd('wincmd H')
            end)
            restore_widths()
          end)
        end,
      })

      -- ============================================================================
      -- FIT: panels stand aside when the editing window would be too narrow
      -- ============================================================================
      --
      -- The full layout takes 126 columns of panels and separators (see
      -- STARTUP LAYOUT), which suits the workspace-wide Kitty window the
      -- dev layout opens (170) and nothing narrower: in a half-screen Kitty
      -- (85) it would leave the editing window, and the shell started in
      -- it, one column wide. And it is not only a bare `nvim` in a small
      -- terminal. Hyprland re-tiles the dev layout's window whenever
      -- another joins its workspace, and Kitty may start Neovim before the
      -- compositor has given the window its size, so even there the width
      -- at startup cannot be trusted. Nor is it only the screen: Claude's
      -- split takes 30% of the row (51 of 170), and the outline its own
      -- share, from every window in it, the keybind pane and the editing
      -- window included. At 170 Claude's split left the editing window 1
      -- column, and the outline left it 33, below ws.min_edit.
      --
      -- So the keybind pane and then the git panel only open while the
      -- editing window keeps ws.min_edit columns; when a resize, a new
      -- window or the outline widening itself takes it below that they
      -- close, in that order, and when the columns come back they reopen
      -- in the reverse one — only those this closed, never one you closed
      -- yourself, and not merely because the outline narrowed again (see
      -- layout_key). The file tree always stays: it is the narrowest and
      -- the one you navigate by. Startup is the same rule, applied to panels
      -- that begin "closed for lack of room". So at 170, opening Claude
      -- hides the keybind pane (the editing window gets
      -- 170 - (30 + 40 + 51 + 3 separators) = 46) and closing it brings
      -- the pane back.
      --
      -- Nor is one you showed yourself closed to make room (see
      -- ws.set_user_shown): showing the keybind pane hides the git panel
      -- if both do not fit, and showing the git panel hides the keybind
      -- pane; with both shown by hand the editing window makes do with
      -- what is left. That holds until width is lost to something you did
      -- not ask for there and then — the screen narrowing, or Claude's
      -- split opening — after which both are FIT's again.
      --
      -- Widths set by hand stay. FIT puts the panels, and Claude's split,
      -- back to their widths (restore_widths) after a window has come or
      -- gone, since Neovim hands a closing window's columns to whichever
      -- neighbour it likes and takes a new one's from wherever it can.
      -- But a panel you widened or narrowed with <C-w>>, <C-w>< or the
      -- mouse has that as its width from then on (w:ws_width, recorded by
      -- the WinResized autocmd at the end of this section), so a :help
      -- split coming and going, or the outline, does not undo it. Which
      -- panels stand aside is still judged by their own widths (see
      -- edit_room), so the columns you give a panel come out of the
      -- editing window, as they did when you gave them, and do not also
      -- keep the keybind pane from coming back after Claude's split. Its
      -- width is its own again when it is closed and reopened, or when the
      -- screen width changes, which shares the whole row out afresh anyway.
      --
      -- Per tab, on the tab you are in, whenever its tiled windows or the
      -- screen width are not what FIT last saw: when a window opens or
      -- closes, on VimResized, and on entering a tab after a resize while
      -- you were in another (Diffview's, say). See the autocmds at the
      -- end of this section.
      local function git_window()
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          local b = vim.api.nvim_win_get_buf(w)
          if vim.b[b].neo_tree_source == 'git_status' and ws.is_panel(w) and not is_float(w) then
            return w
          end
        end
      end

      -- neo-tree docks "right" at the far right-hand edge, which with
      -- Claude's split open is beyond it: the git panel lands right of
      -- the split and takes its 40 columns out of it, leaving 10 of 51 at
      -- 170. That is whoever opens it — FIT bringing it back, or
      -- <leader>gs, the usual way to get it back after hiding it for room
      -- — so both come here (FIT's open below; neo-tree's after-open
      -- event for the rest). The split is moved back to the edge, which
      -- re-lays the row, and the caller then puts the widths back.
      -- Returns whether it moved anything.
      local function git_left_of_claude()
        local claude, git = claude_window(), git_window()
        if claude and git and vim.fn.win_screenpos(git)[2] > vim.fn.win_screenpos(claude)[2] then
          vim.api.nvim_win_call(claude, function()
            vim.cmd('wincmd L')
          end)
          return true
        end
        return false
      end

      local fit_panels = {
        keys = {
          window = keys_window,
          width = function()
            local _, width = keys_measure()
            return width
          end,
          open = function() ws.keys_open(true) end,
          close = function(win) pcall(vim.api.nvim_win_close, win, false) end,
        },
        git = {
          window = git_window,
          width = function() return ws.widths.git_status end,
          -- The restore_widths that follows any change FIT makes sizes
          -- the row once the split is back at the edge.
          open = function()
            pcall(vim.cmd, 'Neotree show git_status right')
            git_left_of_claude()
          end,
          close = function() pcall(vim.cmd, 'Neotree close git_status') end,
        },
      }

      -- Closes the panels that must stand aside and reopens those that
      -- fit again (unless `reopen` is false, see ws.fit), returning
      -- whether it did either. Apart from ws.fit so that ws.fitting is
      -- cleared however it ends.
      local function stand_aside(hidden, shown, reopen)
        local changed = false
        for _, name in ipairs({ 'keys', 'git' }) do
          if edit_room() >= ws.min_edit then
            break
          end
          local p = fit_panels[name]
          local win = p.window()
          if win and not shown[name] then
            p.close(win)
            hidden[name] = true
            changed = true
          end
        end
        for _, name in ipairs(reopen and { 'git', 'keys' } or {}) do
          if hidden[name] then
            local p = fit_panels[name]
            local width = p.width()
            if p.window() or not width then
              hidden[name] = nil -- reopened by hand since, or no file to show
            elseif edit_room() - width - 1 >= ws.min_edit then
              p.open()
              hidden[name] = nil
              changed = true
            else
              break -- the keybind pane only comes back after the git panel
            end
          end
        end
        return changed
      end

      function ws.fit()
        if vim.v.exiting ~= vim.NIL then
          return
        end
        -- Nothing but panels and Claude's split: the editing window has
        -- just gone, and QUITTING (below) is about to reopen it or end the
        -- tab — or, with only Claude's split left, leave the tab be.
        -- Panels reopened for it now would only be undone, or crowd a tab
        -- that has no editing window to make room for.
        local sides_only, any_side = true, false
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if not is_float(w) then
            if ws.is_side(w) then
              any_side = true
            else
              sides_only = false
            end
          end
        end
        if sides_only then
          return
        end

        -- What has happened since FIT last ran in this tab: a window
        -- closed or opened, Claude's split newly opened (its window is
        -- new, whether claudecode reopened it or you did), the screen
        -- width changed — not on FIT's first run in a tab, which has no
        -- width to compare with: that is a new tab, not a new screen
        -- width. Every window is new on that first run.
        local before = type(vim.t.ws_layout) == 'string' and layout_ids(vim.t.ws_layout) or {}
        local now = layout_ids(layout_key())
        local closed, opened = false, false
        for id in pairs(before) do
          closed = closed or not now[id]
        end
        for id in pairs(now) do
          opened = opened or not before[id]
        end
        local claude = claude_window()
        local claude_new = claude ~= nil and not before[claude]
        local resized = type(vim.t.ws_columns) == 'number' and vim.o.columns ~= vim.t.ws_columns
        local narrower = resized and vim.o.columns < vim.t.ws_columns

        -- :only or <C-w>o in the editing window has put every panel away,
        -- and Claude's split with them. FIT's lists of panels it hid and
        -- panels you showed go too, as QUITTING clears them when only
        -- Claude's split is left: otherwise the keybind pane FIT hid for
        -- the outline or the split would come straight back into the tab
        -- you have just cleared. But the last panel on screen put away
        -- with its own key — the tree with <leader>e in a window too
        -- narrow for the rest, say — is not a cleared tab, and the panels
        -- FIT hid should still come back when there is room. Counting the
        -- windows that went cannot tell the two apart, since with the tree
        -- the only panel :only closes just the one too. What can is how
        -- the panel went (t:ws_dropped, set by the autocmd below): :only
        -- closes it from the window it is typed in, while its own key has
        -- neo-tree or ws.keys_toggle close it (ws.closing_own), and :q or q
        -- typed in the panel closes it from inside itself. The outline and
        -- Claude's split never count: their keys close them from the
        -- editing window without a word, so :only with only those two on
        -- screen leaves the lists be. The mark is for this run alone.
        local dropped = vim.t.ws_dropped
        vim.t.ws_dropped = nil
        if dropped and not any_side then
          vim.t.ws_auto_hidden = nil
          vim.t.ws_user_shown = nil
        end

        -- A new screen width shares the row out afresh, so the widths you
        -- set by hand go with it (see the FIT header).
        if resized then
          for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
            vim.w[w].ws_width = nil
          end
        end

        -- A panel you showed stays yours while it is on screen, until the
        -- screen narrows or Claude's split opens. The mark is dropped
        -- rather than skipped over, so a panel FIT then closes is brought
        -- back by FIT when the room returns, like any other it closed.
        local shown = type(vim.t.ws_user_shown) == 'table' and vim.t.ws_user_shown or {}
        for name in pairs(shown) do
          local p = fit_panels[name]
          if narrower or claude_new or not (p and p.window()) then
            shown[name] = nil
          end
        end
        vim.t.ws_user_shown = shown

        -- With no window come or gone and the same screen width, what
        -- brought FIT here is the outline resizing itself (layout_key),
        -- and that only ever closes panels: see there.
        local hidden = type(vim.t.ws_auto_hidden) == 'table' and vim.t.ws_auto_hidden or {}
        ws.fitting = true
        local ok, changed = pcall(stand_aside, hidden, shown, opened or closed or resized)
        ws.fitting = false
        vim.t.ws_auto_hidden = hidden
        if not ok then
          error(changed, 0)
        end

        -- Widths are put back even when no panel had to open or close, if
        -- a side window is off its width in a way a window coming or going
        -- explains (the widths put back being yours where you set them;
        -- see the FIT header). Narrower always counts, since a window
        -- opening beside one squeezes it: Claude's split takes columns
        -- from the keybind pane, and a git panel opened beyond the split
        -- (see git_left_of_claude) leaves it 10.
        --
        -- Wider counts only after a window has closed, since its columns
        -- go to a neighbour, a panel as often as not; after the screen
        -- width has changed, since a wider screen hands its new columns
        -- to the rightmost window without 'winfixwidth' (with Claude's
        -- split open, the split) and a width set by hand has gone with
        -- the old one; and, for Claude's split, when it has just opened.
        -- Not whenever FIT runs: another plugin building a tab can pass
        -- through a window still showing a panel's buffer — Diffview,
        -- after D in the git panel, splits its tab off that panel — and
        -- narrowing that one to 40 would leave one side of the diff 40
        -- columns wide.
        local off = false
        for _, w in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
          if not is_float(w) then
            local width = vim.api.nvim_win_get_width(w)
            if ws.is_panel(w) then
              local want = panel_width(w)
              off = width < want or ((closed or resized) and width > want)
            elseif ws.is_claude(vim.api.nvim_win_get_buf(w)) then
              local want = claude_width(w)
              off = width < want or ((claude_new or closed or resized) and width > want)
            end
            if off then
              break
            end
          end
        end
        if changed or off then
          restore_widths()
        else
          -- Left as they are, a wider one included, and not to be taken
          -- for widths you set when the WinResized for them arrives.
          note_placed()
        end
        ws.mark_fitted()
      end

      -- Window events fire for far more than a window opening or closing
      -- in this tab: every float (Telescope, which-key, completion), every
      -- <C-w>> — and entering a tab says nothing about whether it changed
      -- while you were away. So each refits only when the tab's tiled
      -- windows or the screen width are not what FIT last saw
      -- (ws.is_fitted), or aerial has resized itself (layout_key). WinResized
      -- is there for aerial: it opens its split under :noautocmd, so no
      -- WinNew fires for it, and widening itself to its symbols is no
      -- window event at all. Neovim raises WinResized from the main loop
      -- once the layout has changed, and :noautocmd cannot suppress that.
      --
      -- A panel closed from another window, and not by its own key or FIT,
      -- is marked as dropped for FIT (t:ws_dropped, see there): that is
      -- :only or <C-w>o. The outline is left out, as its key closes it
      -- from the editing window too, without a word.
      vim.api.nvim_create_autocmd({ 'VimResized', 'TabEnter', 'WinNew', 'WinClosed', 'WinResized' }, {
        desc = 'Close or reopen side panels to keep the editing window usable',
        callback = function(ev)
          local win = ev.event == 'WinClosed' and tonumber(ev.match)
          if win and vim.api.nvim_win_is_valid(win) and not is_float(win)
            and not ws.fitting and win ~= ws.closing_own and win ~= vim.api.nvim_get_current_win()
            and ws.is_panel(win) and vim.bo[vim.api.nvim_win_get_buf(win)].filetype ~= 'aerial' then
            vim.t[vim.api.nvim_win_get_tabpage(win)].ws_dropped = true
          end
          vim.schedule(function()
            if not ws.is_fitted() then
              ws.fit()
            end
          end)
        end,
      })

      -- Widths set by hand (see the FIT header). A WinResized that finds
      -- the tab's tiled windows and the screen width just as FIT left
      -- them is no window coming or going: it is <C-w>>, <C-w><,
      -- :vertical resize or a separator dragged with the mouse. Every
      -- side window it changed keeps its new width, the neighbour that
      -- gave up or took the columns included, since that is the row as
      -- you left it. The widths FIT and restore_widths set, or left as a
      -- new window made them, arrive here too, a tick later, and are told
      -- apart by w:ws_seen (note_placed): only a width other than the one
      -- last seen is new. WinResized fires for a change of height alone
      -- too (the screen a line shorter, 'cmdheight'), and a panel
      -- squeezed short of its own width, whose width had not moved, was
      -- taken for one you chose. A width set here is noted as seen in
      -- turn, so resizing a panel back to where FIT had it still counts.
      -- Checked at once, not scheduled, so that it sees the layout the
      -- resize happened in.
      vim.api.nvim_create_autocmd('WinResized', {
        desc = 'Keep the width of a side panel resized by hand',
        callback = function()
          if not ws.is_fitted() then
            return
          end
          for _, w in ipairs(vim.v.event.windows or {}) do
            if vim.api.nvim_win_is_valid(w) and not is_float(w) and ws.is_side(w)
              and not (ws.is_panel(w) and sizes_itself(w)) then
              local width = vim.api.nvim_win_get_width(w)
              if width ~= vim.w[w].ws_seen then
                vim.w[w].ws_width = width
                vim.w[w].ws_seen = width
              end
            end
          end
        end,
      })

      -- ============================================================================
      -- QUITTING: only panels left means done
      -- ============================================================================
      --
      -- neo-tree's close_if_last_window only knows a lone tree, so a keybind
      -- pane, a git panel or an outline beside it would be left on screen
      -- with nothing to edit after :q in the editing window. This replaces it
      -- (it is switched off in neo-tree's setup below) with one rule for
      -- every panel: when a window closes and the tab holds only panels,
      -- close the tab — or quit, if it is the last one. Unsaved files stop
      -- it: the first is put back in an editing window with a warning, as
      -- neo-tree does for its own case.
      --
      -- Claude's split counts as a panel here (ws.is_side), as long as a
      -- real panel is left beside it. It is not one to edit in, and left
      -- out, :q or :bd in the editing window beside it did nothing at all:
      -- the tab was left with no editing window, and the next <Tab> put a
      -- buffer into Claude's split. So :q quits as it does beside the
      -- panels (ending the Claude session with the rest), and :bd reopens
      -- the editing window. A tab with nothing but Claude's split is left
      -- as it is, though: that is <C-w>o or :only in the split, or :q in
      -- the one file beside it outside the layout (`nvim README.md`), and
      -- all three leave you working with Claude, not done. Quitting there
      -- would end the session, and every shell and Codex with it, without
      -- a prompt. <Tab> in it opens an editing window again (:BufCycle).
      --
      -- Only a window YOU closed counts. Deleting the buffer an editing
      -- window shows (:bd, :bw, `d` in the buffer list, <M-d> in Telescope's
      -- buffer picker) also closes that window — Neovim closes every window
      -- showing a deleted buffer unless it is the last one — and treating
      -- that as a quit would end Neovim, killing every shell and Codex with
      -- it, when you only meant to drop one tab. The two are told apart by
      -- the buffer: :q, :close and <C-q> leave it listed (hidden), deletion
      -- does not. A buffer that wipes itself when hidden ('bufhidden', as
      -- the placeholder <leader>t leaves behind does) is gone either way, so
      -- for that one the command decides: QuitPre fires for :q, :wq, :x and
      -- <C-q> but not for :bd, so only a quit counts as closed. (:close and
      -- <C-w>c raise no QuitPre, so on a placeholder they reopen it; on
      -- anything else they close as before.) After a deletion the editing
      -- window is reopened instead, showing whatever ws.close_buffer would
      -- have shown.
      --
      -- Nor does a window showing Claude's terminal count, whatever closed
      -- it: <leader>cc hides the split and the session carries on. Only
      -- panels are left after it when claudecode has taken the editing
      -- window's terminal for its own, which it does by name (see
      -- ws.term; a :terminal you typed in a project whose path holds
      -- "claude" still qualifies), and quitting then would end every
      -- shell, Codex and the Claude session without a prompt. The editing
      -- window is reopened instead, as after a deletion. Whether the
      -- buffer was Claude's is asked there and then: by the time the
      -- scheduled check runs claudecode may have let it go.
      --
      -- Scheduled, and re-checked when it runs, because windows close one at
      -- a time during :tabclose or a plugin tearing down its layout, and only
      -- the state once that settles counts. neo-tree's own rule was a second
      -- scheduled WinClosed handler acting on whatever tab was current by
      -- then, which is why it is off rather than left alongside this one.
      --
      -- The QuitPre flag is cleared on the next tick, so a :q that was
      -- refused cannot leave it set for a later :bd. The WinClosed a :q
      -- causes fires before that, inside the command.
      local quitting = false
      vim.api.nvim_create_autocmd('QuitPre', {
        desc = 'Tell a quit from a buffer deletion (see WinClosed below)',
        callback = function()
          quitting = true
          vim.schedule(function()
            quitting = false
          end)
        end,
      })

      vim.api.nvim_create_autocmd('WinClosed', {
        desc = 'Close the tab, or quit, when only side panels are left',
        callback = function(ev)
          local closing = tonumber(ev.match)
          if not closing or not vim.api.nvim_win_is_valid(closing) or is_float(closing) then
            return
          end
          local tab = vim.api.nvim_win_get_tabpage(closing)
          local cbuf = vim.api.nvim_win_get_buf(closing)
          local self_wiping = ({ delete = true, wipe = true })[vim.bo[cbuf].bufhidden]
          local was_listed = vim.bo[cbuf].buflisted and not (self_wiping and quitting)
          local was_claude = ws.is_claude(cbuf)
          local from = vim.api.nvim_get_current_win()
          vim.schedule(function()
            if vim.v.exiting ~= vim.NIL or not vim.api.nvim_tabpage_is_valid(tab) then
              return
            end
            local tiled = vim.tbl_filter(function(w)
              return not is_float(w)
            end, vim.api.nvim_tabpage_list_wins(tab))
            if #tiled == 0 then
              return
            end
            local panel = false
            for _, w in ipairs(tiled) do
              if not ws.is_side(w) then
                return
              end
              panel = panel or ws.is_panel(w)
            end
            -- Claude's split alone: see above. Every panel in the tab was
            -- put away, so FIT's lists of panels it hid (the keybind pane,
            -- for the split) and panels you showed are cleared too: the
            -- editing window <Tab> reopens comes back on its own, rather
            -- than with a keybind pane FIT would otherwise bring back while
            -- the tree and the git panel stay closed.
            if not panel then
              vim.t[tab].ws_auto_hidden = nil
              vim.t[tab].ws_user_shown = nil
              return
            end

            -- Built from inside that tab (`:bd N` can empty a tab you are
            -- not looking at, and that should not switch you to it). Focus:
            -- after :bd typed in the window that went, you land in its
            -- replacement. From a panel (`d` in the buffer list) you stay in
            -- the panel, to carry on deleting. From a picker's float nothing
            -- moves while it is open — leaving the prompt would close it —
            -- and the replacement is focused once it closes, since the
            -- window the picker would return to is the one that went.
            -- Claude's terminal is never what the replacement shows
            -- (show_instead passes over the buffer that went).
            if was_claude or (was_listed and not (vim.api.nvim_buf_is_valid(cbuf) and vim.bo[cbuf].buflisted)) then
              local win = vim.api.nvim_win_call(tiled[1], function()
                local w = open_editing_window()
                show_instead(w, cbuf)
                return w
              end)
              if from == closing then
                vim.api.nvim_set_current_win(win)
              elseif vim.api.nvim_win_is_valid(from) and is_float(from) then
                vim.api.nvim_create_autocmd('WinClosed', {
                  pattern = tostring(from),
                  once = true,
                  callback = vim.schedule_wrap(function()
                    if vim.api.nvim_win_is_valid(win) then
                      vim.api.nvim_set_current_win(win)
                    end
                  end),
                })
              end
              return
            end

            vim.api.nvim_set_current_tabpage(tab)
            for _, info in ipairs(vim.fn.getbufinfo({ buflisted = 1 })) do
              local bt = vim.bo[info.bufnr].buftype
              if info.changed == 1 and (bt == "" or bt == 'acwrite') then
                local win = ws.main_window()
                vim.api.nvim_win_set_buf(win, info.bufnr)
                vim.api.nvim_set_current_win(win)
                vim.notify(('Not quitting: %s has unsaved changes'):format(
                  vim.fn.fnamemodify(info.name, ':~:.')), vim.log.levels.WARN)
                return
              end
            end

            local cmd = #vim.api.nvim_list_tabpages() > 1 and 'tabclose' or 'qall'
            local ok, err = pcall(vim.cmd, cmd)
            if not ok then
              vim.api.nvim_set_current_win(ws.main_window())
              vim.notify(tostring(err), vim.log.levels.ERROR)
            end
          end)
        end,
      })

      -- ============================================================================
      -- FILE EXPLORER / GIT PANEL: neo-tree (placed panels, no dock manager)
      -- ============================================================================
      --
      -- Two of Zed's docks come from this one plugin, because each neo-tree
      -- source owns its own window position:
      --
      --   filesystem  -> left   (Zed's project_panel)
      --   git_status  -> right  (Zed's git_panel)
      --
      -- That is why there is no edgy.nvim here. edgy exists to force windows
      -- to edges for plugins that cannot place themselves; neo-tree and
      -- aerial both can, so edgy would only add a second opinion about where
      -- things belong — and its own README documents neo-tree but not
      -- nvim-tree, which is the combination we would have been relying on.
      -- The one placement neither plugin can express, "left, but right of the
      -- keybind pane", is the WinNew/WinResized autocmd in KEYBIND PANE above.
      require('neo-tree').setup({
        -- Off: QUITTING above replaces it. It covered a lone tree only, and
        -- as a second WinClosed handler scheduled alongside that one it could
        -- run its `q!` in whichever tab the first had left current, closing
        -- the wrong window or quitting outright.
        close_if_last_window = false,
        popup_border_style = 'rounded',
        enable_git_status = true,
        enable_diagnostics = true,
        sources = { 'filesystem', 'buffers', 'git_status' },

        -- Space is <leader>, and neo-tree maps it in every one of its
        -- windows (this top-level `window` is merged into each source's) to
        -- toggle_node, with nowait = false so that a brisk <leader>e still
        -- gets through. But pause for longer than 'timeoutlen' (300ms) —
        -- exactly what you do when you want which-key's list — and the
        -- folder under the cursor toggles instead, and the list never
        -- shows. Unmapped, Space in the tree and the git panel is the
        -- leader as it is everywhere else. Folders still open and close
        -- with <CR> (neo-tree's `open` toggles a directory), and C closes
        -- the one the cursor is in. 'none' is neo-tree's own "no mapping",
        -- not a command called none.
        window = {
          mappings = {
            ['<space>'] = 'none',
          },
        },

        -- Native version of the setting every edgy thread ends up recommending:
        -- never open a file INTO one of these panels, or the file evicts the
        -- panel it landed in. Entries match a filetype OR a buftype. The
        -- default list starts with 'terminal', left out on purpose: the shell
        -- lives in the editing window as a tab, and a file opened from the
        -- tree belongs in that window next to it, as another tab. 'keybinds'
        -- is the keybind pane (its 'winfixbuf' would refuse the file anyway,
        -- but with an error instead of a quiet skip).
        open_files_do_not_replace_types = {
          'keybinds', 'Trouble', 'trouble', 'qf', 'aerial',
          'NeogitStatus', 'NeogitPopup', 'DiffviewFiles', 'notify',
        },

        event_handlers = {
          -- With 'terminal' off that list, neo-tree's "last window you were
          -- in" rule would also accept claudecode's terminal split and open
          -- the file over the Claude session. Pushing the editing window
          -- ws.main_window picks (which never counts that split) onto the end
          -- of neo-tree's window history makes it the one chosen. That
          -- history is internal to neo-tree, hence the guards: if it moves,
          -- neo-tree just falls back to its own choice.
          --
          -- With no editing window left in the tab, one is reopened in its
          -- slot rather than letting neo-tree split one off beside the
          -- panel it came from, which leaves a 20-column window on the far
          -- side of the git panel. It happens when a file is :edit-ed into
          -- a panel (a stray :e, a plugin): neo-tree takes it back out
          -- with a :bdelete that also closes the editing window if that
          -- showed the same file. `:Neotree current` browses in place of
          -- the file and is left to open where it is.
          {
            event = 'file_open_requested',
            handler = function(args)
              local win = ws.main_window(false)
              local state = type(args) == 'table' and args.state or {}
              if not win and state.current_position ~= 'current' then
                win = ws.main_window()
              end
              local ok, utils = pcall(require, 'neo-tree.utils')
              if not (win and ok and type(utils.prior_windows) == 'table') then
                return
              end
              local tab = vim.api.nvim_get_current_tabpage()
              utils.prior_windows[tab] = utils.prior_windows[tab] or {}
              table.insert(utils.prior_windows[tab], win)
            end,
          },
          -- Opening or closing the git panel yourself (<leader>gs) takes it
          -- off FIT's list of panels to bring back when there is room, and
          -- opening it marks it as yours, so FIT hides the keybind pane to
          -- make room for it rather than the panel you asked for (see
          -- ws.set_user_shown). FIT's own opens and closes come through
          -- here too, synchronously, and ws.fitting sets them apart.
          --
          -- Opened yourself with Claude's split open, it also lands beyond
          -- the split (see git_left_of_claude in FIT), which is moved back
          -- to the edge. Scheduled, because this runs in the middle of
          -- neo-tree setting up the window; by then FIT, scheduled by the
          -- WinNew, has made room, so the widths are put back here.
          {
            event = 'neo_tree_window_after_open',
            handler = function(args)
              if type(args) == 'table' and args.source == 'git_status' and not ws.fitting then
                ws.forget_auto_hidden('git')
                ws.set_user_shown('git', true)
                vim.schedule(function()
                  if git_left_of_claude() then
                    restore_widths()
                  end
                end)
              end
            end,
          },
          -- neo-tree closes its panels itself for their keys (<leader>e,
          -- <leader>b, <leader>gs, q in the panel), between these two
          -- events; :only closes them without it, so the window is noted
          -- for FIT to tell the two apart (ws.closing_own, t:ws_dropped).
          {
            event = 'neo_tree_window_before_close',
            handler = function(args)
              ws.closing_own = type(args) == 'table' and args.winid or nil
            end,
          },
          {
            event = 'neo_tree_window_after_close',
            handler = function(args)
              ws.closing_own = nil
              if type(args) == 'table' and args.source == 'git_status' and not ws.fitting then
                ws.forget_auto_hidden('git')
                ws.set_user_shown('git', false)
              end
            end,
          },
        },

        filesystem = {
          window = { position = 'left', width = ws.widths.filesystem },
          follow_current_file = { enabled = true },
          -- Watch rather than poll, so a `nixos-rebuild` writing into the tree
          -- shows up without a manual refresh.
          use_libuv_file_watcher = true,
          filtered_items = {
            visible = true,
            hide_dotfiles = false,
            hide_gitignored = true,
          },
        },

        git_status = {
          window = {
            position = 'right',
            width = ws.widths.git_status,
            mappings = {
              -- D, because the git_status source already spends <cr> (open),
              -- the g-prefixed git actions (ga gu gU gt gr gc gp gl gg), A, i,
              -- b, the o-prefixed sorts and the global tree keys (d is
              -- delete), while the tree's own `D` (fuzzy_finder_directory) is
              -- filesystem-only, so it is free here. Opens Diffview on just
              -- that path — a directory shows every change under it — in its
              -- own tab; <leader>gq closes it. Documented as the docOnly `D`
              -- in the keymaps attrset, and shown by `?` in the panel.
              --
              -- This Diffview lists untracked files whatever paths it is
              -- given (its `git ls-files --others` ignores them) and selects
              -- the first entry, so a tracked file would open behind a list
              -- of every untracked file in the repo, showing one of those.
              -- For a tracked file untracked ones are turned off; either way
              -- --selected-file puts the one under the cursor in front.
              ['D'] = {
                function(state)
                  local node = state.tree:get_node()
                  if not node or not node.path or node.type == 'message' then
                    return
                  end
                  local status = node.extra and node.extra.git_status
                  local untracked = type(status) == 'string' and status:find('?', 1, true) ~= nil
                  local args = { '--selected-file=' .. node.path }
                  if node.type == 'file' and not untracked then
                    table.insert(args, '--untracked-files=no')
                  end
                  vim.list_extend(args, { '--', node.path })
                  require('diffview').open(args)
                end,
                desc = 'diff in Diffview',
              },
            },
          },
        },

        buffers = {
          window = { position = 'left', width = ws.widths.buffers },
          follow_current_file = { enabled = true },
        },
      })

      -- ============================================================================
      -- AERIAL: symbol outline (mirrors Zed's outline_panel)
      -- ============================================================================

      require('aerial').setup({
        layout = {
          default_direction = 'left',
          placement = 'edge',
          max_width = { 30, 0.2 },
        },
        -- 'window', NOT 'global'. attach_mode = 'global' is the setting
        -- behind folke/lazy.nvim#1762, where the main window shrinks every
        -- time focus leaves the outline. That report involved edgy, which
        -- this config no longer uses, but the setting is the trigger and
        -- 'window' is the documented way out — so keep it either way.
        attach_mode = 'window',
        close_automatic_events = {},
        -- LSP first, treesitter as the fallback. Matches how the rest of this
        -- config resolves symbols, and means filetypes with a parser but no
        -- server still get an outline.
        backends = { 'lsp', 'treesitter', 'markdown', 'man' },
      })

      -- ============================================================================
      -- TELESCOPE: fuzzy finder
      -- ============================================================================

      local telescope = require('telescope')
      telescope.setup({
        defaults = {
          file_ignore_patterns = { "node_modules", ".git", "__pycache__", "target" },
          -- Telescope opens its pick in whichever window it was started from.
          -- Started from the tree or the git panel that would replace the
          -- panel, and from the keybind pane it would hit 'winfixbuf' and
          -- fail; the editing window is where a picked file belongs.
          get_selection_window = function()
            return ws.main_window()
          end,
        }
      })
      telescope.load_extension('fzf')

      -- ============================================================================
      -- LUALINE: status line
      -- ============================================================================

      require('lualine').setup({
        options = {
          theme = 'ayu_dark',
          component_separators = { left = '|', right = '|'},
          section_separators = { left = "", right = ""},
        }
      })

      -- ============================================================================
      -- BUFFERLINE: buffer tabs
      -- ============================================================================

      -- Terminals are tabs here too (see TERMINALS). name_formatter shows
      -- their b:term_label instead of the tail of a term://…//1234:/bin/zsh
      -- name, and closing a tab with the mouse goes through ws.close_buffer
      -- so the editing window survives it. The default close commands are
      -- `bdelete! %d`, forced, and ws.close_buffer(n, true) keeps that.
      -- Clicking a tab defaults to `buffer %d` in the current window, which
      -- from a panel would put the file in the panel (or hit the keybind
      -- pane's 'winfixbuf'); it opens in the editing window instead.
      --
      -- custom_filter keeps Claude's terminal off the line (ws.is_tab): it
      -- has its own split, and clicked into the editing window it would
      -- leave no editing window behind. The offsets start the tabs clear of
      -- the side panels instead of over the keybind reference. bufferline
      -- only offsets for the outermost window on each side, so with the
      -- keybind pane open they begin over the tree; hide it and they begin
      -- over the editing window. The 'neo-tree' entry is also what keeps
      -- them off the git panel on the right.
      require('bufferline').setup({
        options = {
          mode = 'buffers',
          numbers = 'none',
          diagnostics = 'nvim_lsp',
          show_buffer_close_icons = true,
          show_close_icon = false,
          custom_filter = function(buf)
            return ws.is_tab(buf)
          end,
          offsets = {
            { filetype = ws.KEYS_FT, text = 'Keybinds', separator = true },
            { filetype = 'neo-tree', separator = true },
          },
          name_formatter = function(buf)
            return vim.b[buf.bufnr].term_label
          end,
          left_mouse_command = function(n)
            vim.api.nvim_set_current_win(ws.main_window())
            vim.cmd.buffer(n)
          end,
          close_command = function(n)
            ws.close_buffer(n, true)
          end,
          right_mouse_command = function(n)
            ws.close_buffer(n, true)
          end,
        }
      })

      -- ============================================================================
      -- GITSIGNS: git integration
      -- ============================================================================

      require('gitsigns').setup({
        signs = {
          add = { text = '+' },
          change = { text = '~' },
          delete = { text = '_' },
          topdelete = { text = '‾' },
          changedelete = { text = '~' },
        }
      })

      -- ============================================================================
      -- INDENT BLANKLINE: indent guides
      -- ============================================================================

      require('ibl').setup({
        indent = { char = '│' },
      })

      -- ============================================================================
      -- COMMENT: easy commenting
      -- ============================================================================

      require('Comment').setup()

      -- ============================================================================
      -- AUTOPAIRS: auto close brackets
      -- ============================================================================

      require('nvim-autopairs').setup()

      -- ============================================================================
      -- TROUBLE: better diagnostics
      -- ============================================================================

      require('trouble').setup()

      -- ============================================================================
      -- NEOGIT + DIFFVIEW: full git UI and diff viewer
      -- ============================================================================

      -- `kind = 'tab'` on purpose: neo-tree's git_status source is already the
      -- docked, Zed-style git panel on the right. Neogit is the full staging
      -- and committing UI, so it gets its own tab rather than fighting for an
      -- edge with the panels that live there.
      require('neogit').setup({
        kind = 'tab',
        integrations = { diffview = true },
        graph_style = 'unicode',
      })

      require('diffview').setup({
        enhanced_diff_hl = true,
      })

      -- ============================================================================
      -- CLAUDE CODE
      -- ============================================================================

      -- terminal_cmd is left nil on purpose: the plugin defaults to `claude`,
      -- which claude-code-nix already puts on PATH. Pinning a store path here
      -- would freeze the CLI at whatever revision this rebuild happened to see.
      --
      -- Proposed edits are reviewed in a tab of their own. In the current
      -- tab claudecode opens the diff beside the first window that is not a
      -- terminal, float or a sidebar it knows (neo-tree, aerial and so on),
      -- and the keybind pane, far left, is none of those: the review diff
      -- was squeezed into ~30 columns between the reference and the tree,
      -- and the editing window down to ~11. The tab closes on accept or
      -- reject, which returns you to the layout as it was.
      require('claudecode').setup({
        auto_start = true,
        track_selection = true,
        diff_opts = { open_in_new_tab = true },
      })

      -- Claude showing you a file (its openFile tool) :edits it in the
      -- first window that is not a terminal, a 'nofile' buffer, a float or
      -- a sidebar it knows. While the editing window is on a Terminal tab
      -- there is none — the keybind pane is 'nofile' too — so claudecode
      -- falls back to a :vsplit beside the tree, and the editing column is
      -- cut in two. So while the editing window shows a terminal it is
      -- handed a placeholder first ('bufhidden' = wipe, buftype ""), which
      -- the search does pick: the file replaces it as a new tab (:edit
      -- takes over an empty [No Name] buffer rather than leaving it
      -- behind, resetting its options), and the terminal stays a tab
      -- beside it. If the file does not end up there after all (an error,
      -- or `preview`, which opens a preview window instead) the terminal
      -- is put back and the placeholder, hidden, wipes itself.
      --
      -- The handler is kept twice: in the tool registry, which a call
      -- reads it from, and in the tool's own module, which the registry
      -- is refilled from each time the server starts (:ClaudeCodeStart
      -- after :ClaudeCodeStop). Both are replaced. The server loads the
      -- registry as 'claudecode.tools.init', which Lua caches apart from
      -- 'claudecode.tools': the latter would be a second, empty registry
      -- that no call ever reads, so it is looked up under both names in
      -- package.loaded rather than required. This is claudecode's
      -- internal API, hence every check: if it moves, openFile simply
      -- keeps the plugin's own behaviour.
      pcall(function()
        local open_file = require('claudecode.tools.open_file')
        local original = type(open_file) == 'table' and open_file.handler
        if type(original) ~= 'function' then
          return
        end
        local function handler(params, ...)
          local win = ws.main_window(false)
          local term = win and vim.api.nvim_win_get_buf(win)
          local stand_in
          if term and vim.bo[term].buftype == 'terminal' then
            stand_in = placeholder()
            vim.api.nvim_win_set_buf(win, stand_in)
          end
          local result = vim.F.pack_len(pcall(original, params, ...))
          -- is_blank as well as the number: :edit in an empty [No Name]
          -- buffer reuses it for the file, number and all.
          if stand_in and vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(term)
            and vim.api.nvim_win_get_buf(win) == stand_in and is_blank(stand_in) then
            vim.api.nvim_win_set_buf(win, term)
          end
          if not result[1] then
            error(result[2], 0) -- as raised: claudecode reads {code, message} tables
          end
          return unpack(result, 2, result.n)
        end
        open_file.handler = handler
        for _, name in ipairs({ 'claudecode.tools.init', 'claudecode.tools' }) do
          local registry = type(package.loaded[name]) == 'table' and package.loaded[name].tools
          if type(registry) == 'table' and type(registry.openFile) == 'table'
            and registry.openFile.handler == original then
            registry.openFile.handler = handler
          end
        end
      end)

      -- ============================================================================
      -- WHICH-KEY: keybinding hints
      -- ============================================================================

      -- Group labels only. The bindings themselves are generated further down
      -- from the keymaps attrset in neovim.nix, and each carries its own
      -- `desc`, which is what which-key actually renders per key.
      local wk = require('which-key')
      wk.setup()
      wk.add({
        { '<leader>f', group = 'find' },
        { '<leader>g', group = 'git' },
        { '<leader>c', group = 'code / AI' },
        { '<leader>x', group = 'diagnostics' },
      })

      -- ============================================================================
      -- COLORIZER: color preview
      -- ============================================================================

      require('colorizer').setup()

      -- ============================================================================
      -- KEYMAPS (generated)
      -- ============================================================================
      --
      -- Everything below is rendered from the `keymaps` attrset at the top of
      -- neovim.nix, which also renders ~/.config/nvim/KEYBINDS.md — the file
      -- the keybind pane shows. Do not add bindings here by hand: one added
      -- here would work but would be missing from the on-screen reference,
      -- which is the exact drift this generation exists to prevent.
      --
      -- Buffer-local LSP bindings are the deliberate exception. They are set in
      -- on_attach above because they only make sense where a server is
      -- attached, and they appear in the reference as `docOnly` entries.

      ${keymapLua}

      -- ============================================================================
      -- STARTUP LAYOUT
      -- ============================================================================
      --
      -- The dev layout (SUPER + SHIFT + RETURN / SUPER + CTRL + RETURN) now
      -- opens Neovim alone, filling the workspace, so the reference and the
      -- shell that used to be separate Kitty windows beside it live in here:
      --
      --   keybind pane | file tree (30) | editing window | git panel (40)
      --
      -- The editing window starts on a shell terminal, which is a tab in the
      -- bufferline like any file opened after it; in a git work tree the git
      -- panel is open so the changes are in view from the start (D on one
      -- opens its diff). Outline is <leader>o. Every panel toggles, and they
      -- are worth toggling: a 1920px screen is 170 columns at Kitty's 14pt,
      -- and the editing window gets what the panels leave of them,
      --
      --   170 - (53 + 30 + 40 + 3 separators) = 44
      --
      -- (keybind pane 53: the widest line of KEYBINDS.md plus a column of
      -- air, so it moves with the descriptions; tree 30; git panel 40).
      -- That 44 is the figure the rest of this file refers to. <leader>?
      -- alone gives back 54, the pane and its separator, so that and
      -- <leader>gs are the first to hide when code needs width.
      -- In anything narrower FIT does that for you: the keybind pane and
      -- the git panel start "closed for lack of room" and open only if the
      -- editing window keeps ws.min_edit columns, so a half-screen Kitty
      -- gets the tree and a usable editing window, and the panels arrive
      -- the moment the window is widened.
      --
      -- Built with `show` and a no-enter split, so focus never leaves the
      -- editing window and nothing has to be walked back with wincmd. The
      -- shell starts in Normal mode, so every <leader> binding works before
      -- you have typed into it; `i` is the way in.
      --
      -- Only on a truly bare start: no file arguments, no piped stdin, no
      -- session (-S), and nothing a -c/+ command, -q or -t has already put
      -- on screen — an extra tab (`nvim +Neogit`, `nvim -c DiffviewOpen`),
      -- an extra window, or a buffer in the one window (`nvim -q errs.txt`,
      -- `nvim -c 'e README.md'`). Those all run before VimEnter with
      -- argc() == 0, and building the layout over them buried the file
      -- asked for under the shell, or squeezed Diffview's diff to one
      -- column. `nvim file.rs`, `git commit` and `:terminal` editors are
      -- unaffected, as before.
      --
      -- `nested`, because autocmds do not fire inside a non-nested one, and
      -- the layout depends on some that would otherwise be skipped: above
      -- all Neovim's own TermOpen defaults for the startup shell, which make
      -- a terminal buffer non-modifiable (without them Normal-mode `dd`
      -- rewrites the shell's screen text), drop the line numbers and sign
      -- column, and add the [[ / ]] prompt jumps. Without it the first
      -- Terminal tab behaves unlike every terminal opened after it.
      vim.api.nvim_create_autocmd('VimEnter', {
        desc = 'Build the full-screen layout on a bare start',
        nested = true,
        callback = function()
          if vim.fn.argc() > 0 or vim.g.started_with_stdin or vim.v.this_session ~= ""
            or #vim.api.nvim_list_tabpages() > 1 or #vim.api.nvim_tabpage_list_wins(0) > 1
            or not is_blank(vim.api.nvim_get_current_buf()) then
            return
          end
          local main = vim.api.nvim_get_current_win()
          vim.t.last_editing_win = main
          -- Tree before the keybind pane: both split the whole screen to the
          -- left, so whichever goes second ends up outermost. FIT opens the
          -- keybind pane and the git panel, as far as the width allows.
          --
          -- The git panel only inside a git work tree. Anywhere else
          -- neo-tree's git_status source still opens, reading "working tree
          -- clean", which is not so much untrue as meaningless, and costs
          -- 41 columns. <leader>gs opens it all the same. ('.git' may be a
          -- file, in a worktree or a submodule; vim.fs.root finds either.)
          pcall(vim.cmd, 'Neotree show filesystem left')
          local in_work_tree = vim.fs.root(vim.fn.getcwd(), '.git') ~= nil
          vim.t.ws_auto_hidden = { git = in_work_tree or nil, keys = true }
          ws.fit()
          vim.api.nvim_set_current_win(main)
          ws.shell(1, { insert = false })
        end,
      })

      vim.api.nvim_create_autocmd('StdinReadPre', {
        desc = 'Remember that stdin was piped in, so VimEnter can skip the layout',
        callback = function()
          vim.g.started_with_stdin = true
        end,
      })

      -- ============================================================================
      -- FORMATTING: conform
      -- ============================================================================
      --
      -- This replaced a BufWritePre autocmd that matched file globs and called
      -- vim.lsp.buf.format. Two things were wrong with that. First, '*.php' also
      -- matches '*.blade.php' and '*.html' also covers Django templates, and in
      -- both cases the server attached to the plain-language file is attached to
      -- the template too — Intelephense would have reformatted the PHP inside a
      -- Blade view, the HTML server would have reflowed {% %} tags. conform keys
      -- on filetype, which keeps those apart.
      --
      -- Second, editor.nix has Zed format CSS, HTML, JSON, JSONC, JS, TS, TSX,
      -- YAML, GraphQL and Markdown with prettier, while the language servers for
      -- those languages use formatters of their own. Routing both editors
      -- through prettier keeps a file byte-identical whichever one saved it.
      -- Markdown has no language server here at all, so prettier is the only
      -- thing that formats it.
      --
      -- Filetypes not listed fall through to the language server, which is what
      -- formats Rust, Nix, Lua, TOML, Terraform, PHP, Slint, LaTeX and systemd
      -- units. nginx is the one server here that advertises no formatting at
      -- all, so .conf files are left alone.
      local prettier = { 'prettier' }
      require('conform').setup({
        formatters_by_ft = {
          javascript = prettier,
          javascriptreact = prettier,
          typescript = prettier,
          typescriptreact = prettier,
          css = prettier,
          scss = prettier,
          less = prettier,
          html = prettier,
          json = prettier,
          jsonc = prettier,
          yaml = prettier,
          markdown = prettier,
          graphql = prettier,
          python = { 'ruff_format' },
          sh = { 'shfmt' },
          bash = { 'shfmt' },
          blade = { 'blade-formatter' },
        },
        formatters = {
          -- prettier and ruff are deliberately left to PATH resolution so a
          -- project-local copy in node_modules/.bin or a venv wins — the same
          -- thing Zed does — falling back to the pinned nixpkgs build that
          -- modules/software/development.nix puts on PATH. shfmt and
          -- blade-formatter have no project-local convention, so they are
          -- pinned to the store the way editor.nix pins them.
          shfmt = {
            command = '${pkgs.shfmt}/bin/shfmt',
            -- Zed passes '-i 2 -ci'; conform derives -i from shiftwidth (2).
            prepend_args = { '-ci' },
          },
          ['blade-formatter'] = {
            command = '${pkgs.blade-formatter}/bin/blade-formatter',
          },
        },
        format_on_save = {
          timeout_ms = 3000,
          lsp_format = 'fallback',
        },
      })

      -- Defined globally rather than in on_attach so it also reaches Markdown
      -- and Blade, which conform formats but no attached server does.
      --
      -- '<leader>cf', not '<leader>f': <leader>f is the Telescope prefix
      -- (ff/fg/fb/fh further down), and a mapping on the prefix itself makes
      -- every one of those wait out 'timeoutlen' before firing. This sits with
      -- <leader>ca (code action) under a 'c' for code instead.
      vim.keymap.set({ 'n', 'v' }, '<leader>cf', function()
        require('conform').format({ async = true, lsp_format = 'fallback' })
      end, { desc = 'Format buffer' })
    '';
  };

  # The keybind reference Neovim shows in its own leftmost pane on a bare
  # start (and on <leader>?). initLua reads it from stdpath('config'), i.e.
  # here, and simply opens no pane if it is missing, so the file and the
  # layout can change independently without breaking startup.
  #
  # Rendered from the same `keymaps` attrset that generates the vim.keymap.set
  # calls above, which is the whole point: the pane cannot document a binding
  # that does not exist, or miss one that does.
  xdg.configFile."nvim/KEYBINDS.md".text = keybindsMarkdown;
}
