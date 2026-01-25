{ config, pkgs, ... }:

{
  # Define user accounts

  # Main user: sam-dev
  users.users.sam-dev = {
    isNormalUser = true;
    description = "Sam Bailey";
    extraGroups = [
      "wheel"          # sudo access
      "networkmanager" # network management
      "video"          # video devices (brightness control)
      "audio"          # audio devices
      "docker"         # docker (when enabled)
      "libvirtd"       # virtualization (when enabled)
    ];
    shell = pkgs.zsh;

    # SSH authorized keys (will be added in Phase 2 via secrets)
    # openssh.authorizedKeys.keys = [ ];
  };

  # Root user configuration
  users.users.root = {
    # Root login disabled - use sudo from sam-dev
    hashedPassword = "!"; # Locked password
  };

  # Sudo configuration
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true; # Require password for sudo
  };
}
