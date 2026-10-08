{ config, pkgs, lib, osConfig ? { }, ... }:

# File management: Yazi (main), Thunar (backup).
#
#   SUPER + F          Yazi in kitty, on workspace 10   (config/hypr/60-keybinds.lua)
#   SUPER + SHIFT + F  Thunar, on workspace 10
#   F1 inside Yazi     ~/.config/yazi/KEYBINDS.md in less, in the same window
#                      (generated from `keybinds` below)
#   `y` in a shell     Yazi, then cd to wherever it was left (q; Q skips the cd)
#
# Companions, all configured below:
#
#   ouch       archive preview (ouch.yazi), compression (C) and extraction
#   udiskie    automounts removable drives to /run/media/$USER, tray icon in
#              waybar; replaces thunar-volman
#   ripdrag    drag files out to GUI apps from the keyboard (ALT + d)
#   termfilechooser
#              Yazi as the system "Open / Save file" dialog. The portal itself
#              is installed system-side (modules/desktop/hyprland/default.nix);
#              its config file has to be user-level, see below.
#
# Yazi 26.8+ ALSO drags and drops natively in kitty (OSC 72, kitty 0.47+):
# mouse-drag a file out of Yazi, or drop one onto it. ripdrag is the keyboard
# route and the one that handles a whole selection at once.
#
# KEYBINDS ARE DECLARATIVE
#
# `keybinds` below is the single source of truth, the same pattern as
# home/modules/neovim.nix: it renders BOTH Yazi's keymap.toml AND the
# ~/.config/yazi/KEYBINDS.md that F1 shows, so the sheet cannot drift from
# the bindings. Add, move or remove a binding there and rebuild.
#
# Entries with `run` are ours: PREPENDED to Yazi's defaults, so a default
# with the same keys is replaced and every other default stays active.
# `docOnly = true` entries are Yazi's built-in defaults (or keys that only
# exist inside a plugin or the picker), listed so the sheet is complete; to
# change one, give it a `run`. Ours are marked `*` on the sheet. Yazi's `~`
# opens its command palette, which lists every live binding by `desc`.
#
# YAZI 26.x SHELL SYNTAX
#
# Commands run as `sh -c <cmd>` with NO positional arguments, so `$@`/`$1`
# expand to nothing (deprecated in 25.12.29, removed in practice). Use the %
# placeholders, which Yazi shell-quotes itself, so never quote them:
#   %s  selected files, or the hovered one when nothing is selected
#   %h  the hovered file      %d  parent dir of each selected file
# `shell --confirm` is gone too. Older plugin READMEs (ouch.yazi's included)
# still show the `"$@"` form; it silently passes no files.

