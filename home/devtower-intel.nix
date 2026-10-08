{ config, lib, osConfig ? { }, ... }:

let
  link = config.lib.file.mkOutOfStoreSymlink;

  # DavinciProj, the NTFS drive shared with Windows (hardware-configuration.nix,
  # docs/DAVINCI-SHARED-DRIVE.md).
  davinci = "/mnt/davinci";

  # The letter Windows gives DavinciProj (Disk Management), lower case, e.g. "e".
  # Affinity's Wine prefix then maps the same letter to the drive, so linked
  # resources saved on one OS resolve on the other. Wine only picks the letter
  # for paths under the drive root itself (no realpath), so open files through
  # /mnt/davinci or ~/DavinciProj, never a symlink to a subfolder.
  davinciDriveLetter = null;

  hasResolve = builtins.any (p: (p.pname or "") == "davinci-resolve-studio")
    (osConfig.environment.systemPackages or [ ]);
in
{
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
