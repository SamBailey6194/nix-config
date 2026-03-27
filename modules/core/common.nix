{ config, pkgs, inputs, ... }:

{
  # System-wide common configuration for all hosts

  # Enable Flakes and Nix Command
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  # Auto-optimize store
  nix.settings.auto-optimise-store = true;

  # Garbage collection
  # - Boot menu shows 5 entries (configurationLimit in base-configuration.nix)
  # - Always keep the 3 most recent generations regardless of age
  # - Delete generations older than 90 days beyond those 3
  nix.gc.automatic = false; # We use a custom service instead
  systemd.services.nix-gc-custom = {
    description = "Nix garbage collection (keep min 3 generations, remove >90d)";
    script = ''
      set -eu
      profile="/nix/var/nix/profiles/system"
      cutoff=$(date -d '90 days ago' +%Y-%m-%d)

      # List generations newest first, skip the 3 most recent,
      # then collect generation numbers older than 90 days
      to_delete=$(${pkgs.nix}/bin/nix-env -p "$profile" --list-generations \
        | sort -rn \
        | tail -n +4 \
        | while read -r gen date rest; do
            if [ "$date" \< "$cutoff" ]; then
              echo "$gen"
            fi
          done \
        | tr '\n' ' ')

      if [ -n "$to_delete" ]; then
        echo "Deleting old generations: $to_delete"
        ${pkgs.nix}/bin/nix-env -p "$profile" --delete-generations $to_delete
      else
        echo "No generations to clean up"
      fi

      ${pkgs.nix}/bin/nix-store --gc
    '';
    serviceConfig.Type = "oneshot";
    startAt = "weekly";
  };

  # Common system packages
  environment.systemPackages = with pkgs; [
    # Core utilities
    coreutils
    curl
    wget
    git
    vim
    neovim
    rclone
    fuse

    # System monitoring
    htop
    btop
    tree

    # Network tools
    dig
    nmap
    traceroute
    wireguard-tools

    # DDEV/mkcert (locally-trusted SSL certs)
    mkcert
    nss.tools # needed for Firefox cert trust

    # Archive tools
    unzip
    zip
    p7zip

    # Build tools
    gcc
    gnumake
    pkg-config
    just

    # Profiling & debugging
    valgrind

    # Secrets management
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ]
  # Rust CLI tools (secrets-verify, agenix-helper, wireguard-helper, etc.)
  ++ (builtins.attrValues inputs.self.packages.${pkgs.stdenv.hostPlatform.system});

  # Shell configuration
  programs.zsh.enable = true;
  programs.bash.completion.enable = true;

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Console keymap and font
  console = {
    font = "Lat2-Terminus16";
    keyMap = "us";
  };
}
