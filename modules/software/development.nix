{ config, pkgs, ... }:

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

    # Rust toolchain via rustup (provides rustc, cargo, rustfmt, clippy)
    # After install: rustup default stable && rustup component add rust-analyzer
    rustup

    # PHP — used by DDEV projects and Blade templates
    php                 # PHP interpreter
    phpPackages.composer # PHP dependency manager
    # Intelephense LSP is downloaded automatically by Zed's PHP extension

    # Language servers (shared by Zed, Neovim, and other editors)
    typescript-language-server  # TypeScript/JavaScript
    vscode-langservers-extracted  # HTML, CSS, JSON, ESLint
    pyright                                    # Python type checking
    # rust-analyzer provided by rustup (rustup component add rust-analyzer)
    nixd                                       # Nix language server (used by Zed)
    nil                                        # Nix language server (used by Neovim)
    lua-language-server                        # Lua (for Neovim config)
    taplo                                      # TOML language server + formatter

    # Linters and formatters (shared by all editors)
    ruff                                       # Python linter + formatter (fast!)
    prettier                      # JS/TS/JSON/YAML/Markdown formatter
    eslint                        # JavaScript/TypeScript linter

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
