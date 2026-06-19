{ config, pkgs, lib, ... }:

{
  # Shared browser configuration for Firefox and LibreWolf
  # Both browsers will have identical settings, privacy configurations, and search engines

  programs.firefox = {
    enable = true;

    profiles.default = {
      id = 0;
      name = "default";
      isDefault = true;

      # Search engines
      search = {
        default = "ddg";
        force = true;

        engines = {
          "ddg" = {
            name = "DuckDuckGo";
            urls = [{ template = "https://duckduckgo.com/?q={searchTerms}"; }];
            icon = "https://duckduckgo.com/favicon.ico";
            definedAliases = [ "@ddg" ];
          };

          "google" = {
            name = "Google";
            urls = [{ template = "https://www.google.com/search?q={searchTerms}"; }];
            icon = "https://www.google.com/favicon.ico";
            definedAliases = [ "@g" ];
          };

          "github" = {
            name = "GitHub";
            urls = [{ template = "https://github.com/search?q={searchTerms}"; }];
            icon = "https://github.com/favicon.ico";
            definedAliases = [ "@gh" ];
          };

          "nixos-options" = {
            name = "NixOS Options";
            urls = [{ template = "https://search.nixos.org/options?query={searchTerms}"; }];
            icon = "https://nixos.org/favicon.ico";
            definedAliases = [ "@no" ];
          };

          "nixos-packages" = {
            name = "NixOS Packages";
            urls = [{ template = "https://search.nixos.org/packages?query={searchTerms}"; }];
            icon = "https://nixos.org/favicon.ico";
            definedAliases = [ "@np" ];
          };
        };
      };

      # Privacy and security settings (from your Ubuntu Firefox)
      settings = {
        # Enhanced Privacy (matching your current settings)
        "privacy.donottrackheader.enabled" = true;
        "privacy.trackingprotection.enabled" = true;
        "privacy.trackingprotection.socialtracking.enabled" = true;
        "privacy.trackingprotection.emailtracking.enabled" = true;
        "privacy.partition.network_state.ocsp_cache" = true;
        "privacy.fingerprintingProtection" = true;
        "privacy.globalprivacycontrol.enabled" = true;
        "privacy.query_stripping.enabled" = true;
        "privacy.query_stripping.enabled.pbmode" = true;
        "privacy.bounceTrackingProtection.mode" = 1;

        # Disable telemetry
        "browser.newtabpage.activity-stream.feeds.telemetry" = false;
        "browser.newtabpage.activity-stream.telemetry" = false;
        "browser.ping-centre.telemetry" = false;
        "toolkit.telemetry.archive.enabled" = false;
        "toolkit.telemetry.bhrPing.enabled" = false;
        "toolkit.telemetry.enabled" = false;
        "toolkit.telemetry.firstShutdownPing.enabled" = false;
        "toolkit.telemetry.hybridContent.enabled" = false;
        "toolkit.telemetry.newProfilePing.enabled" = false;
        "toolkit.telemetry.reportingpolicy.firstRun" = false;
        "toolkit.telemetry.shutdownPingSender.enabled" = false;
        "toolkit.telemetry.unified" = false;
        "toolkit.telemetry.updatePing.enabled" = false;

        # Firefox Sync (enable temporarily for initial setup, then disable)
        "identity.fxaccounts.enabled" = true;  # Set to false after sync complete

        # Performance
        "browser.cache.disk.enable" = true;
        "browser.sessionstore.resume_from_crash" = true;

        # UI/UX
        "browser.tabs.warnOnClose" = false;
        "browser.download.useDownloadDir" = true;
        "browser.download.folderList" = 1; # 0=Desktop, 1=Downloads, 2=Custom

        # Disable Pocket
        "extensions.pocket.enabled" = false;

        # Enable containers (Multi-Account Containers extension recommended)
        "privacy.userContext.enabled" = true;
        "privacy.userContext.ui.enabled" = true;

        # HTTPS-Only mode
        "dom.security.https_only_mode" = true;
        "dom.security.https_only_mode_ever_enabled" = true;
      };

      # Extensions (Note: Some extensions need manual setup after installation)
      # extensions = with pkgs.nur.repos.rycee.firefox-addons; [
      #   ublock-origin
      #   privacy-badger
      #   multi-account-containers
      #   bitwarden
      # ];
    };
  };

  # LibreWolf with same settings as Firefox
  programs.librewolf = {
    enable = true;

    # LibreWolf settings (inherits Firefox privacy defaults, but can override)
    settings = {
      # Use same privacy settings as Firefox profile above
      # LibreWolf has strong privacy defaults, so minimal config needed

      # Allow DRM content (Netflix, etc.) - uncomment if needed
      # "media.eme.enabled" = true;

      # Restore session on startup
      "browser.startup.page" = 3; # 1=home, 2=blank, 3=restore session

      # Downloads
      "browser.download.useDownloadDir" = true;
      "browser.download.folderList" = 1;
    };
  };

  # Set default browser (LibreWolf for privacy, Firefox as backup)
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/html" = "librewolf.desktop";
      "x-scheme-handler/http" = "librewolf.desktop";
      "x-scheme-handler/https" = "librewolf.desktop";
      "x-scheme-handler/about" = "librewolf.desktop";
      "x-scheme-handler/unknown" = "librewolf.desktop";
    };
  };
}
