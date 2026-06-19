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

    # Claude Code CLI (hourly auto-updates)
    claude-code-nix = {
      url = "github:sadjow/claude-code-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Browser accountability posture (private repo - locked enterprise policies
    # + QUIC-blocking nftables rule). flake = false -> consumed as a plain source
    # tree (policy JSONs, network/*.nft). Auth via the github-personal SSH alias;
    # pin with: nix flake update browser_setup
    browser_setup = {
      url = "git+ssh://git@github-personal/SamBailey6194/browser_setup.git";
      flake = false;
    };

    # Accountability script (private repo - the squid-digest Rust tool +
    # custom-blocklist.txt). flake = false -> built with rustPlatform from its
    # own subdir Cargo.lock. Pin with: nix flake update accountability_script
    accountability_script = {
      url = "git+ssh://git@github-personal/SamBailey6194/accountability_script.git";
      flake = false;
    };

    # Zen browser (not packaged in nixpkgs)
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, agenix, hyprland, affinity-nix, claude-code-nix, browser_setup, accountability_script, zen-browser, ... }@inputs:
  let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};
    rustTools = import ./rust/nix { inherit pkgs; };

    # squid-digest is built from the accountability_script input's own crate
    # (separate src + Cargo.lock from the rust/ workspace), so it is defined
    # standalone rather than via rust/nix/default.nix.
    squid-digest = pkgs.callPackage ./modules/security/squid-digest/package.nix {
      accountability_script = inputs.accountability_script;
    };
  in {
    # Rust CLI tool packages (nix build .#<name>)
    packages.${system} = rustTools // {
      inherit squid-digest;
      default = pkgs.symlinkJoin {
        name = "nix-config-rust-tools";
        paths = builtins.attrValues rustTools;
      };
    };

    # NixOS System Configurations
    nixosConfigurations = {
      # ============================================================================
      # LAPTOP-INTEL (Intel i5-10210U, 32GB RAM, Intel UHD Graphics)
      # ============================================================================

      # Stage 1: Minimal (for installation only)
      laptop-intel-minimal = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/laptop-intel/configuration-minimal.nix
        ];
      };

      # Stage 2: Desktop (Hyprland + zsh + SSH)
      laptop-intel-desktop = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/laptop-intel/configuration-desktop.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.sam-laptop = import ./home/laptop-desktop.nix;
          }
        ];
      };

      # Stage 3: Development (+ browsers, Zed, Neovim)
      laptop-intel-dev = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/laptop-intel/configuration-dev.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.sam-laptop = import ./home/laptop-dev.nix;
          }
        ];
      };

      # Stage 4: Productivity (+ LibreOffice, communication)
      laptop-intel-productivity = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/laptop-intel/configuration-productivity.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.sam-laptop = import ./home/laptop-productivity.nix;
          }
        ];
      };

      # Stage 5: Creative (GIMP + Affinity - no DaVinci on Intel GPU)
      # Note: Affinity packages added via inputs.affinity-nix.packages in configuration
      laptop-intel-creative = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/laptop-intel/configuration-creative.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.sam-laptop = import ./home/laptop-creative.nix;
          }
        ];
      };

      # Stage 6: Full (all software + Affinity + VPN + malware scanner)
      # Note: Affinity packages added via inputs.affinity-nix.packages in configuration
      laptop-intel = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/laptop-intel/configuration-full.nix
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.sam-laptop = import ./home/laptop.nix;
          }
        ];
      };

      # ============================================================================
      # FRAMEWORK (AMD Ryzen + Radeon, 64GB RAM)
      # ============================================================================

      # Stage 1: Minimal (for installation only)
      framework-minimal = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/framework/configuration-minimal.nix
        ];
      };

      # Stage 2: Desktop (Hyprland + zsh + SSH)
      framework-desktop = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/framework/configuration-desktop.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.sam-framework = import ./home/framework-desktop.nix;
          }
        ];
      };

      # Stage 3: Development (+ browsers, Zed, Neovim)
      framework-dev = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/framework/configuration-dev.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.sam-framework = import ./home/framework-dev.nix;
          }
        ];
      };

      # Stage 4: Productivity (+ LibreOffice, communication)
      framework-productivity = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/framework/configuration-productivity.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.sam-framework = import ./home/framework-productivity.nix;
          }
        ];
      };

      # Stage 5: Creative (+ DaVinci Resolve Studio, Blender + Affinity)
      # Note: Affinity packages added via inputs.affinity-nix.packages in configuration
      framework-creative = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/framework/configuration-creative.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.sam-framework = import ./home/framework-creative.nix;
          }
        ];
      };

      # Stage 6: Full (all software + Affinity + VPN + malware scanner)
      # Note: Affinity packages added via inputs.affinity-nix.packages in configuration
      framework = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/framework/configuration-full.nix
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.sam-framework = import ./home/framework.nix;
          }
        ];
      };

      # ============================================================================
      # DEVTOWER (AMD CPU + GPU, 64GB RAM, Go XLR)
      # ============================================================================

      # Stage 1: Minimal (for installation only)
      devtower-minimal = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/devtower/configuration-minimal.nix
        ];
      };

      # Stage 2: Desktop (Hyprland + zsh + SSH)
      devtower-desktop = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/devtower/configuration-desktop.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.sam-desktop = import ./home/devtower-desktop.nix;
          }
        ];
      };

      # Stage 3: Development (+ browsers, Zed, Neovim)
      devtower-dev = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/devtower/configuration-dev.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.sam-desktop = import ./home/devtower-dev.nix;
          }
        ];
      };

      # Stage 4: Productivity (+ LibreOffice, communication)
      devtower-productivity = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/devtower/configuration-productivity.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.sam-desktop = import ./home/devtower-productivity.nix;
          }
        ];
      };

      # Stage 5: Creative (+ DaVinci Resolve Studio, Blender, Go XLR + Affinity)
      # Note: Affinity packages added via inputs.affinity-nix.packages in configuration
      devtower-creative = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/devtower/configuration-creative.nix
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.sam-desktop = import ./home/devtower-creative.nix;
          }
        ];
      };

      # Stage 6: Full (all software + Affinity + VPN + malware scanner + OpenRGB)
      # Note: Affinity packages added via inputs.affinity-nix.packages in configuration
      devtower = nixpkgs.lib.nixosSystem {
        specialArgs = { inherit inputs; };
        modules = [
          { nixpkgs.hostPlatform = system; }
          ./hosts/devtower/configuration-full.nix
          agenix.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.backupFileExtension = "hm-backup";
            home-manager.users.sam-desktop = import ./home/devtower.nix;
          }
        ];
      };
    };

    # Development Shell (for secret management and Rust development)
    devShells.${system}.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        # Core tools
        git
        vim

        # Agenix for secrets management
        agenix.packages.${system}.default

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

        # Nix language server (for Zed/editors)
        nixd

        # Encryption and filesystem tools
        cryptsetup      # LUKS management
        tpm2-tools      # TPM2 management
        btrfs-progs     # BTRFS filesystem tools
        gocryptfs       # Per-folder encryption
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
          echo "  - luks-manage, btrfs-manage, vault-manage, tpm-manage"
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
        echo "  luks-manage            - LUKS encryption management"
        echo "  btrfs-manage           - BTRFS filesystem management"
        echo "  vault-manage           - Per-folder encryption (gocryptfs)"
        echo "  tpm-manage             - TPM2 management"
        echo ""
      '';
    };
  };
}
