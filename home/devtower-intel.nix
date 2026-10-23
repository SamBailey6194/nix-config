{ config, lib, osConfig ? { }, ... }:

let
  link = config.lib.file.mkOutOfStoreSymlink;

  # The NTFS drive shared with Windows: DavinciProj (hardware-configuration.nix,
  # docs/DAVINCI-SHARED-DRIVE.md) until the WD becomes the VeraCrypt data
  # volume, then /mnt/data (data-pair.nix, docs/SHARED-DATA-DRIVES.md), which
  # keeps the DavinciProj tree at its root.
  davinci =
    if (import ../hosts/devtower-intel/disks.nix).dataPair.data.partUuid != null
    then "/mnt/data" else "/mnt/davinci";

  # The letter Windows gives DavinciProj (Disk Management), lower case, e.g. "e";
  # for the data volume, the letter its VeraCrypt favourite mounts it at.
  # Affinity's Wine prefix then maps the same letter to the drive, so linked
  # resources saved on one OS resolve on the other. The letter maps the volume
  # root, so a file in <area>/design/ is <letter>:\<area>\design\... on both
  # OSes. Wine only picks the letter for paths under the drive root itself (no
  # realpath), so open files through the drive root (davinci above),
  # ~/DavinciProj or ~/Data (a bind mount of the root), never a symlink to a
  # subfolder.
  davinciDriveLetter = "f";

  hasResolve = import ./modules/resolve-package.nix { inherit lib osConfig; } != null;
in
{
  # Files finished meetings into syntek-business-docs (only where
  # software.meetingNotes is on: the dev stage and up).
  imports = [ ./modules/meeting-notes-filing.nix ];

  # Keep Cargo artifacts outside any repository Nix might copy as a flake.
  home.sessionVariables.CARGO_TARGET_DIR = "${config.xdg.cacheHome}/cargo-target";
  programs.zsh.envExtra = ''
    export CARGO_TARGET_DIR="${config.xdg.cacheHome}/cargo-target"
  '';

  # Replace the future AMD tower's monitor/app rules entirely on this PC.
  wayland.windowManager.hyprland.extraLuaFiles."90-device" = {
    content = lib.mkForce ../config/hypr/devices/devtower-intel.lua;
    autoLoad = true;
  };
  wayland.windowManager.hyprland.extraLuaFiles."96-dashboard" = lib.mkIf
    (osConfig.services.localLlm.enable or false) {
      content = ../config/hypr/devices/devtower-intel-dashboard.lua;
      autoLoad = true;
    };

  # The 40-workspace map above needs its own cheat sheet; the ws1 dashboard
  # and SUPER + / both read this path.
  home.file.".config/hypr/KEYBINDS.md".source =
    lib.mkForce ../config/hypr/KEYBINDS-devtower-intel.md;

  # Zen is for streaming only on this PC (workspace 12), so links open in
  # Brave instead. home/modules/browsers.nix and home/stages/desktop.nix both
  # set Zen for these types and the lists merge, so each one is forced here.
  xdg.mimeApps.defaultApplications = lib.genAttrs [
    "text/html"
    "x-scheme-handler/http"
    "x-scheme-handler/https"
    "x-scheme-handler/about"
    "x-scheme-handler/unknown"
    "application/x-extension-htm"
    "application/x-extension-html"
    "application/x-extension-shtml"
    "application/xhtml+xml"
    "application/x-extension-xhtml"
    "application/x-extension-xht"
  ] (_: lib.mkForce "brave-browser.desktop");
  home.sessionVariables.BROWSER = lib.mkForce "brave";

  # Desktop: never dim, lock or blank on idle. hypridle keeps running for the
  # manual paths only - its lock_cmd serves SUPER+CTRL+L (loginctl
  # lock-session) and before_sleep_cmd still locks ahead of a manual suspend.
  services.hypridle.settings.listener = lib.mkForce [ ];

  # The drive root in the home folder (a link to the root keeps Wine's drive
  # letter mapping; see davinciDriveLetter above).
  home.file."DavinciProj".source = link davinci;

  # affinity-nix overlays ~/.local/share/affinity on its read-only prefix, so a
  # dosdevices entry here adds the drive letter to Designer, Photo and Publisher.
  # Don't rebuild while an Affinity app is open (overlayfs upper layer).
  xdg.dataFile = lib.optionalAttrs (davinciDriveLetter != null) {
    "affinity/dosdevices/${davinciDriveLetter}:".source = link davinci;
  };

  # home/devtower.nix's resolve/dvr aliases carry AMD Rusticl and DRI_PRIME
  # variables for the future AMD tower; this PC is NVIDIA (CUDA). Resolve still
  # needs XWayland, and the session sets QT_QPA_PLATFORM=wayland.
  programs.zsh.shellAliases = lib.mkIf hasResolve {
    resolve = lib.mkForce "QT_QPA_PLATFORM=xcb davinci-resolve-studio";
    dvr = lib.mkForce "QT_QPA_PLATFORM=xcb davinci-resolve-studio";
  };
}