let
  # RAR support needs the unfree unrar feature; allowUnfree is already on
  # (modules/core/nix-settings.nix). Without it ouch, and Yazi's bundled 7zz,
  # cannot open .rar at all.
  ouch = pkgs.ouch.override { enableUnfree = true; };

  # udisks2 mounts removable media under /run/media/<user> (the user differs
  # per device: sam-laptop, sam-framework, sam-desktop).
  mediaDir = "/run/media/${config.home.username}";

  # The DavinciProj NTFS drive shared with Windows (docs/DAVINCI-SHARED-DRIVE.md),
  # on hosts that mount it. Go through /mnt/davinci itself, not a symlink to a
  # subfolder, so Affinity under Wine records the drive letter, not Z:\home\...
  davinci = "/mnt/davinci";
  davinciKeys = lib.optionals ((osConfig.fileSystems or { }) ? ${davinci}) [
    { group = "Go to"; on = [ "g" "D" ]; desc = "DavinciProj drive (${davinci})"; run = "cd ${davinci}"; }
    { group = "Go to"; on = [ "g" "a" ]; desc = "Affinity files on DavinciProj"; run = "cd ${davinci}/Affinity"; }
  ];

  # ── Keybinds ───────────────────────────────────────────────────────────
  #
  # `on` is the key sequence as Yazi takes it ([ "g" "m" ] = g then m).
  # Defaults are from Yazi 26.9.1's preset keymap-default.toml.
  keybinds = [
    { group = "Help"; on = [ "<F1>" ]; desc = "This sheet (q to go back)";
      run = "shell --block 'less ~/.config/yazi/KEYBINDS.md'"; }
    { group = "Help"; on = [ "~" ]; desc = "Command palette: every live key, Enter runs it"; docOnly = true; }

    { group = "Move"; on = [ "k" ]; desc = "Up (also Up arrow)"; docOnly = true; }
    { group = "Move"; on = [ "j" ]; desc = "Down (also Down arrow)"; docOnly = true; }
    { group = "Move"; on = [ "h" ]; desc = "Parent folder (also Left arrow)"; docOnly = true; }
    { group = "Move"; on = [ "l" ]; desc = "Enter folder (also Right arrow)"; docOnly = true; }
    { group = "Move"; on = [ "g" "g" ]; desc = "Top"; docOnly = true; }
    { group = "Move"; on = [ "G" ]; desc = "Bottom"; docOnly = true; }
    { group = "Move"; on = [ "<C-u>" ]; desc = "Half page up (<C-b> full page)"; docOnly = true; }
    { group = "Move"; on = [ "<C-d>" ]; desc = "Half page down (<C-f> full page)"; docOnly = true; }
    { group = "Move"; on = [ "H" ]; desc = "Back in history"; docOnly = true; }
    { group = "Move"; on = [ "L" ]; desc = "Forward in history"; docOnly = true; }
    { group = "Move"; on = [ "K" ]; desc = "Scroll preview up (J down)"; docOnly = true; }

    { group = "Go to"; on = [ "g" "h" ]; desc = "Home"; docOnly = true; }
    { group = "Go to"; on = [ "g" "c" ]; desc = "~/.config"; docOnly = true; }
    { group = "Go to"; on = [ "g" "d" ]; desc = "~/Downloads"; docOnly = true; }
    { group = "Go to"; on = [ "g" "r" ]; desc = "~/Repos"; run = "cd ~/Repos"; }
    { group = "Go to"; on = [ "g" "m" ]; desc = "Mounted drives (${mediaDir})"; run = "cd ${mediaDir}"; }
  ] ++ davinciKeys ++ [
    { group = "Go to"; on = [ "g" "<Space>" ]; desc = "Type a path"; docOnly = true; }
    { group = "Go to"; on = [ "g" "f" ]; desc = "Follow symlink"; docOnly = true; }
    { group = "Go to"; on = [ "Z" ]; desc = "Jump with zoxide"; docOnly = true; }
    { group = "Go to"; on = [ "z" ]; desc = "Jump with fzf"; docOnly = true; }

    { group = "Select"; on = [ "<Space>" ]; desc = "Toggle file, move down"; docOnly = true; }
    { group = "Select"; on = [ "v" ]; desc = "Visual select (V: visual unselect)"; docOnly = true; }
    { group = "Select"; on = [ "<C-a>" ]; desc = "Select all"; docOnly = true; }
    { group = "Select"; on = [ "<C-r>" ]; desc = "Invert selection"; docOnly = true; }
    { group = "Select"; on = [ "<Esc>" ]; desc = "Clear selection / cancel"; docOnly = true; }

    { group = "Open"; on = [ "<Enter>" ]; desc = "Open (also o)"; docOnly = true; }
    { group = "Open"; on = [ "O" ]; desc = "Open with... (pick: Neovim, Zed, ...)"; docOnly = true; }
    { group = "Open"; on = [ "<Tab>" ]; desc = "File info (spot)"; docOnly = true; }

    { group = "File ops"; on = [ "y" ]; desc = "Copy (yank)"; docOnly = true; }
    { group = "File ops"; on = [ "x" ]; desc = "Cut"; docOnly = true; }
    { group = "File ops"; on = [ "p" ]; desc = "Paste (P: overwrite)"; docOnly = true; }
    { group = "File ops"; on = [ "Y" ]; desc = "Cancel copy / cut (also X)"; docOnly = true; }
    { group = "File ops"; on = [ "d" ]; desc = "Move to trash"; docOnly = true; }
    { group = "File ops"; on = [ "D" ]; desc = "Delete permanently"; docOnly = true; }
    { group = "File ops"; on = [ "a" ]; desc = "Create (end with / for a folder)"; docOnly = true; }
    { group = "File ops"; on = [ "r" ]; desc = "Rename (bulk in Neovim if several)"; docOnly = true; }
    { group = "File ops"; on = [ "-" ]; desc = "Paste as symlink (_: relative)"; docOnly = true; }
    { group = "File ops"; on = [ "." ]; desc = "Show / hide hidden files"; docOnly = true; }

    { group = "Archives and drives"; on = [ "C" ]; desc = "Compress selection to .zip (ouch)"; run = "plugin ouch"; }
    { group = "Archives and drives"; on = [ "<A-c>" ]; desc = "Compress selection to .7z (ouch)"; run = "plugin ouch 7z"; }
    { group = "Archives and drives"; on = [ "<Enter>" ]; desc = "On an archive: extract to a new folder"; docOnly = true; }
    { group = "Archives and drives"; on = [ "M" ]; desc = "Drives: m mount, u unmount, e eject, Enter go"; run = "plugin mount"; }

    # -x closes ripdrag after one drag, -a adds a "drag all" button for a
    # multi-file selection. --orphan detaches it so Yazi stays usable.
    { group = "Drag and drop"; on = [ "<A-d>" ]; desc = "Drag selection out (ripdrag window)"; run = "shell --orphan 'ripdrag -x -a %s'"; }
    { group = "Drag and drop"; on = [ "mouse" ]; desc = "Drag a file out of Yazi, or drop one onto it"; docOnly = true; }

    { group = "Search"; on = [ "s" ]; desc = "Find by name (fd)"; docOnly = true; }
    { group = "Search"; on = [ "S" ]; desc = "Find by content (ripgrep)"; docOnly = true; }
    { group = "Search"; on = [ "<C-s>" ]; desc = "Cancel search"; docOnly = true; }
    { group = "Search"; on = [ "f" ]; desc = "Filter this folder"; docOnly = true; }
    { group = "Search"; on = [ "/" ]; desc = "Find next (? previous; n / N repeat)"; docOnly = true; }

    { group = "Copy path"; on = [ "c" "c" ]; desc = "Full path"; docOnly = true; }
    { group = "Copy path"; on = [ "c" "d" ]; desc = "Folder path"; docOnly = true; }
    { group = "Copy path"; on = [ "c" "f" ]; desc = "File name"; docOnly = true; }
    { group = "Copy path"; on = [ "c" "n" ]; desc = "Name without extension"; docOnly = true; }

    { group = "Sort"; on = [ "," "m" ]; desc = "Modified (capital letter = reverse)"; docOnly = true; }
    { group = "Sort"; on = [ "," "s" ]; desc = "Size"; docOnly = true; }
    { group = "Sort"; on = [ "," "a" ]; desc = "Alphabetical"; docOnly = true; }
    { group = "Sort"; on = [ "," "n" ]; desc = "Natural"; docOnly = true; }
    { group = "Sort"; on = [ "," "e" ]; desc = "Extension"; docOnly = true; }

    { group = "Tabs"; on = [ "t" "t" ]; desc = "New tab"; docOnly = true; }
    { group = "Tabs"; on = [ "1" ]; desc = "Tab 1 (1-9)"; docOnly = true; }
    { group = "Tabs"; on = [ "[" ]; desc = "Previous tab (] next)"; docOnly = true; }
    { group = "Tabs"; on = [ "<C-c>" ]; desc = "Close tab (quits on the last)"; docOnly = true; }

    { group = "Shell and quit"; on = [ ";" ]; desc = "Run a shell command"; docOnly = true; }
    { group = "Shell and quit"; on = [ ":" ]; desc = "Run a shell command, wait for it"; docOnly = true; }
    { group = "Shell and quit"; on = [ "w" ]; desc = "Background tasks"; docOnly = true; }
    { group = "Shell and quit"; on = [ "q" ]; desc = "Quit (`y` in zsh: cd to this folder)"; docOnly = true; }
    { group = "Shell and quit"; on = [ "Q" ]; desc = "Quit without the cd"; docOnly = true; }

    { group = "As a file picker"; on = [ "<Enter>" ]; desc = "Choose the file"; docOnly = true; }
    { group = "As a file picker"; on = [ "<Space>" ]; desc = "Mark several, then Enter"; docOnly = true; }
    { group = "As a file picker"; on = [ "q" ]; desc = "Folder picker: choose the current folder"; docOnly = true; }
    { group = "As a file picker"; on = [ "Q" ]; desc = "Cancel"; docOnly = true; }
    { group = "As a file picker"; on = [ "r" ]; desc = "Save: rename the help file, then Enter it"; docOnly = true; }
  ];

  renderBinding = k: { inherit (k) on run desc; };
  prependKeymap = map renderBinding (builtins.filter (k: !(k.docOnly or false)) keybinds);

  # Padded into aligned columns because it is read raw, in less. Padding
  # counts bytes, which equals columns while every cell is ASCII.
  repeatStr = n: s: lib.concatStrings (lib.genList (_: s) n);
  padRight = width: s: s + repeatStr (width - lib.stringLength s) " ";
  keyCell = k: "`${lib.concatStringsSep " " k.on}`" + lib.optionalString (!(k.docOnly or false)) " *";

  renderGroup = group:
    let
      rows = lib.filter (k: k.group == group) keybinds;
      widest = cells: lib.foldl' lib.max 0 (map lib.stringLength cells);
      keyWidth = widest ([ "Key" ] ++ map keyCell rows);
      descWidth = widest ([ "Action" ] ++ map (k: k.desc) rows);
      line = key: desc: "| ${padRight keyWidth key} | ${padRight descWidth desc} |";
    in
    "## ${group}\n\n"
    + line "Key" "Action" + "\n"
    + "| ${repeatStr keyWidth "-"} | ${repeatStr descWidth "-"} |\n"
    + lib.concatMapStringsSep "\n" (k: line (keyCell k) k.desc) rows;

  keybindsMarkdown = ''
    # Yazi keybinds

    `q` closes this sheet. `*` = set in this config;
    the rest are Yazi's defaults. Generated from
    `home/modules/file-manager.nix`: do not edit by
    hand, the file is rewritten on every rebuild.

    `~` opens Yazi's own palette of every live key.

  '' + lib.concatMapStringsSep "\n\n" renderGroup (lib.unique (map (k: k.group) keybinds)) + "\n";
