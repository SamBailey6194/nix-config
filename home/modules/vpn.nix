{ config, pkgs, lib, ... }:

{
  # VPN-first browser configuration
  # All browsers launched via GUI or default shell command use VPN
  # LAN networks (Docker, DDEV, venvs) automatically bypass VPN via routing rules

  # Override desktop entries to ALWAYS launch browsers through VPN
  xdg.desktopEntries = {
    firefox = {
      name = "Firefox";
      icon = "firefox";
      exec = "vpn-app firefox %U";
      categories = [ "Network" "WebBrowser" ];
      mimeType = [
        "text/html"
        "text/xml"
        "application/xhtml+xml"
        "application/vnd.mozilla.xul+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
      comment = "Browse the Web (via VPN)";
    };

    librewolf = {
      name = "LibreWolf";
      icon = "librewolf";
      exec = "vpn-app librewolf %U";
      categories = [ "Network" "WebBrowser" ];
      mimeType = [
        "text/html"
        "text/xml"
        "application/xhtml+xml"
        "application/vnd.mozilla.xul+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
      comment = "Browse the Web (via VPN)";
    };

    "google-chrome" = {
      name = "Google Chrome";
      icon = "google-chrome";
      exec = "vpn-app google-chrome %U";
      categories = [ "Network" "WebBrowser" ];
      mimeType = [
        "text/html"
        "text/xml"
        "application/xhtml+xml"
        "x-scheme-handler/http"
        "x-scheme-handler/https"
      ];
      comment = "Browse the Web (via VPN)";
    };
  };

  # Shell aliases for VPN management and direct browser access
  programs.zsh.shellAliases = {
    # VPN service control
    vpn-on = "sudo systemctl start wg-quick-mullvad0";
    vpn-off = "sudo systemctl stop wg-quick-mullvad0";
    vpn-restart = "sudo systemctl restart wg-quick-mullvad0";
    vpn-status = "sudo systemctl status wg-quick-mullvad0";

    # Browsers through VPN (default behavior, but explicit for clarity)
    firefox-vpn = "vpn-app firefox";
    chrome-vpn = "vpn-app google-chrome";
    librewolf-vpn = "vpn-app librewolf";

    # Direct browser access (bypass VPN if needed for troubleshooting)
    firefox-direct = "firefox";
    chrome-direct = "google-chrome";
    librewolf-direct = "librewolf";

    # Torrent client always through VPN
    transmission-vpn = "vpn-app transmission-gtk";
  };

  # Bash aliases (in case user switches to bash)
  programs.bash.shellAliases = {
    vpn-on = "sudo systemctl start wg-quick-mullvad0";
    vpn-off = "sudo systemctl stop wg-quick-mullvad0";
    vpn-restart = "sudo systemctl restart wg-quick-mullvad0";
    vpn-status = "sudo systemctl status wg-quick-mullvad0";

    firefox-vpn = "vpn-app firefox";
    chrome-vpn = "vpn-app google-chrome";
    librewolf-vpn = "vpn-app librewolf";

    firefox-direct = "firefox";
    chrome-direct = "google-chrome";
    librewolf-direct = "librewolf";

    transmission-vpn = "vpn-app transmission-gtk";
  };
}
