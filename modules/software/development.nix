{ config, pkgs, ... }:

let
  # Language servers that nixpkgs does not carry, plus one it carries too old to
  # be usable. All three are wired into Zed and Neovim in
  # home/modules/{editor,neovim}.nix; see the files themselves for why they are
  # built here rather than pulled from nixpkgs. These `let` bindings shadow the
  # `with pkgs;` names in the package list below.
  laravel-ls = pkgs.callPackage ../../pkgs/laravel-ls.nix { };
  django-template-lsp = pkgs.callPackage ../../pkgs/django-template-lsp.nix { };
  htmx-lsp = pkgs.callPackage ../../pkgs/htmx-lsp.nix { };
in
{
  # Development tools and environment
  # IDEs, language servers, build tools, version control

  environment.systemPackages = with pkgs; [
    # Version Control
    git
    gh                  # GitHub CLI
    git-lfs            # Git Large File Storage

    # Environment management
    direnv            # Auto-load dev environments per directory

    # Build tools
    gnumake
    cmake
    ninja

    # Container tools
    docker
    docker-compose
    ddev              # Docker-based local PHP+Node.js dev environments

    # Database tools
    postgresql
    sqlite
    mariadb           # MySQL-compatible database (client + server)
    mycli             # Better MySQL/MariaDB CLI with auto-completion

    # API testing
    postman
    insomnia

    # Node.js — fnm for per-project version management
    # Usage: fnm install 20, fnm use 20, or auto-switch via .node-version
    nodejs              # System-level Node.js (latest LTS, for global tools)
    fnm                 # Fast Node Manager (per-project Node.js versions)
    yarn
    pnpm

    # Python — uv handles version management and virtual environments
    # Usage: uv python install 3.12, uv venv, uv pip install ...
    python314           # Default for new projects
    python314Packages.pip
    python314Packages.virtualenv
    python313           # For legacy projects
    python313Packages.pip
    python313Packages.virtualenv
    uv                  # Fast Python package installer + version manager
    copier              # Project scaffolding from templates (copier copy/update)

    # Rust toolchain via rustup (provides rustc, cargo, rustfmt, clippy)
    # After install: rustup default stable && rustup component add rust-analyzer
    rustup

    # PHP — used by DDEV projects and Blade templates
    php                 # PHP interpreter
    phpPackages.composer # PHP dependency manager
    # Intelephense LSP is downloaded automatically by Zed's PHP extension

    # ── Language servers ────────────────────────────────────────────────
    # One system-wide set, shared by Zed and Neovim. Both editors are pointed at
    # these exact store paths (home/modules/editor.nix pins `lsp.<server>.binary`,
    # home/modules/neovim.nix pins each server's `cmd`) so neither downloads its
    # own copy at runtime and both report identical diagnostics.

    # Web — TypeScript, JavaScript, React / React Native
    typescript-language-server  # tsserver-backed LSP (Neovim)
    vtsls                       # same tsserver via the VS Code TS service (Zed's default)
    vscode-langservers-extracted  # HTML, CSS, JSON and ESLint servers
    tailwindcss-language-server   # Tailwind class completion + linting
    emmet-language-server         # Emmet abbreviations in HTML/JSX/Blade
    htmx-lsp                      # hx-* attribute completion (see pkgs/htmx-lsp.nix)

    # Python / Django
    pyright                     # Python type checking
    django-template-lsp         # {% %} tags, template/static/url names (djlsp)

    # PHP / Laravel / Livewire / Blade
    intelephense                # PHP LSP; also serves Blade via Zed's blade extension
    laravel-ls                  # Laravel routes, views, config keys, env vars

    # Rust — rust-analyzer comes from rustup (rustup component add rust-analyzer)

    # Slint (UI markup)
    slint-lsp

    # TeX
    texlab                      # LaTeX/BibTeX LSP (build, forward search, refs)

    # Shell
    bash-language-server        # sh/bash/zsh, backed by shellcheck below

    # Config / infra languages
    terraform-ls                               # Terraform / OpenTofu HCL language server
    tflint                                     # Terraform linter
    nixd                                       # Nix language server (used by Zed)
    nil                                        # Nix language server (used by Neovim)
    lua-language-server                        # Lua (for Neovim config)
    taplo                                      # TOML language server + formatter
    yaml-language-server                       # YAML + schema validation
    nginx-language-server                      # nginx.conf completion + hover
    systemd-lsp                                # systemd unit files (Neovim only)

    # ── Linters and formatters (shared by all editors) ──────────────────
    ruff                        # Python linter + formatter (fast!)
    prettier                    # JS/TS/JSON/YAML/Markdown formatter
    eslint                      # JavaScript/TypeScript linter
    shellcheck                  # Shell static analysis (bash-language-server uses it)
    shfmt                       # Shell formatter
    blade-formatter             # Laravel Blade template formatter
    phpPackages.php-cs-fixer    # PHP formatter (PSR-12 etc.)

    # TeX engines — pdflatex, xelatex, lualatex, latexmk, biber, full CTAN set.
    # texliveFull is a large closure (~7GB); texliveMedium is the same engines with
    # a trimmed package set if that ever needs reclaiming.
    texliveFull

    # Document conversion (markdown/html/docx/... -> PDF and between formats)
    pandoc                                     # universal document converter
    wkhtmltopdf                                # HTML -> PDF (also pandoc --pdf-engine=wkhtmltopdf)
  ];

  # Docker configuration
  virtualisation.docker = {
    enable = true;
    enableOnBoot = true;
  };

  # Enable virtualization for VMs
  virtualisation.libvirtd = {
    enable = true;
  };
}