in
{
  programs.yazi = {
    enable = true;

    # The HM default is still "yy" for stateVersion < 26.05 (this repo is on
    # 24.11) and prints a deprecation warning, so name it explicitly.
    shellWrapperName = "y";
    enableZshIntegration = true;

    # On PATH for Yazi and its plugins only (the nixpkgs wrapper already adds
    # 7zz, ffmpeg, poppler, fd, ripgrep, fzf, zoxide, imagemagick, jq, chafa
    # and resvg). The rest are what the plugins and preset openers shell out
    # to: mount.yazi -> udisksctl, lsblk, eject, gdbus; the preset "reveal"
    # and "play" openers -> exiftool, mediainfo.
    extraPackages = [
      # The `edit` opener below runs nvim, but Neovim is otherwise only
      # installed from the dev stage up. On Yazi's PATH only, so it does not
      # clash with programs.neovim later.
      pkgs.neovim
      ouch
      pkgs.ripdrag
      pkgs.udisks
      pkgs.util-linux
      pkgs.glib
      pkgs.mediainfo
      pkgs.exiftool
    ];

    plugins = {
      ouch = pkgs.yaziPlugins.ouch;   # archive preview + compress (C)
      mount = pkgs.yaziPlugins.mount; # mount / unmount / eject UI (M)
    };

    settings = {
      plugin.prepend_previewers = [
        # ouch.yazi lists the archive as a tree. It is a previewer only; the
        # opener below handles extraction.
        {
          mime = "application/{*zip,tar,bzip2,7z*,rar,xz,zstd,java-archive}";
          run = "ouch";
        }
      ];

      opener = {
        # Replaces the preset `extract` opener (`ya pub extract`, 7zz).
        # ouch 0.8 unpacks into a new folder named after the archive, and
        # skips the folder when the archive holds a single same-named entry,
        # so extracting never sprays files into the current directory.
        extract = [
          { run = "ouch d -y %s"; desc = "Extract (ouch)"; }
        ];

        # Replaces the preset `edit` opener, which runs `$EDITOR`. EDITOR here
        # is `zeditor --wait` (home/stages/dev.nix), and the preset opener
        # blocks — Yazi would freeze until Zed closed. Neovim runs inside
        # Yazi's own window instead (on Yazi's PATH in every stage, see
        # extraPackages); Zed stays one `O` (open with...) away and is
        # orphaned, so it does not hold Yazi up. Zed only exists from the dev
        # stage up.
        edit = [
          { run = "nvim %s"; block = true; desc = "Neovim"; }
          { run = "zeditor %s"; orphan = true; desc = "Zed"; }
        ];
      };
    };

    # Generated from `keybinds` above, which also renders KEYBINDS.md.
    keymap.mgr.prepend_keymap = prependKeymap;
  };

  # Opened by F1 in Yazi (and readable with `less` from anywhere).
  xdg.configFile."yazi/KEYBINDS.md".text = keybindsMarkdown;

  # ── Yazi as the "Open / Save file" dialog ──────────────────────────────────
  #
  # xdg-desktop-portal-termfilechooser looks for its config ONLY under
  # $XDG_CONFIG_HOME and its own store prefix: the compiled SYSCONFDIR is the
  # store path, so /etc/xdg is never searched on NixOS. Hence a user file.
  #
  # The values go through wordexp(), which strips quotes, so nothing here may
  # be quoted (a quoted title breaks into separate words). The kitty class
  # `termfilechooser` is what the Hyprland rules match on to float the picker
  # on the CURRENT workspace (00-vars.lua, 70-windowrules.lua).
  #
  # How to use it: Enter on a file picks it; Space selects several, then
  # Enter. For a folder, navigate into it and press q. Saving: the portal
  # drops a help file at the suggested name — rename it if you want, then
  # open it (Enter). Q cancels.
  #
  # The daemon reads this once at start:
  #   systemctl --user restart xdg-desktop-portal-termfilechooser.service
  xdg.configFile."xdg-desktop-portal-termfilechooser/config".text = ''
    [filechooser]
    cmd=yazi-wrapper.sh
    default_dir=$HOME
    env=TERMCMD=kitty --class termfilechooser --title termfilechooser
    open_mode=suggested
    save_mode=last
  '';

  # GTK 3 apps also need GTK_USE_PORTAL=1 to use this picker. That is set
  # system-wide (modules/desktop/hyprland/default.nix), because HM session
  # variables never reach apps launched from Hyprland.

  # ── Removable drives ───────────────────────────────────────────────────────
  #
  # Mounts on plug-in via udisks2 (system: services.udisks2), no password for
  # the active session user. The tray icon goes to waybar's tray via
  # StatusNotifierItem, which udiskie picks automatically on Wayland. The HM
  # unit Requires tray.target, which waybar's unit provides.
  #
  # "Browse" from the tray or a notification opens the drive in Yazi, in a
  # kitty with the `yazi` class so it lands on workspace 10 like SUPER + F.
  services.udiskie = {
    enable = true;
    automount = true;
    notify = true;
    tray = "auto"; # icon only while a drive is present
    settings.program_options.file_manager = "kitty --class yazi yazi";
  };

  # thunar-volman is no longer installed (udiskie owns automounting), so stop
  # Thunar trying to spawn it on every device event. Needs the NixOS-side
  # programs.xfconf.enable (modules/desktop/hyprland/default.nix).
  xfconf.settings.thunar."misc-volume-management" = false;

  home.packages = [ ouch ];
}
