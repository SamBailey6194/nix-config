{ config, pkgs, ... }:

{
  # Web browsers for different purposes.
  #
  # The locked accountability browser set (Brave, LibreWolf, Firefox Developer
  # Edition, Zen) is installed + policy-locked by
  # modules/security/browser-policies. Brave is now the Chromium/Claude-extension
  # browser, so Google Chrome is dropped here. This file keeps only non-managed
  # extras.

  environment.systemPackages = with pkgs; [
    # Privacy-focused browser (personal use). Also installed + locked by the
    # browser-policies module; kept here for hosts that don't enable that module.
    librewolf

    # Development testing browser
    firefox

    # Alternative browsers (optional)
    # chromium         # Open-source Chrome
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
