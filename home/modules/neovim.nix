{ config, pkgs, lib, ... }:

{
  # Neovim configuration with Lua
  # Reuses the same LSP servers and linters as Zed
  # All LSP servers are in modules/software/development.nix

  programs.neovim = {
    enable = true;
    defaultEditor = false;  # Zed is still the default (EDITOR=zed in common.nix)
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

      local lspconfig = require('lspconfig')
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

      -- LSP keymaps (on attach)
      local on_attach = function(client, bufnr)
        local opts = { buffer = bufnr, noremap = true, silent = true }

        vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
        vim.keymap.set('n', 'gD', vim.lsp.buf.declaration, opts)
        vim.keymap.set('n', 'gi', vim.lsp.buf.implementation, opts)
        vim.keymap.set('n', 'gr', vim.lsp.buf.references, opts)
        vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)
        vim.keymap.set('n', '<C-k>', vim.lsp.buf.signature_help, opts)
        vim.keymap.set('n', '<leader>rn', vim.lsp.buf.rename, opts)
        vim.keymap.set('n', '<leader>ca', vim.lsp.buf.code_action, opts)
        vim.keymap.set('n', '<leader>f', vim.lsp.buf.format, opts)
        vim.keymap.set('n', '[d', vim.diagnostic.goto_prev, opts)
        vim.keymap.set('n', ']d', vim.diagnostic.goto_next, opts)
        vim.keymap.set('n', '<leader>e', vim.diagnostic.open_float, opts)
      end

      -- Capabilities for completion
      local capabilities = require('cmp_nvim_lsp').default_capabilities()

      -- Python: pyright + ruff
      lspconfig.pyright.setup({
        on_attach = on_attach,
        capabilities = capabilities,
        settings = {
          python = {
            analysis = {
              diagnosticsMode = "workspace",
              typeCheckingMode = "basic",
            }
          }
        }
      })

      -- TypeScript/JavaScript
      lspconfig.ts_ls.setup({
        on_attach = on_attach,
        capabilities = capabilities,
      })

      -- ESLint
      lspconfig.eslint.setup({
        on_attach = on_attach,
        capabilities = capabilities,
      })

      -- Rust
      lspconfig.rust_analyzer.setup({
        on_attach = on_attach,
        capabilities = capabilities,
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

      -- Lua
      lspconfig.lua_ls.setup({
        on_attach = on_attach,
        capabilities = capabilities,
        settings = {
          Lua = {
            diagnostics = {
              globals = { 'vim' }
            }
          }
        }
      })

      -- Nix
      lspconfig.nil_ls.setup({
        on_attach = on_attach,
        capabilities = capabilities,
      })

      -- HTML, CSS, JSON (from vscode-langservers-extracted)
      lspconfig.html.setup({ on_attach = on_attach, capabilities = capabilities })
      lspconfig.cssls.setup({ on_attach = on_attach, capabilities = capabilities })
      lspconfig.jsonls.setup({ on_attach = on_attach, capabilities = capabilities })

      -- ============================================================================
      -- TREESITTER
      -- ============================================================================

      require('nvim-treesitter.configs').setup({
        highlight = { enable = true },
        indent = { enable = true },
        ensure_installed = {}, -- Managed by Nix
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

      -- Format on save (using LSP)
      vim.api.nvim_create_autocmd('BufWritePre', {
        pattern = { '*.py', '*.rs', '*.ts', '*.tsx', '*.js', '*.jsx', '*.lua', '*.nix' },
        callback = function()
          vim.lsp.buf.format({ async = false })
        end,
      })
    '';
  };
}
