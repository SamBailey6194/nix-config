{ config, pkgs, ... }:

{
  # Communication and productivity apps
  # Discord, Slack, note-taking, etc.

  environment.systemPackages = with pkgs; [
    # Chat and collaboration
    discord              # Voice, video, and text chat
    slack                # Team collaboration
    teams-for-linux      # Microsoft Teams
    zoom-us              # Zoom video conferencing
    # telegram-desktop   # Telegram (optional)

    # Note-taking and knowledge management
    obsidian

    # Email clients (optional)
    # thunderbird        # Mozilla Thunderbird
    # mailspring         # Modern email client
  ];
}
