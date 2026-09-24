{ pkgs, lib, osConfig ? null, ... }:

# System monitors: btop is the main one, htop the backup.
#
#   SUPER + M          btop in kitty          (config/hypr/60-keybinds.lua)
#   SUPER + SHIFT + M  htop in kitty
#   workspace 1        btop is the dashboard's right-hand pane, relaunched by
#                      SUPER + Escape if closed (config/hypr/devices/laptop-intel.lua)
#
# htop stays as the fallback for whenever btop cannot draw: a terminal below
# btop's 80x24 minimum, or a TTY without a UTF-8 locale (btop refuses to
# start). A bad btop.conf is NOT one of them: btop logs it and runs on its
# defaults (see VALUE TYPES MATTER below). htop is ALSO in the system packages
# (modules/core/common.nix, base-configuration.nix), so it is still on PATH
# for root and on a bare TTY if home-manager activation itself has failed.
#
# THE CONFIG IS READ-ONLY - AND btop IS TOLD SO
#
# programs.btop writes ~/.config/btop/btop.conf as a symlink into the Nix
# store. btop's default is save_config_on_exit = True, which rewrites the whole
# file on every quit. Against a store symlink that write fails with EROFS and
# btop swallows it: no error, no log line, exit code 0. Verified on 1.4.7 with
# strace. Turning the save off means btop never tries.
#
# The consequence: changes made in btop's own options menu (o or F2) apply
# for the rest of that session only, and are gone on the next start. Change
# settings here instead. After a rebuild, `pkill -USR2 -x btop` makes a running
# btop - the dashboard pane, say - re-read the file without a restart.
#
# VALUE TYPES MATTER
#
# The module renders Nix bools as True/False, ints bare and strings quoted.
# btop rejects a quoted value for an int or bool key ("2000", "True"), logs a
# WARNING to ~/.local/state/btop.log and quietly keeps the default. So
# update_ms and friends must be Nix ints, and flags must be Nix bools. A
# misspelled key is ignored silently too.
#
# Spelling matters as much as type. The enum-like strings are case-sensitive
# and several are not validated when the file loads, so a wrong spelling is
# silent: "Celsius" shows every temperature as 0, "Range" never matches a
# frequency mode, "Gotham" falls back to the Default theme. Others ("debug",
# "Block", "on") are rejected with a log WARNING and fall back to the default.
# Copy the exact spellings used below.
#
# GPU BOX
#
# btop 1.4.7 is built with GPU support, but it has nothing to show on this
# Intel laptop. Intel iGPU stats come from system-wide perf events, which
# need CAP_PERFMON or kernel.perf_event_paranoid <= 0; this system has 2.
# So btop logs "Intel GPU: Failed to initialize PMU" once per start and draws
# no GPU box. That is deliberate: the box would only add utilisation, clock
# and power, which is not worth a capability grant on a hardened machine.
# (Do not add gpu0 to shown_boxes either: with no GPU detected, btop resets
# the whole list to "cpu mem net proc".)

