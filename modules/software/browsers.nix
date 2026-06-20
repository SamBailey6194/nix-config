{ config, pkgs, ... }:

{
  # Web browsers.
  #
  # The locked accountability browser set (Brave, LibreWolf, Firefox Developer
  # Edition, Zen) is installed + policy-locked by
  # modules/security/browser-policies. Regular Firefox and Google Chrome have
  # been removed from this system: Brave is the Chromium/Claude-extension
  # browser, and Zen / LibreWolf / Firefox Developer Edition cover the rest.
  # This file keeps only the non-managed LibreWolf install for hosts that don't
  # enable the browser-policies module.

  environment.systemPackages = with pkgs; [
    # Privacy-focused browser (personal use). Also installed + locked by the
    # browser-policies module; kept here for hosts that don't enable that module.
    librewolf

    # Alternative browsers (optional)
    # vivaldi          # Feature-rich browser
  ];
}
