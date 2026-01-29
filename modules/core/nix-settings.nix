{ config, pkgs, ... }:

{
  # Nix-specific settings and optimizations

  nix = {
    # Build settings
    settings = {
      # Experimental features
      experimental-features = [ "nix-command" "flakes" ];

      # Build optimization
      auto-optimise-store = true;
      max-jobs = "auto";
      cores = 0; # Use all available cores

      # Download optimization (256 MB buffer for large packages)
      download-buffer-size = 268435456; # 256 MB in bytes

      # Trusted users (for remote builds, etc.)
      trusted-users = [ "root" "@wheel" ];

      # Substituters and cache
      substituters = [
        "https://cache.nixos.org"
        "https://nix-community.cachix.org"
        "https://hyprland.cachix.org"
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
        "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
      ];

      # Warn about dirty git trees
      warn-dirty = false;
    };

    # Garbage collection
    gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 30d";
    };

    # Automatic store optimization
    optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };
  };

  # nixpkgs configuration
  nixpkgs.config = {
    allowUnfree = true;
    allowBroken = false;
  };

  # ============================================================================
  # nix-ld: Run unpatched dynamic binaries on NixOS
  # ============================================================================
  # NixOS cannot run dynamically linked executables (e.g., npm packages,
  # downloaded binaries) because they expect libraries in /lib, /usr/lib, etc.
  #
  # nix-ld provides a compatibility layer that:
  # 1. Creates /lib64/ld-linux-x86-64.so.2 pointing to the Nix store
  # 2. Sets LD_LIBRARY_PATH to include common libraries
  #
  # This allows tools like:
  # - npm install -g @anthropic-ai/claude-code (uses downloaded Node.js)
  # - Downloaded AppImages
  # - Pre-compiled development tools
  #
  # Without nix-ld, you get: "Could not start dynamically linked executable"
  # ============================================================================
  programs.nix-ld = {
    enable = true;
    # Libraries commonly needed by dynamically linked programs
    # Add more as needed based on specific tool requirements
    libraries = with pkgs; [
      # Core C/C++ libraries
      stdenv.cc.cc.lib
      glibc

      # SSL/TLS for network operations
      openssl

      # Compression libraries
      zlib
      bzip2
      xz

      # ICU for internationalization (Node.js, Electron apps)
      icu

      # Graphics libraries (for Electron apps, GUI tools)
      libGL
      xorg.libX11
      xorg.libXext
      xorg.libXrender
      xorg.libXi

      # Additional commonly needed libraries
      curl
      libgcc
    ];
  };

  # System version (for reference)
  # This is set in host configuration, not here
}
