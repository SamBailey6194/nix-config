{ config, pkgs, ... }:

{
  # LEGACY: This file is a template and is NOT imported by any host.
  # Each device uses its own user module in modules/users/ instead:
  #   - modules/users/laptop.nix    (sam-laptop)
  #   - modules/users/framework.nix (sam-framework)
  #   - modules/users/devtower.nix  (sam-desktop)

  # Template user (not used - kept as reference)
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
    # Root login disabled - use sudo from device user
    hashedPassword = "!"; # Locked password
  };

  # Sudo configuration
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true; # Require password for sudo
  };
}
