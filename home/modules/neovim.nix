{ config, pkgs, lib, ... }:

let
  # Language servers not carried by nixpkgs, or carried too old — see pkgs/*.nix
  # for why. Same derivations modules/software/development.nix puts on PATH.
  laravel-ls = pkgs.callPackage ../../pkgs/laravel-ls.nix { };
  django-template-lsp = pkgs.callPackage ../../pkgs/django-template-lsp.nix { };
  htmx-lsp = pkgs.callPackage ../../pkgs/htmx-lsp.nix { };
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

      # File explorer
      nvim-tree-lua            # File tree
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
          vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
          vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
          vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
          vim.keymap.set('n', '[d', function() vim.diagnostic.jump({ count = -1, float = true }) end, opts)
          vim.keymap.set('n', ']d', function() vim.diagnostic.jump({ count = 1, float = true }) end, opts)
          -- <leader>e belongs to NvimTreeToggle further down; a buffer-local
          -- binding here would shadow it in every buffer with a server attached.
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
      -- FILE EXPLORER: nvim-tree
      -- ============================================================================

      require('nvim-tree').setup({
        view = {
          width = 30,
          side = 'left',
        },
        renderer = {
          group_empty = true,
        },
        filters = {
          dotfiles = false,
        },
      })

      vim.keymap.set('n', '<leader>e', ':NvimTreeToggle<CR>', { noremap = true, silent = true })

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

      vim.keymap.set('n', '<leader>ff', ':Telescope find_files<CR>', { noremap = true })
      vim.keymap.set('n', '<leader>fg', ':Telescope live_grep<CR>', { noremap = true })
      vim.keymap.set('n', '<leader>fb', ':Telescope buffers<CR>', { noremap = true })
      vim.keymap.set('n', '<leader>fh', ':Telescope help_tags<CR>', { noremap = true })

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

      require('toggleterm').setup({
        direction = 'float',
        float_opts = {
          border = 'curved',
        }
      })

      vim.keymap.set('n', '<C-`>', ':ToggleTerm<CR>', { noremap = true })

      -- ============================================================================
      -- TROUBLE: better diagnostics
      -- ============================================================================

      require('trouble').setup()

      vim.keymap.set('n', '<leader>xx', ':Trouble diagnostics toggle<CR>', { noremap = true })
      vim.keymap.set('n', '<leader>xw', ':Trouble diagnostics toggle filter.buf=0<CR>', { noremap = true })

      -- ============================================================================
      -- WHICH-KEY: keybinding hints
      -- ============================================================================

      require('which-key').setup()

      -- ============================================================================
      -- COLORIZER: color preview
      -- ============================================================================

      require('colorizer').setup()

      -- ============================================================================
      -- ADDITIONAL KEYMAPS
      -- ============================================================================

      -- Clear search highlight
      vim.keymap.set('n', '<leader>h', ':nohlsearch<CR>', { noremap = true })

      -- Save file
      vim.keymap.set('n', '<C-s>', ':w<CR>', { noremap = true })

      -- Quit
      vim.keymap.set('n', '<C-q>', ':q<CR>', { noremap = true })

      -- Window navigation
      vim.keymap.set('n', '<C-h>', '<C-w>h', { noremap = true })
      vim.keymap.set('n', '<C-j>', '<C-w>j', { noremap = true })
      vim.keymap.set('n', '<C-k>', '<C-w>k', { noremap = true })
      vim.keymap.set('n', '<C-l>', '<C-w>l', { noremap = true })

      -- Buffer navigation
      vim.keymap.set('n', '<Tab>', ':bnext<CR>', { noremap = true })
      vim.keymap.set('n', '<S-Tab>', ':bprevious<CR>', { noremap = true })
      vim.keymap.set('n', '<leader>x', ':bdelete<CR>', { noremap = true })

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
}
