{ config, pkgs, lib, ... }:

let
  # Brave's vertical tabs are profile prefs, not policies (the managed policy
  # set has no key for them), so they are merged into Default/Preferences.
  # Values are the ones observed on the Ubuntu desktop: collapsed left tab
  # strip, window title shown above the toolbar, URL bar along the top.
  braveLayout = {
    brave.tabs = {
      vertical_tabs_enabled = true;
      vertical_tabs_collapsed = true;
      vertical_tabs_on_right = false;
      vertical_tabs_show_title_on_window = true;
      vertical_tabs_show_scrollbar = true;
      vertical_tabs_expanded_state_per_window = false;
    };
    bookmark_bar.show_on_all_tabs = false;
  };
in
{
  # Browser configuration (user-level).
  #
  # Regular Firefox and Google Chrome have been removed from this system. The
  # managed browser set (Brave, LibreWolf, Firefox Developer Edition, Zen) is
  # installed + policy-locked by modules/security/browser-policies. This file
  # keeps the LibreWolf user profile, Brave's vertical-tab layout and sets Zen
  # as the default browser.

  # LibreWolf user profile (strong privacy defaults; minimal overrides)
  programs.librewolf = {
    enable = true;

    settings = {
      # Vertical tabs (Firefox 136+)
      "sidebar.verticalTabs" = true;
      "sidebar.revamp" = true;

      # Hide bookmarks toolbar
      "browser.toolbars.bookmarks.visibility" = "never";
    };
  };

  # Re-applied on every activation, like the Gecko pref() lines in
  # modules/security/browser-policies. Skipped while Brave runs, because it
  # rewrites Preferences from memory on exit and would undo the merge.
  home.activation.braveLayout = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    braveDir="''${XDG_CONFIG_HOME:-$HOME/.config}/BraveSoftware/Brave-Browser/Default"
    bravePrefs="$braveDir/Preferences"
    braveLayout=${lib.escapeShellArg (builtins.toJSON braveLayout)}

    if ${pkgs.procps}/bin/pgrep -u "$(id -u)" -x brave >/dev/null; then
      echo "braveLayout: Brave is running; skipped (quit Brave and rebuild to apply vertical tabs)" >&2
    else
      mkdir -p "$braveDir"
      braveInput=/dev/null
      if [ -s "$bravePrefs" ]; then braveInput=$bravePrefs; fi
      braveTmp=$(mktemp "$braveDir/.Preferences.XXXXXX")
      if ${pkgs.jq}/bin/jq -c -n --slurpfile cur "$braveInput" --argjson layout "$braveLayout" \
           '($cur[0] // {}) * $layout' > "$braveTmp"; then
        mv "$braveTmp" "$bravePrefs"
      else
        rm -f "$braveTmp"
        echo "braveLayout: could not parse $bravePrefs; left untouched" >&2
      fi
    fi
  '';

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
