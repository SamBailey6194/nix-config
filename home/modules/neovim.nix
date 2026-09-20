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
      toggleterm-nvim          # Terminal integration
      trouble-nvim             # Better diagnostics
      nvim-colorizer-lua       # Color preview

      # Outline — mirrors Zed's outline_panel (left dock, under the file tree)
      aerial-nvim

      # Git panel — mirrors Zed's git_panel (right dock)
      neogit
      diffview-nvim
      plenary-nvim             # neogit's dependency; telescope pulls it in too

      # Claude Code, as an editor integration rather than a bare shell: it can
      # take the current buffer or selection as context and review diffs in
      # place. Codex has no such plugin and runs in a toggleterm instead.
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
      -- to edges for plugins that cannot place themselves; neo-tree, aerial
      -- and toggleterm all can, so edgy would only add a second opinion about
      -- where things belong — and its own README documents neo-tree but not
      -- nvim-tree, which is the combination we would have been relying on.
      require('neo-tree').setup({
        close_if_last_window = true,
        popup_border_style = 'rounded',
        enable_git_status = true,
        enable_diagnostics = true,
        sources = { 'filesystem', 'buffers', 'git_status' },

        -- Native version of the setting every edgy thread ends up recommending:
        -- never open a file INTO one of these panels, or the file evicts the
        -- panel it landed in. The default covers terminal/Trouble/qf/edgy; the
        -- rest are the panels this config adds.
        open_files_do_not_replace_types = {
          'terminal', 'Trouble', 'trouble', 'qf', 'aerial', 'toggleterm',
          'NeogitStatus', 'NeogitPopup', 'DiffviewFiles', 'notify',
        },

        filesystem = {
          window = { position = 'left', width = 30 },
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
          window = { position = 'right', width = 40 },
        },

        buffers = {
          window = { position = 'left', width = 30 },
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
          file_ignore_patterns = { "node_modules", ".git", "__pycache__", "target" }
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

      require('bufferline').setup({
        options = {
          mode = 'buffers',
          numbers = 'none',
          diagnostics = 'nvim_lsp',
          show_buffer_close_icons = true,
          show_close_icon = false,
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
      -- TOGGLETERM: terminal
      -- ============================================================================

      -- A bottom dock rather than a float, so the shape matches Zed's terminal
      -- dock. `open_mapping` is deliberately unset: every binding in this
      -- config comes from the keymaps attrset in neovim.nix, and a plugin
      -- registering its own would be invisible to the generated reference.
      require('toggleterm').setup({
        direction = 'horizontal',
        size = 15,
        start_in_insert = true,
        persist_size = true,
        shade_terminals = false,
      })

      -- Codex gets its own toggleterm instance rather than sharing the default
      -- shell, so toggling it away leaves the session running and does not
      -- disturb whatever is in the plain terminal. Claude is handled by
      -- claudecode-nvim below, which is a real editor integration rather than
      -- a shell, hence the asymmetry between the two.
      local Terminal = require('toggleterm.terminal').Terminal
      local codex = Terminal:new({
        cmd = 'codex',
        hidden = true,
        direction = 'horizontal',
        close_on_exit = false,
      })

      vim.api.nvim_create_user_command('CodexToggle', function()
        codex:toggle()
      end, { desc = 'Toggle the Codex CLI in its own terminal' })

      -- ============================================================================
      -- TROUBLE: better diagnostics
      -- ============================================================================

      require('trouble').setup()

      -- ============================================================================
      -- NEOGIT + DIFFVIEW: git panel (mirrors Zed's git_panel)
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
      require('claudecode').setup({
        auto_start = true,
        track_selection = true,
      })

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
      -- neovim.nix, which also renders ~/.config/nvim/KEYBINDS.md — the file the
      -- dev layout shows in its top-right pane. Do not add bindings here by
      -- hand: one added here would work but would be missing from the on-screen
      -- reference, which is the exact drift this generation exists to prevent.
      --
      -- Buffer-local LSP bindings are the deliberate exception. They are set in
      -- on_attach above because they only make sense where a server is
      -- attached, and they appear in the reference as `docOnly` entries.

      ${keymapLua}

      -- ============================================================================
      -- STARTUP LAYOUT
      -- ============================================================================
      --
      -- Opens the file tree and the terminal dock, which is the shape Zed
      -- actually starts in: project_panel open, the other docks present but
      -- toggled on demand. Outline is <leader>o and the git panel <leader>gs;
      -- each plugin places its own window, so they land on the right edge
      -- whenever you open them without anything having to manage the layout.
      --
      -- Deliberately not opening all four: the dev layout gives Neovim 75% of a
      -- 1920px screen, and a tree plus an outline plus a git panel would leave
      -- roughly 60 columns for code.
      --
      -- Skipped when nvim was given a file or piped stdin, so `nvim file.rs`,
      -- `git commit` and `:terminal` editors are unaffected.
      vim.api.nvim_create_autocmd('VimEnter', {
        desc = 'Open the default dock layout on a bare start',
        callback = function()
          if vim.fn.argc() > 0 or vim.g.started_with_stdin then
            return
          end
          -- Tree first so it claims the left edge before anything else maps.
          vim.cmd('Neotree show filesystem left')
          vim.cmd('ToggleTerm')
          -- Land the cursor back in the editing window rather than the tree or
          -- the terminal, so typing immediately goes where you expect.
          vim.schedule(function()
            pcall(vim.cmd, 'wincmd k')
            pcall(vim.cmd, 'wincmd l')
          end)
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

  # The keybind reference the Neovim dev layout shows in its top-right pane
  # (SUPER + SHIFT + RETURN / SUPER + CTRL + RETURN). rust/dev-layout looks for
  # it at $HOME/.config/nvim/KEYBINDS.md — see NVIM_KEYBINDS_REL there — and
  # falls back to a plain shell if it is missing, so the two can be changed
  # independently without breaking the layout.
  #
  # Rendered from the same `keymaps` attrset that generates the vim.keymap.set
  # calls above, which is the whole point: the pane cannot document a binding
  # that does not exist, or miss one that does.
  xdg.configFile."nvim/KEYBINDS.md".text = keybindsMarkdown;
}
