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

  # System version (for reference)
  # This is set in host configuration, not here
}
