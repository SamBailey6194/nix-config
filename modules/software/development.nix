{ config, pkgs, ... }:

{
  # Development tools and environment
  # IDEs, language servers, build tools, version control

  environment.systemPackages = with pkgs; [
    # IDEs and Editors
    vscode              # Visual Studio Code
    # zed is managed via home-manager

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

    # Language servers (for non-Zed editors)
    # Most are handled by Zed, but useful for other editors
    nodePackages.typescript-language-server
    nodePackages.vscode-langservers-extracted
    pyright
    rust-analyzer
    nil                 # Nix language server
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
