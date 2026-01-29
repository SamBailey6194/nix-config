{ config, pkgs, ... }:

{
  # Stage 6: Full
  # Everything from creative + Cloud sync + All remaining features

  imports = [
    ./creative.nix
    ../modules/cloud.nix     # Google Drive linked via rclone and fuse
  ];

  # Any remaining packages or configs
  home.packages = with pkgs; [
    # Claude Code CLI
    # Note: Claude Code plugins should be configured in ~/.config/claude/
    # after installation. Your custom plugins (syntek-dev-suite, syntek-rust-security,
    # syntek-infra) should be cloned to ~/Repos/personal/claude-plugins/ and symlinked.
  ];

  # Systemd user services
  systemd.user.sessionVariables = {
    # CLAUDE_CODE_OAUTH_TOKEN = ""; # Set this via secrets or manually
  };
}
