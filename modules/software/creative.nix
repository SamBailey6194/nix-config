{ config, pkgs, ... }:

{
  # Creative software suite
  # DaVinci Resolve Studio + Affinity Apps
  # Requires AMD GPU (or powerful dedicated GPU)

  environment.systemPackages = with pkgs; [
    # Video Editing
    davinci-resolve-studio
  ];

  # Note: Affinity Apps are enabled via programs.affinity
  # in base-configuration.nix, so all devices get them
}
