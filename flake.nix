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
          affinity-nix.nixosModules.default
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
          affinity-nix.nixosModules.default
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
          affinity-nix.nixosModules.default
          home-manager.nixosModules.home-manager
          {
            home-manager.useGlobalPkgs = true;
            home-manager.useUserPackages = true;
            home-manager.users.sam-desktop = import ./home/devtower.nix;
          }
        ];
      };
    };

    # Development Shell (optional, for testing before installation)
    devShells.x86_64-linux.default = nixpkgs.legacyPackages.x86_64-linux.mkShell {
      buildInputs = with nixpkgs.legacyPackages.x86_64-linux; [
        git
        vim
        agenix.packages.x86_64-linux.default
      ];
    };
  };
}