let
  # ── Disks ──────────────────────────────────────────────────────────────
  #
  # Every host here keeps its OS on one LUKS btrfs pool split into subvolumes
  # (/, /nix, /.snapshots, /var/log, and /home on the laptops). btop lists each
  # subvolume as a separate disk, and because they share the pool they all
  # show the same size, the same free space and the same dm-0 IO: five
  # identical bars.
  #
  # Rather than hard-code a list per host, hide every mount that sits on the
  # same device as /. Derived from the NixOS fileSystems, so it stays right:
  #
  #   laptop-intel, framework   exclude=/.snapshots /home /nix /var/log
  #   devtower                  exclude=/.snapshots /nix /var/log
  #                             (/home is its own SSD there, so it stays)
  #
  # /boot is a separate vfat partition everywhere, so it is always shown.
  # /nix/store, tmpfs and docker overlays never show up, because btop only
  # lists mounts that are also in /etc/fstab (use_fstab, on by default).
  fileSystems = if osConfig != null then osConfig.fileSystems else { };
  rootDevice = (fileSystems."/" or { device = null; }).device;
  subvolumesOfRoot = lib.mapAttrsToList (_: fs: fs.mountPoint) (
    lib.filterAttrs (
      _: fs: rootDevice != null && fs.mountPoint != "/" && fs.device == rootDevice
    ) fileSystems
  );

  # ── Network interface ─────────────────────────────────────────────────
  #
  # btop's automatic choice is whichever running interface has moved the
  # most bytes since boot. Browsers here go through the local Squid proxy
  # (127.0.0.1:3128), so every page is counted twice on loopback and `lo`
  # overtakes the Wi-Fi card: the net box ends up graphing proxy traffic.
  # Pin the real interface per host. btop only uses net_iface when that
  # interface exists and falls back to the automatic choice otherwise, so a
  # stale name here degrades gracefully. Add framework and devtower once their
  # interface names are known (`ip -br link`).
  netIfaceByHost = {
    laptop-intel = "wlp6s0";
  };
  # "" rather than null: `set.${null}` is an evaluation error even with `or`.
  hostName = if osConfig != null then osConfig.networking.hostName else "";
  netIface = netIfaceByHost.${hostName} or null;

  # Also used to scale the IO graph ceilings below.
  updateMs = 1000;

  # ── IO graph ceilings ─────────────────────────────────────────────────
  #
  # io_graph_speeds sets the top of each disk's read/write graph, per
  # mountpoint. It is a fixed ceiling: IO above it draws as a flat full-height
  # graph (the ▲/▼ figures still show the real rate), and it never rescales.
  # A mountpoint with no entry gets 100. Only mountpoints btop actually lists
  # count, so the subvolumes hidden by disks_filter need no entry: "/" is the
  # whole LUKS pool, /home and /nix included. Swap never gets IO graphs.
  #
  # The graphs only appear in IO mode: press `i` in the mem box (io_mode is
  # off below, and the toggle lasts for the session). With it off the disks
  # show a one-row busy-time graph instead, which these values do not affect.
  #
  # Two btop 1.4.7 quirks, both handled by ioGraphEntry:
  #
  #   - The value is MiB per SAMPLE, not per second: btop does not divide by
  #     the update interval. The table below is in MiB/s and is scaled by
  #     updateMs, so changing update_ms does not silently move the ceilings.
  #   - btop computes `value << 20` in a 32-bit int (btop_draw.cpp:1278), so
  #     2048 or more wraps negative and the graph sits at 100% for any IO at
  #     all. Anything outside 1-2047 per sample fails the build instead.
  #
  # Rough starting points when filling in the other hosts (lsblk -o
  # NAME,MODEL,TRAN,ROTA,SIZE): NVMe 1000-2000, SATA SSD 500, HDD 200,
  # ESP /boot 100. Lower is more detail for everyday IO, higher clips less.
  ioGraphSpeedsByHost = {
    # Samsung 970 EVO Plus 1TB, PCIe 3.0 x4, behind LUKS2 aes-xts. Sequential
    # reads through LUKS measured ~2.3 GiB/s, but a ceiling that high flattens
    # everyday IO into the bottom row. At 1000, builds and rebuilds (tens to
    # hundreds of MiB/s) show as proper waves and only big copies clip.
    laptop-intel = {
      "/" = 1000;
      "/boot" = 100; # only kernel + initrd writes on a rebuild, ~60 MB
    };
    # framework = { "/" = …; "/boot" = 100; };  # one NVMe, model TBD
    # devtower  = { "/" = …; "/home" = …; "/boot" = 100; };  # /home is its own SSD
  };
  ioGraphEntry =
    mount: mibPerSecond:
    let
      perSample = mibPerSecond * updateMs / 1000;
    in
    assert lib.assertMsg (perSample >= 1 && perSample <= 2047)
      "system-monitor.nix: io_graph_speeds for ${mount} works out at ${toString perSample} MiB per sample; btop 1.4.7 only handles 1-2047";
    "${mount}:${toString perSample}";
  ioGraphSpeeds = lib.mapAttrsToList ioGraphEntry (ioGraphSpeedsByHost.${hostName} or { });
