{ config, pkgs, ... }:

{
  # User configuration for laptop-intel device

  users.users.sam-laptop = {
    isNormalUser = true;
    description = "Sam Bailey (Laptop)";
    extraGroups = [
      "wheel"          # sudo access
      "networkmanager" # network management
      "video"          # video devices (brightness control)
      "audio"          # audio devices
      "docker"         # docker (when enabled)
      "libvirtd"       # virtualization (when enabled)
    ];
    shell = pkgs.zsh;

    # Password will be set during installation
    # Use: passwd sam-laptop

    # SSH authorized keys (will be added in Phase 2 via secrets)
    # openssh.authorizedKeys.keys = [ ];
  };

  # Root user configuration
  users.users.root = {
    hashedPassword = "!"; # Locked password - use sudo
  };

  # Sudo configuration
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };

  # Trust mkcert root CA system-wide (curl, Node.js, etc.)
  # Run `mkcert -install` once after first rebuild to generate the CA.
  security.pki.certificateFiles =
    let caFile = /home/sam-laptop/.local/share/mkcert/rootCA.pem;
    in pkgs.lib.optional (builtins.pathExists caFile) caFile;
}
