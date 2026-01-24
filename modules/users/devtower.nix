{ config, pkgs, ... }:

{
  # User configuration for devtower device

  users.users.sam-desktop = {
    isNormalUser = true;
    description = "Sam Bailey (DevTower)";
    extraGroups = [
      "wheel"          # sudo access
      "networkmanager" # network management
      "video"          # video devices
      "audio"          # audio devices
      "docker"         # docker (when enabled)
      "libvirtd"       # virtualization (when enabled)
      "render"         # GPU access (AMD Radeon)
      "input"          # input devices (Go XLR)
    ];
    shell = pkgs.zsh;

    # Password will be set during installation
    # Use: passwd sam-desktop

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
}
