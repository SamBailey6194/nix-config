{ config, pkgs, lib, ... }:

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

      git_panel = {
        button = true;
        dock = "left";
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

        PHP = {
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
      };

      # LSP settings
      lsp = {
        basedpyright = {
          settings = {
            "basedpyright.analysis" = {
              diagnosticsMode = "workspace";
              inlayHints = {
                callArguments = false;
              };
            };
          };
        };

        ruff = {
          initialization_options = {
            settings = {
              lint = { enable = true; };
              format = { enable = true; };
            };
          };
        };

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

        tailwindcss-language-server = {
          settings = {
            tailwindCSS = {
              emmetCompletions = true;
              classAttributes = [ "class" "className" "ngClass" ];
              experimental = {
                classRegex = [ "tw`([^`]*)`" "tw=\"([^\"]*)\"" ];
              };
            };
          };
        };

        typescript-language-server = {
          initialization_options = {
            preferences = {
              includeCompletionsForModuleExports = true;
              includeCompletionsWithInsertText = true;
              importModuleSpecifierPreference = "relative";
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
