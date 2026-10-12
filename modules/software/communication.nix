{ config, pkgs, ... }:

{
  # Communication apps
  # Slack, Teams, Zoom. Notes are plain Markdown in Neovim (Zed as
  # the backup), so there is no separate notes app.

  environment.systemPackages = with pkgs; [
    # Chat and collaboration
    slack                # Team collaboration
    teams-for-linux      # Microsoft Teams
    zoom-us              # Zoom video conferencing
    # telegram-desktop   # Telegram (optional)

    # Email: aerc and Claws Mail, per user (home/modules/aerc.nix, email.nix)
  ];
}
