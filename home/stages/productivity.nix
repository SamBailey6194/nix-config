{ config, pkgs, ... }:

{
  # Stage 4: Productivity
  # Everything from dev + Productivity apps (mail, Discord, etc.)

  imports = [
    ./dev.nix
    ../modules/aerc.nix # aerc, the default mail client (SUPER + E)
    ../modules/email.nix # Claws Mail, the GUI backup (SUPER + SHIFT + E)
  ];

  # Productivity packages
  home.packages = with pkgs; [
    discord
  ];
}
