{ config, pkgs, lib, ... }:

let
  # Language servers not carried by nixpkgs — see pkgs/*.nix for why.
  laravel-ls = pkgs.callPackage ../../pkgs/laravel-ls.nix { };
  django-template-lsp = pkgs.callPackage ../../pkgs/django-template-lsp.nix { };

  # Zed resolves a language server by downloading its own copy unless
  # `lsp.<server>.binary` names one. Every pin below points at the same store
  # path modules/software/development.nix puts on PATH, so Zed and Neovim run
  # byte-identical servers and a fresh machine needs no network to get LSP.
  bin = path: args: { binary = { inherit path; arguments = args; }; };
in
{
  # Zed editor configuration
  # Comprehensive settings for development workflow
  #
  # NOTE: We use home.file ONLY (not programs.zed-editor) because:
  # 1. The programs.zed-editor module creates its own config symlinks
  # 2. Using both causes "Read-only file system" errors during activation
  # 3. home.file gives us full control over the JSON structure
  #
  # The Zed package is installed via home.packages below.

  # Install Zed editor package
  home.packages = [ pkgs.zed-editor ];

  # Full Zed settings.json configuration
  # Using home.file with force = true to handle upgrades cleanly
  home.file.".config/zed/settings.json" = {
    force = true;  # Replace existing file/symlink
    text = builtins.toJSON {
      # Debugger
      debugger = {
        dock = "bottom";
      };

      # Theme and appearance
      theme = "Ayu Dark";
      ui_font_size = 16;
      buffer_font_family = "Ubuntu Mono";
      buffer_font_size = 16.0;

      # Editor behavior
      format_on_save = "on";
      tab_size = 2;
      show_whitespaces = "selection";
      autosave = "on_focus_change";
      vim_mode = false;

      # Terminal
      terminal = {
        shell = { program = "${pkgs.zsh}/bin/zsh"; };
        max_scroll_history_lines = 100000;
        font_size = 14.0;
        font_family = "Ubuntu Mono";
      };

      # File scanning exclusions
      file_scan_exclusions = [
        "**/.git"
        "**/node_modules"
        "**/__pycache__"
        "**/target"
        "**/.venv"
        "**/dist"
        "**/build"
      ];

      # Project panel
      project_panel = {
        button = true;
        dock = "left";
        default_width = 280;
        auto_reveal_entries = true;
        auto_fold_dirs = false;
        git_status = true;
      };

      # Git integration
      git = {
        git_gutter = "tracked_files";
        inline_blame = {
          enabled = true;
        };
      };

      # Git "Changes" panel on the RIGHT dock (project panel stays on the left),
      # grouped by folder (tree). Flip tree_view to false for a flat file list —
      # both modes are also toggleable from the panel's context menu.
      git_panel = {
        button = true;
        dock = "right";
        tree_view = true;
        default_width = 280;
      };

      # Panels
      outline_panel = {
        button = true;
        dock = "left";
      };

      collaboration_panel = {
        button = false;
      };

      notification_panel = {
        button = false;
      };

      agent = {
        button = true;
        dock = "right";
        default_width = 480;
      };

      # Tab bar
      tab_bar = {
        show = true;
        show_nav_history_buttons = true;
      };

      tabs = {
        close_position = "right";
        file_icons = true;
        git_status = true;
      };

      # Language-specific settings
      languages = {
        Python = {
          tab_size = 4;
          format_on_save = "on";
          colorize_brackets = true;
          show_edit_predictions = true;
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          formatter = {
            external = {
              command = "ruff";
              arguments = [ "format" "-" ];
            };
          };
          language_servers = [ "pyright" "ruff" ];
          code_actions_on_format = {
            "source.fixAll" = true;
            "source.organizeImports.ruff" = true;
          };
        };

        TypeScript = {
          format_on_save = "on";
          colorize_brackets = true;
          formatter = "prettier";
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          code_actions_on_format = {
            "source.fixAll.eslint" = true;
            "source.organizeImports" = true;
          };
        };

        TSX = {
          format_on_save = "on";
          colorize_brackets = true;
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          formatter = "prettier";
          code_actions_on_format = {
            "source.fixAll.eslint" = true;
            "source.organizeImports" = true;
          };
        };

        JavaScript = {
          format_on_save = "on";
          colorize_brackets = true;
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          formatter = "prettier";
          code_actions_on_format = {
            "source.fixAll.eslint" = true;
          };
        };

        Markdown = {
          format_on_save = "on";
          colorize_brackets = true;
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          formatter = "prettier";
        };

        JSON = {
          format_on_save = "on";
          colorize_brackets = true;
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          formatter = "prettier";
        };

        JSONC = {
          format_on_save = "on";
          colorize_brackets = true;
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          formatter = "prettier";
        };

        HTML = {
          format_on_save = "on";
          colorize_brackets = true;
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          formatter = "prettier";
        };

        CSS = {
          format_on_save = "on";
          colorize_brackets = true;
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          formatter = "prettier";
        };

        YAML = {
          format_on_save = "on";
          colorize_brackets = true;
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          formatter = "prettier";
        };

        TOML = {
          format_on_save = "on";
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          colorize_brackets = true;
        };

        Rust = {
          tab_size = 4;
          format_on_save = "on";
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          colorize_brackets = true;
        };

        GraphQL = {
          format_on_save = "on";
          colorize_brackets = true;
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          formatter = "prettier";
        };

        SQL = {
          format_on_save = "on";
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          colorize_brackets = true;
        };

        Dockerfile = {
          format_on_save = "on";
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          colorize_brackets = true;
        };

        "Markdown-Inline" = {
          format_on_save = "on";
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          colorize_brackets = true;
        };

        # ── Languages that arrive with an extension ─────────────────────
        # Zed has no grammar for these until the matching entry in
        # `auto_install_extensions` below is installed; these blocks configure
        # which of the servers each extension registers actually run.

        PHP = {
          # Zed's shipped order is ["phpactor", "!intelephense", ...]. This stack
          # standardises on Intelephense (CLAUDE.md), and it is also the server the
          # blade extension shares with Blade files, so the two are swapped round.
          # laravel adds route/view/config/env awareness on top.
          language_servers = [ "intelephense" "laravel" "!phpactor" "!phptools" "!phpantom" "..." ];
          tab_size = 4;
          format_on_save = "on";
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          colorize_brackets = true;
        };

        # Livewire components are Blade markup plus a PHP class, so they need no
        # separate server — this pair covers both halves.
        Blade = {
          language_servers = [ "intelephense" "laravel" "emmet-language-server" "..." ];
          format_on_save = "on";
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          colorize_brackets = true;
          formatter = {
            external = {
              command = "${pkgs.blade-formatter}/bin/blade-formatter";
              arguments = [ "--stdin" ];
            };
          };
        };

        # Django templates. The extension also registers django-language-server,
        # which has no nixpkgs package and would be downloaded at runtime; the
        # Python side of a Django project is already covered by pyright + ruff.
        Django = {
          language_servers = [ "django-template-lsp" "!django-language-server" "..." ];
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          colorize_brackets = true;
        };

        LaTeX = {
          language_servers = [ "texlab" "..." ];
          formatter = "language_server";
          format_on_save = "on";
          soft_wrap = "editor_width";
          auto_indent = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
        };

        Slint = {
          language_servers = [ "slint" "..." ];
          format_on_save = "on";
          formatter = "language_server";
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          colorize_brackets = true;
        };

        Terraform = {
          language_servers = [ "terraform-ls" "..." ];
          format_on_save = "on";
          formatter = "language_server";
          tab_size = 2;
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          colorize_brackets = true;
        };

        "Terraform Vars" = {
          language_servers = [ "terraform-ls" "..." ];
          format_on_save = "on";
          formatter = "language_server";
          tab_size = 2;
          ensure_final_newline_on_save = true;
        };

        "Shell Script" = {
          language_servers = [ "bash-language-server" "..." ];
          format_on_save = "on";
          auto_indent = true;
          auto_indent_on_paste = true;
          show_completions_on_input = true;
          ensure_final_newline_on_save = true;
          colorize_brackets = true;
          formatter = {
            external = {
              command = "${pkgs.shfmt}/bin/shfmt";
              arguments = [ "-i" "2" "-ci" ];
            };
          };
        };
      };

      # LSP settings.
      #
      # Every `binary` here is a `bin` call from the let block at the top of this
      # file, pinning the server to the store path that
      # modules/software/development.nix also puts on PATH. Servers with no pin
      # (eslint, rust-analyzer) are deliberately left to Zed / rustup.
      lsp = {
        # Named `pyright`, not `basedpyright`: the Python entry above enables
        # ["pyright" "ruff"], and settings under a server that is not running are
        # silently ignored — which is what happened to this block before.
        pyright = (bin "${pkgs.pyright}/bin/pyright-langserver" [ "--stdio" ]) // {
          settings = {
            "python.analysis" = {
              diagnosticsMode = "workspace";
              inlayHints = {
                callArgumentNames = false;
              };
            };
          };
        };

        ruff = (bin "${pkgs.ruff}/bin/ruff" [ "server" ]) // {
          initialization_options = {
            settings = {
              lint = { enable = true; };
              format = { enable = true; };
            };
          };
        };

        # Django templates (djlsp) — the Python side is pyright + ruff above.
        django-template-lsp = bin "${django-template-lsp}/bin/djlsp" [ ];

        # PHP / Laravel / Livewire / Blade
        intelephense = (bin "${pkgs.intelephense}/bin/intelephense" [ "--stdio" ]) // {
          settings = {
            intelephense = {
              files.maxSize = 5000000;   # Laravel vendor/ trees are large
              environment.includePaths = [ "vendor" ];
            };
          };
        };
        laravel = bin "${laravel-ls}/bin/laravel-ls" [ ];

        # TeX
        texlab = (bin "${pkgs.texlab}/bin/texlab" [ ]) // {
          settings = {
            texlab = {
              build = {
                executable = "latexmk";
                args = [ "-pdf" "-interaction=nonstopmode" "-synctex=1" "%f" ];
                onSave = false;
              };
              chktex.onOpenAndSave = true;
            };
          };
        };

        # Slint
        slint = bin "${pkgs.slint-lsp}/bin/slint-lsp" [ ];

        # Shell
        bash-language-server = bin "${pkgs.bash-language-server}/bin/bash-language-server" [ "start" ];

        # Terraform / OpenTofu
        terraform-ls = (bin "${pkgs.terraform-ls}/bin/terraform-ls" [ "serve" ]) // {
          initialization_options = {
            experimentalFeatures = {
              validateOnSave = true;
              prefillRequiredFields = true;
            };
          };
        };

        # HTML / CSS / JSON / YAML — one package provides the first three
        vscode-html-language-server =
          bin "${pkgs.vscode-langservers-extracted}/bin/vscode-html-language-server" [ "--stdio" ];
        vscode-css-language-server =
          bin "${pkgs.vscode-langservers-extracted}/bin/vscode-css-language-server" [ "--stdio" ];
        vscode-json-language-server =
          bin "${pkgs.vscode-langservers-extracted}/bin/vscode-json-language-server" [ "--stdio" ];
        yaml-language-server =
          bin "${pkgs.yaml-language-server}/bin/yaml-language-server" [ "--stdio" ];

        emmet-language-server =
          bin "${pkgs.emmet-language-server}/bin/emmet-language-server" [ "--stdio" ];

        rust-analyzer = {
          # rust-analyzer found via PATH (~/.cargo/bin from rustup)
          initialization_options = {
            check = {
              command = "clippy";
            };
            diagnostics = {
              enable = true;
            };
            cargo = {
              allFeatures = true;
            };
          };
        };

        tailwindcss-language-server = (bin "${pkgs.tailwindcss-language-server}/bin/tailwindcss-language-server" [ "--stdio" ]) // {
          settings = {
            tailwindCSS = {
              emmetCompletions = true;
              classAttributes = [ "class" "className" "ngClass" ":class" "x-bind:class" ];
              experimental = {
                classRegex = [ "tw`([^`]*)`" "tw=\"([^\"]*)\"" ];
              };
            };
          };
        };

        # Zed 1.15 defaults TypeScript/TSX/JavaScript to
        # `["!typescript-language-server", "vtsls", "..."]`, so vtsls — not
        # typescript-language-server — is the server that actually runs, and any
        # `lsp.typescript-language-server` block here is dead config.
        #
        # Pinning `binary` to the nixpkgs vtsls stops Zed npm-installing its own
        # copy into ~/.local/share/zed/languages/vtsls on first use: same
        # @vtsls/language-server 0.3.0 + typescript 5.9.3, but present from the
        # first boot and without needing the network.
        vtsls = {
          binary = {
            path = "${pkgs.vtsls}/bin/vtsls";
            arguments = [ "--stdio" ];
          };
          # vtsls takes VS Code's TS/JS settings namespace rather than
          # typescript-language-server's `preferences` initialization_options.
          settings = {
            typescript = {
              preferences.importModuleSpecifier = "relative";
              suggest.autoImports = true;
            };
            javascript = {
              preferences.importModuleSpecifier = "relative";
              suggest.autoImports = true;
            };
          };
        };

        eslint = {
          settings = {
            codeActionOnSave = {
              enable = true;
              mode = "all";
            };
          };
        };
      };

      # Extensions Zed installs on startup. Zed only has grammars and language
      # servers for a language once its extension is present, so this list is what
      # actually turns the `languages` blocks above from inert config into working
      # support. Extensions are fetched from Zed's registry at runtime — the one
      # part of this setup Nix cannot pin — but every server they launch is pinned
      # to a store path by the `lsp` block above.
      #
      # No Alpine.js language server exists for Zed (the registry carries only
      # `alpinejs-snippets`), and there is no htmx extension at all; Alpine's
      # `x-*` and htmx's `hx-*` attributes are plain HTML attributes, so the HTML
      # server and Tailwind's `:class`/`x-bind:class` handling above are what
      # cover them in Zed. Neovim gets a real htmx server — see neovim.nix.
      auto_install_extensions = {
        html = true;              # HTML (also Zed's own default)
        php = true;               # PHP — Intelephense / phpactor
        blade = true;             # Laravel Blade templates (and Livewire views)
        laravel-official = true;  # Laravel LSP, by Laravel
        django = true;            # Django templates
        latex = true;             # LaTeX + BibTeX, texlab
        slint = true;             # Slint UI markup
        terraform = true;         # Terraform / OpenTofu HCL, terraform-ls
        alpinejs-snippets = true; # Alpine.js — snippets only, no LSP exists
      };

      # Node used for Zed's own npm-installed language servers (eslint,
      # tailwindcss-language-server, yaml-language-server, prettier...). Without
      # this Zed downloads a private Node tarball into ~/.local/share/zed/node;
      # pinning both paths (Zed derives npm_path wrongly from path alone) keeps
      # those servers on the same nodejs the rest of the system uses.
      node = {
        path = "${pkgs.nodejs}/bin/node";
        npm_path = "${pkgs.nodejs}/bin/npm";
      };

      # File types
      file_types = {
        Blade = [ "blade.php" ];
      };

      # Indent guides
      indent_guides = {
        enabled = true;
      };
    };
  };

  # Zed keymap configuration
  home.file.".config/zed/keymap.json" = {
    force = true;  # Replace existing file/symlink
    text = builtins.toJSON [
      {
        context = "Workspace";
        bindings = {
          "ctrl-p" = "file_finder::Toggle";
          "ctrl-shift-p" = "command_palette::Toggle";
          "ctrl-`" = "terminal_panel::ToggleFocus";
          "ctrl-shift-`" = "workspace::NewTerminal";
          "ctrl-shift-e" = "project_panel::ToggleFocus";
          "ctrl-shift-g" = "git_panel::ToggleFocus";
          "ctrl-shift-m" = "diagnostics::Deploy";
          "ctrl-shift-o" = "outline_panel::ToggleFocus";
          "ctrl-\\" = "pane::SplitRight";
          "ctrl-shift-\\" = "pane::SplitDown";
          "ctrl-w" = "pane::CloseActiveItem";
          "ctrl-shift-w" = "workspace::CloseWindow";
          "ctrl-tab" = "pane::ActivateNextItem";
          "ctrl-shift-tab" = "pane::ActivatePreviousItem";
          "ctrl-k ctrl-s" = "zed::OpenKeymap";
          "ctrl-," = "zed::OpenSettings";
        };
      }
      {
        context = "Editor";
        bindings = {
          "ctrl-d" = "editor::SelectNext";
          "ctrl-shift-k" = "editor::DeleteLine";
          "alt-up" = "editor::MoveLineUp";
          "alt-down" = "editor::MoveLineDown";
          "ctrl-shift-up" = "editor::AddSelectionAbove";
          "ctrl-shift-down" = "editor::AddSelectionBelow";
          "ctrl-/" = "editor::ToggleComments";
          "ctrl-l" = "editor::SelectLine";
          "ctrl-shift-l" = "editor::SplitSelectionIntoLines";
          "f12" = "editor::GoToDefinition";
          "shift-f12" = "editor::FindAllReferences";
          "f2" = "editor::Rename";
          "ctrl-." = "editor::ToggleCodeActions";
          "ctrl-space" = "editor::ShowCompletions";
          "ctrl-shift-space" = "editor::ShowSignatureHelp";
        };
      }
      {
        context = "Terminal";
        bindings = {
          "ctrl-shift-c" = "terminal::Copy";
          "ctrl-shift-v" = "terminal::Paste";
          "ctrl-shift-n" = "workspace::NewTerminal";
          "ctrl-shift-w" = "pane::CloseActiveItem";
        };
      }
      {
        context = "ProjectPanel && not_editing";
        bindings = {
          "a" = "project_panel::NewFile";
          "shift-a" = "project_panel::NewDirectory";
          "r" = "project_panel::Rename";
          "d" = "project_panel::Delete";
          "x" = "project_panel::Cut";
          "c" = "project_panel::Copy";
          "p" = "project_panel::Paste";
        };
      }
    ];
  };
}
