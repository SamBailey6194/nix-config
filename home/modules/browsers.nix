{ config, pkgs, lib, ... }:

{
  # Browser configuration (user-level).
  #
  # Regular Firefox and Google Chrome have been removed from this system. The
  # managed browser set (Brave, LibreWolf, Firefox Developer Edition, Zen) is
  # installed + policy-locked by modules/security/browser-policies. This file
  # keeps the LibreWolf user profile and sets Zen as the default browser.

  # LibreWolf user profile (strong privacy defaults; minimal overrides)
  programs.librewolf = {
    enable = true;

    settings = {
      # Restore session on startup
      "browser.startup.page" = 3; # 1=home, 2=blank, 3=restore session

      # Downloads
      "browser.download.useDownloadDir" = true;
      "browser.download.folderList" = 1;

      # Vertical tabs (Firefox 136+)
      "sidebar.verticalTabs" = true;
      "sidebar.revamp" = true;

      # Hide bookmarks toolbar
      "browser.toolbars.bookmarks.visibility" = "never";
    };
  };

  # Set Zen as default browser
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "zen-beta.desktop";
      "x-scheme-handler/http" = "zen-beta.desktop";
      "x-scheme-handler/https" = "zen-beta.desktop";
      "x-scheme-handler/about" = "zen-beta.desktop";
      "x-scheme-handler/unknown" = "zen-beta.desktop";
    };
  };
}
