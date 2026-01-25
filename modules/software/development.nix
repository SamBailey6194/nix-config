{ config, pkgs, ... }:

{
  # Development tools and environment
  # IDEs, language servers, build tools, version control

  environment.systemPackages = with pkgs; [
    # IDEs and Editors
    # vscode              # Visual Studio Code (managed via home-manager)
    # zed                 # Managed via home-manager (see home/modules/editor.nix)
    # neovim              # Managed via home-manager (see home/modules/neovim.nix)

    # Version Control
    git
    gh                  # GitHub CLI
    git-lfs            # Git Large File Storage

    # Build tools
    gnumake
    cmake
    ninja

    # Container tools
    docker
    docker-compose

    # Database tools
    postgresql
    sqlite

    # API testing
    postman
    insomnia

    # Node.js tools (if not using nvm)
    nodejs_20
    yarn
    pnpm

    # Python tools
    python312
    python312Packages.pip
    python312Packages.virtualenv
    uv                  # Fast Python package installer

    # Rust toolchain (alternative to rustup)
    # rustc
    # cargo
    # rustfmt
    # clippy

    # Language servers (shared by Zed, Neovim, and other editors)
    nodePackages.typescript-language-server  # TypeScript/JavaScript
    nodePackages.vscode-langservers-extracted  # HTML, CSS, JSON, ESLint
    pyright                                    # Python type checking
    rust-analyzer                              # Rust
    nil                                        # Nix language server
    lua-language-server                        # Lua (for Neovim config)

    # Linters and formatters (shared by all editors)
    ruff                                       # Python linter + formatter (fast!)
    nodePackages.prettier                      # JS/TS/JSON/YAML/Markdown formatter
    nodePackages.eslint                        # JavaScript/TypeScript linter
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
