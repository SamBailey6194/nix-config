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
      url = "github:hyprwm/Hyprland";
    };

    # Affinity Apps (Designer, Photo, Publisher)
    affinity-nix = {
      url = "github:mrshmllow/affinity-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Claude Code (hourly updates, native binary)
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, agenix, hyprland, affinity-nix, claude-code-nix, ... }@inputs: {
    # NixOS System Configurations
    nixosConfigurations = {
      # ============================================================================
      # LAPTOP-INTEL (Intel i5-10210U, 32GB RAM, Intel UHD Graphics)
      # ============================================================================

      # Stage 1: Minimal (for installation only)
      laptop-intel-minimal = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/laptop-intel/configuration-minimal.nix ];
      };

      # Stage 2: Desktop (Hyprland + zsh + SSH)
      laptop-intel-desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/laptop-intel/configuration-desktop.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sam-laptop = import ./home/laptop-desktop.nix;
          }
        ];
      };

      # Stage 3: Development (+ browsers, Zed, Neovim)
      laptop-intel-dev = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/laptop-intel/configuration-dev.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sam-laptop = import ./home/laptop-dev.nix;
          }
        ];
      };

      # Stage 4: Productivity (+ LibreOffice, communication)
      laptop-intel-productivity = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/laptop-intel/configuration-productivity.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sam-laptop = import ./home/laptop-productivity.nix;
          }
        ];
      };

      # Stage 5: Creative (GIMP + Affinity - no DaVinci on Intel GPU)
      # Note: Affinity packages added via inputs.affinity-nix.packages in configuration
      laptop-intel-creative = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/laptop-intel/configuration-creative.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sam-laptop = import ./home/laptop-creative.nix;
          }
        ];
      };

      # Stage 6: Full (all software + Affinity + VPN + malware scanner)
      # Note: Affinity packages added via inputs.affinity-nix.packages in configuration
      laptop-intel = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/laptop-intel/configuration-full.nix
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sam-laptop = import ./home/laptop.nix;
          }
        ];
      };

      # ============================================================================
      # FRAMEWORK (AMD Ryzen + Radeon, 64GB RAM)
      # ============================================================================

      # Stage 1: Minimal (for installation only)
      framework-minimal = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/framework/configuration-minimal.nix ];
      };

      # Stage 2: Desktop (Hyprland + zsh + SSH)
      framework-desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/framework/configuration-desktop.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sam-framework = import ./home/framework-desktop.nix;
          }
        ];
      };

      # Stage 3: Development (+ browsers, Zed, Neovim)
      framework-dev = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/framework/configuration-dev.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sam-framework = import ./home/framework-dev.nix;
          }
        ];
      };

      # Stage 4: Productivity (+ LibreOffice, communication)
      framework-productivity = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/framework/configuration-productivity.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sam-framework = import ./home/framework-productivity.nix;
          }
        ];
      };

      # Stage 5: Creative (+ DaVinci Resolve Studio, Blender + Affinity)
      # Note: Affinity packages added via inputs.affinity-nix.packages in configuration
      framework-creative = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/framework/configuration-creative.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sam-framework = import ./home/framework-creative.nix;
          }
        ];
      };

      # Stage 6: Full (all software + Affinity + VPN + malware scanner)
      # Note: Affinity packages added via inputs.affinity-nix.packages in configuration
      framework = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/framework/configuration-full.nix
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sam-framework = import ./home/framework.nix;
          }
        ];
      };

      # ============================================================================
      # DEVTOWER (AMD CPU + GPU, 64GB RAM, Go XLR)
      # ============================================================================

      # Stage 1: Minimal (for installation only)
      devtower-minimal = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [ ./hosts/devtower/configuration-minimal.nix ];
      };

      # Stage 2: Desktop (Hyprland + zsh + SSH)
      devtower-desktop = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/devtower/configuration-desktop.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sam-desktop = import ./home/devtower-desktop.nix;
          }
        ];
      };

      # Stage 3: Development (+ browsers, Zed, Neovim)
      devtower-dev = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/devtower/configuration-dev.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sam-desktop = import ./home/devtower-dev.nix;
          }
        ];
      };

      # Stage 4: Productivity (+ LibreOffice, communication)
      devtower-productivity = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/devtower/configuration-productivity.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sam-desktop = import ./home/devtower-productivity.nix;
          }
        ];
      };

      # Stage 5: Creative (+ DaVinci Resolve Studio, Blender, Go XLR + Affinity)
      # Note: Affinity packages added via inputs.affinity-nix.packages in configuration
      devtower-creative = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/devtower/configuration-creative.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sam-desktop = import ./home/devtower-creative.nix;
          }
        ];
      };

      # Stage 6: Full (all software + Affinity + VPN + malware scanner + OpenRGB)
      # Note: Affinity packages added via inputs.affinity-nix.packages in configuration
      devtower = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/devtower/configuration-full.nix
          agenix.nixosModules.default
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
