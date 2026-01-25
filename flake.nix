{
  description = "Personal NixOS Configuration - Phase 1: Foundation";

  inputs = {
    # Core
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    # Home Manager
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Secrets Management
    agenix = {
      url = "github:ryantm/agenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Hyprland Wayland Compositor
    hyprland = {
      url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Affinity Apps (Designer, Photo, Publisher)
    affinity-nix = {
      url = "github:mrshmllow/affinity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, agenix, hyprland, affinity-nix, ... }@inputs: {
    # NixOS System Configurations
    nixosConfigurations = {
      # Current Intel Laptop (i5-10210U, 32GB RAM)
      laptop-intel = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/laptop-intel/configuration.nix
          agenix.nixosModules.default
          # TODO: Re-enable after installation - affinity-nix doesn't expose nixosModules.default
          # affinity-nix.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sam-laptop = import ./home/laptop.nix;
          }
        ];
      };

      # Future Framework Laptop (AMD Ryzen + Radeon, 64GB RAM)
      framework = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/framework/configuration.nix
          agenix.nixosModules.default
          # TODO: Re-enable after installation - affinity-nix doesn't expose nixosModules.default
          # affinity-nix.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sam-framework = import ./home/framework.nix;
          }
        ];
      };

      # Future DevTower Desktop (AMD CPU + GPU, 64GB RAM, Go XLR)
      devtower = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/devtower/configuration.nix
          agenix.nixosModules.default
          # TODO: Re-enable after installation - affinity-nix doesn't expose nixosModules.default
          # affinity-nix.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sam-desktop = import ./home/devtower.nix;
          }
        ];
      };
    };

    # Development Shell (for secret management and Rust development)
    devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
      buildInputs = with nixpkgs.legacyPackages.x86_64-linux; [
        # Core tools
        git
        vim

        # Agenix for secrets management
        agenix.packages.x86_64-linux.default

        # Rust toolchain for building secrets-verify and agenix-helper
        cargo
        rustc
        rust-analyzer
        clippy
        rustfmt

        # Additional dependencies for Rust tools
        pkg-config
        openssl

        # VPN tools (Phase 6: Wireguard + Mullvad)
        curl   # For IP verification and Mullvad API
        jq     # For JSON parsing
      ];

      # Auto-build Rust tools when entering dev shell
      shellHook = ''
        echo "🦀 NixOS Config Dev Shell"
        echo ""

        if [ -d rust ]; then
          echo "Building Rust tools..."
          cd rust
          cargo build --release 2>&1 | grep -E "(Compiling|Finished|error)" || true
          cd ..
          echo ""

          # Add Rust tools to PATH
          export PATH="$PWD/rust/target/release:$PATH"
          echo "✅ Rust tools available:"
          echo "  - secrets-verify, agenix-helper"
          echo "  - wireguard-helper"
          echo "  - malware-scanner"
          echo "  - restic-manage, zfs-manage, raid-manage"
          echo ""
        fi

        echo "Available commands:"
        echo "  agenix -e <secret>     - Edit an encrypted secret"
        echo "  agenix -r              - Rekey all secrets"
        echo "  secrets-verify         - Verify deployed secrets"
        echo "  agenix-helper          - Helper CLI for secrets management"
        echo "  wireguard-helper       - Mullvad VPN management"
        echo "  restic-manage          - Restic backup configuration"
        echo "  zfs-manage             - ZFS storage management"
        echo "  raid-manage            - RAID array management"
        echo ""
      '';
    };
  };
}