in
{
  programs.btop = {
    enable = true; # also installs pkgs.btop, so it is not in home.packages

    # Grouped and ordered exactly as btop's options menu (o) lists them, so the
    # two can be read side by side. Values that match btop's defaults are still
    # written out: each one was chosen, and pinning it keeps the behaviour
    # fixed if a btop upgrade changes a default. The per-host values
    # (disks_filter, net_iface, io_graph_speeds) are merged in at the end.
    settings = {
      # ── General ─────────────────────────────────────────────────────────
      color_theme = "gotham"; # bundled with btop (share/btop/themes)
      theme_background = true; # paint gotham's #2E3440, not kitty's background
      truecolor = true;
      force_tty = false;
      vim_keys = false; # on: h/l cycle the sort column, help and kill move to H/K
      disable_mouse = false;
      disable_presets = "Off";
      # presets and shown_boxes: btop's defaults. The default boxes need 80x24;
      # the workspace 1 pane is 84x40.
      update_ms = updateMs;
      rounded_corners = true;
      terminal_sync = true;
      graph_symbol = "block";
      # clock_format: btop's default, "%X" (the locale's time).
      base_10_sizes = true; # KB/MB (powers of 1000), not KiB/MiB
      background_update = true;
      show_battery = true;
      selected_battery = "Auto";
      show_battery_watts = true;
      log_level = "DEBUG"; # ~/.local/state/btop.log: start-up lines only, rotates at 1 MB
      save_config_on_exit = false; # see THE CONFIG IS READ-ONLY above

      # ── CPU ─────────────────────────────────────────────────────────────
      cpu_bottom = false;
      graph_symbol_cpu = "block";
      cpu_graph_upper = "Auto";
      cpu_graph_lower = "Auto"; # unused while cpu_single_graph is on
      cpu_invert_lower = true; # likewise
      cpu_single_graph = true;
      show_gpu_info = "On"; # nothing to show on laptop-intel (see GPU BOX above)
      check_temp = true;
      cpu_sensor = "Auto"; # resolves to coretemp's "Package id 0"
      show_coretemp = true;
      # cpu_core_map stays empty. It overrides which temperature sensor each
      # CPU row shows, for chips where btop pairs them wrongly. The i5-10210U
      # has 8 threads but 4 core sensors, and btop pairs them from the core ids
      # in /proc/cpuinfo: cpu0 and cpu4 -> Core 0, cpu1 and cpu5 -> Core 1, and
      # so on. Checked by pinning a busy loop to each CPU in turn: the matching
      # Core sensor rose every time. Writing "4:0 5:1 6:2 7:3" out by hand would
      # change nothing, and would be one more value to go stale.
      temp_scale = "celsius";
      show_cpu_freq = true;
      freq_mode = "range";
      # custom_cpu_name: none, btop shows the real model name.
      show_uptime = true;
      show_cpu_watts = true; # RAPL is root-only here, so btop hides it; harmless

      # ── GPU ─────────────────────────────────────────────────────────────
      # Left at btop's defaults: laptop-intel has no GPU box (see GPU BOX
      # above). Set these per host once framework and devtower are running.

      # ── Mem ─────────────────────────────────────────────────────────────
      mem_below_net = false;
      graph_symbol_mem = "block";
      mem_graphs = true;
      show_disks = true;
      show_io_stat = true;
      io_mode = false; # `i` in the mem box toggles it for the session
      io_graph_combined = false;
      # io_graph_speeds: per host, see "IO graph ceilings" above.
      show_swap = true;
      swap_disk = true;
      only_physical = false; # no effect while use_fstab is on
      use_fstab = true;
      zfs_hide_datasets = true; # no ZFS yet; for the devtower media pool / NAS
      # disk_free_priv: btop's default (off).
      # disks_filter: per host, see "Disks" above.
      zfs_arc_cached = true;

      # ── Net ─────────────────────────────────────────────────────────────
      graph_symbol_net = "block";
      swap_upload_download = true;
      net_download = 100; # Mbit/s graph scale, only used when net_auto is off
      net_upload = 100;
      net_auto = true;
      net_sync = true;
      # net_iface: per host, see "Network interface" above.
      base_10_bitrate = "Auto"; # follows base_10_sizes: Kbps/Mbps

      # ── Proc ────────────────────────────────────────────────────────────
      proc_left = false;
      graph_symbol_proc = "block";
      proc_sorting = "pid"; # descending, so the newest processes are on top
      proc_reversed = false;
      proc_tree = false;
      proc_aggregate = false; # tree view only
      proc_colors = true;
      proc_gradient = true;
      proc_per_core = false;
      proc_mem_bytes = true;
      keep_dead_proc_usage = true;
      proc_cpu_graphs = true;
      proc_filter_kernel = false;
      proc_follow_detailed = true;
    }
    // lib.optionalAttrs (subvolumesOfRoot != [ ]) {
      # "exclude=" on the first token turns the list into a deny-list.
      # Mountpoints are matched exactly and separated by spaces.
      disks_filter = "exclude=" + lib.concatStringsSep " " subvolumesOfRoot;
    }
    // lib.optionalAttrs (netIface != null) {
      net_iface = netIface;
    }
    // lib.optionalAttrs (ioGraphSpeeds != [ ]) {
      io_graph_speeds = lib.concatStringsSep " " ioGraphSpeeds;
    };
  };

  home.packages = [ pkgs.htop ];
}
