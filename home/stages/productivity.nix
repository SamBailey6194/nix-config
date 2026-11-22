{ config, pkgs, ... }:

{
  # Stage 4: Productivity
  # Everything from dev + Productivity apps (mail, etc.)

  imports = [
    ./dev.nix
    ../modules/aerc.nix # aerc, the mail client (SUPER + E)
  ];
}
