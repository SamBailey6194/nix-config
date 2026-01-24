{ config, pkgs, ... }:

{
  # Web browsers for different purposes
  # LibreWolf (privacy), Firefox (dev testing), Chrome (Claude extension)

  environment.systemPackages = with pkgs; [
    # Privacy-focused browser (personal use)
    librewolf

    # Development testing browser
    firefox

    # Chromium-based (Claude Chrome extension)
    google-chrome

    # Alternative browsers (optional)
    # chromium         # Open-source Chrome
    # brave            # Privacy-focused Chromium
    # vivaldi          # Feature-rich browser
  ];

  # Firefox configuration (optional)
  # You can manage Firefox settings via Home Manager too
  programs.firefox = {
    enable = true;

    # Set default preferences
    preferences = {
      "browser.startup.homepage" = "about:blank";
      "privacy.trackingprotection.enabled" = true;
      "dom.security.https_only_mode" = true;
    };
  };
}
