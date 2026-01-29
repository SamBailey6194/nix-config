{ config, pkgs, ... }:

{
  # Stage 5: Creative
  # Everything from productivity + Creative app configurations
  # (Currently no specific creative configs, but ready for future use)

  imports = [
    ./productivity.nix
  ];

  # Creative-specific packages (if any)
  # home.packages = with pkgs; [
  #   # Future: Add creative app configs here
  # ];
}
