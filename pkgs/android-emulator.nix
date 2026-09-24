# `android-emulator`: boot a virtual Pixel and sideload APKs into it, for testing
# an app without putting it on a real phone.
#
#     android-emulator                      boot it (first run creates the device)
#     android-emulator app.apk [more.apk]   boot it if needed, then install them
#     android-emulator --wipe               factory-reset the device, then boot
#     android-emulator -- -no-window        anything after -- goes to `emulator`
#
# It returns once Android has finished booting, so `adb install`, `adb logcat`
# and friends work straight after. The emulator keeps running in its own window;
# close the window to shut it down. Closing saves a quick-boot snapshot (the
# window lingers ~20s while it writes), which is what makes the next start take
# seconds rather than a full boot.
#
# ── What it emulates ─────────────────────────────────────────────────────────
#
# One device: the Pixel 8 Pro hardware profile on Android 17 (API 37.0), the same
# Android level as the real Pixel 8 Pro. The image is the Google Play variant
# because Play services are what FCM push and Google sign-in run on, so a plain
# AOSP image would hide exactly the failures worth catching. x86_64 so KVM runs
# it at native speed.
#
# This is deliberately one device. Testing on a second Android version means a
# second image (~2GB each; the keys under `images` in nixpkgs'
# pkgs/development/mobile/androidenv/repo.json are what exists) and a second
# AVD name — parameterise `apiLevel`/`avd` rather than growing this script.
#
# ── SDK: pinned by Nix, not downloaded ───────────────────────────────────────
#
# Google's sdkmanager downloads unpatched binaries that do not run on NixOS, so
# the SDK comes from nixpkgs' androidenv instead: emulator, platform-tools,
# cmdline-tools (avdmanager) and the one system image, and nothing else — no
# build-tools, CMake or NDK, because this is for running APKs, not building
# them. androidenv refuses to evaluate until the SDK licence is accepted, which
# modules/software/development.nix does via nixpkgs.config.
#
# The AVD itself is mutable state, so it lives in the normal place,
# ~/.android/avd/pixel-8-pro.avd, and survives rebuilds. Its config.ini names
# the system image relative to the SDK root (image.sysdir.1 =
# system-images/android-37.0/...), and this script points ANDROID_HOME at the
# current store SDK, so after a `nix flake update` brings a newer image the
# device picks it up on its own; expect one cold boot while the quick-boot
# snapshot is invalidated. If the device ever gets into a bad state, `--wipe`.
{
  androidenv,
  android-tools,
  coreutils,
  gnugrep,
  gnused,
  util-linux,
  writeShellApplication,
}:

let
  apiLevel = "37.0";
  imageType = "google_apis_playstore";
  abi = "x86_64";

  sdk =
    (androidenv.composeAndroidPackages {
      platformVersions = [ apiLevel ];
      includeEmulator = true;
      includeSystemImages = true;
      systemImageTypes = [ imageType ];
      abiVersions = [ abi ];
      buildToolsVersions = [ ];
      includeCmake = false;
    }).androidsdk;
in

writeShellApplication {
  name = "android-emulator";

  # adb from android-tools, not the SDK's platform-tools, so this script and the
  # `adb` on PATH talk to the adb server as the same client version.
  runtimeInputs = [
    android-tools
    coreutils
    gnugrep
    gnused
    util-linux # setsid
  ];

  runtimeEnv = {
    ANDROID_HOME = "${sdk}/libexec/android-sdk";
    ANDROID_SDK_ROOT = "${sdk}/libexec/android-sdk";
    # The emulator bundles its own Qt with no Wayland plugin — platforms/ holds
    # xcb, offscreen, minimal, linuxfb and vnc only — and the Hyprland session
    # exports QT_QPA_PLATFORM=wayland, which it would fail on. xcb runs it
    # under XWayland.
    QT_QPA_PLATFORM = "xcb";
    # On close the emulator saves a quick-boot snapshot (the guest's whole RAM,
    # ~3.7GB at hw.ramSize 4096) and force-kills itself if that takes over 20s.
    # On laptop-intel the save measured 20.0s ("Saving snapshot 'default_boot'
    # using 20013 ms"), so at the default it was cut off every time: ram.bin
    # landed but snapshot.pb did not, the next start logged "Device 'cache'
    # does not have the requested snapshot" and cold-booted in ~75s. With the
    # save allowed to finish, the next start was booted in 18s.
    ANDROID_EMULATOR_WAIT_TIME_BEFORE_KILL = "120";
  };

  text = ''
    avd=pixel-8-pro
    image="system-images;android-${apiLevel};${imageType};${abi}"
    port=5554
    serial="emulator-$port"
    emulator="$ANDROID_HOME/emulator/emulator"
    avdmanager="${sdk}/bin/avdmanager"

    usage() {
      cat <<'EOF'
    Usage:
      android-emulator                      boot the virtual Pixel 8 Pro
      android-emulator app.apk [more.apk]   boot it if needed, then install them
      android-emulator --wipe               factory-reset the device, then boot
      android-emulator -- <emulator flags>  pass flags through to `emulator`
    EOF
    }

    wipe=0
    apks=()
    emulator_flags=()
    while [ $# -gt 0 ]; do
      case "$1" in
        -h | --help) usage; exit 0 ;;
        --wipe) wipe=1 ;;
        --) shift; emulator_flags=("$@"); break ;;
        -*) echo "android-emulator: unknown option $1" >&2; usage >&2; exit 2 ;;
        *)
          if [ ! -f "$1" ]; then
            echo "android-emulator: no such file: $1" >&2
            exit 2
          fi
          apks+=("$1")
          ;;
      esac
      shift
    done

    # Set a key in the AVD's config.ini, replacing it if avdmanager wrote one.
    set_config() {
      local file="$1" key="$2" value="$3"
      if grep -q "^$key *=" "$file"; then
        sed -i "s|^$key *=.*|$key=$value|" "$file"
      else
        echo "$key=$value" >>"$file"
      fi
    }

    booted() {
      [ "$(adb -s "$serial" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ]
    }

    log_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/android-emulator"
    log="$log_dir/emulator.log"
    pid=""

    adb start-server >/dev/null 2>&1

    if adb devices | grep -q "^''${serial}[[:space:]]"; then
      if [ "$wipe" = 1 ] || [ ''${#emulator_flags[@]} -gt 0 ]; then
        echo "android-emulator: $serial is already running; close it first to use --wipe or emulator flags" >&2
        exit 1
      fi
      echo "Emulator already running as $serial." >&2
    else
      if ! "$emulator" -list-avds 2>/dev/null | grep -qx "$avd"; then
        echo "Creating the $avd virtual device (first run only)..." >&2
        # `echo no` answers "create a custom hardware profile?". Not `yes ""`:
        # under pipefail its SIGPIPE on exit would fail the whole pipeline.
        # Output is only shown on failure: a successful run still prints
        # "Could not load devices from .../devices.xml", because Google's newer
        # system images no longer ship that file and avdmanager looks anyway.
        if ! out=$(echo no | "$avdmanager" create avd \
          --name "$avd" --package "$image" --device pixel_8_pro 2>&1); then
          echo "$out" >&2
          exit 1
        fi
      fi

      # Applied on every launch, not just at creation, so a change here reaches
      # a device that already exists.
      config="''${ANDROID_AVD_HOME:-''${ANDROID_USER_HOME:-$HOME/.android}/avd}/$avd.avd/config.ini"
      # Sized for the smallest host (laptop-intel: 4 cores / 8 threads, 32GB).
      set_config "$config" hw.cpu.ncore 4
      set_config "$config" hw.ramSize 4096
      # Host GPU, forced. `auto` checks the host driver against the emulator's
      # blocklist and, on this laptop's Mesa Intel driver, logs "Your GPU drivers
      # may have a bug" and falls back to SwiftShader + lavapipe — software
      # rendering that left the first boot at ~5 minutes with the launcher
      # ANRing. `host` runs fine on it (Mesa, Intel UHD, Vulkan 1.4). If a host
      # ever misrenders, override per run: android-emulator -- -gpu swiftshader_indirect
      set_config "$config" hw.gpu.enabled yes
      set_config "$config" hw.gpu.mode host
      # Let the laptop keyboard type into the device.
      set_config "$config" hw.keyboard yes

      # The emulator finds the host timezone by looking for /usr/share/zoneinfo,
      # which NixOS does not have, so on its own the device boots on GMT. Hand
      # it the zone /etc/localtime resolves to instead.
      tz=$(readlink -f /etc/localtime 2>/dev/null | sed -n 's|.*/zoneinfo/||p' || true)
      if [ -n "$tz" ]; then
        emulator_flags=(-timezone "$tz" "''${emulator_flags[@]}")
      fi

      if [ "$wipe" = 1 ]; then
        emulator_flags+=(-wipe-data)
      fi

      mkdir -p "$log_dir"
      echo "Starting the emulator (log: $log)..." >&2
      # Its own session, so it outlives this script and the terminal it ran in.
      setsid "$emulator" -avd "$avd" -port "$port" "''${emulator_flags[@]}" \
        >"$log" 2>&1 </dev/null &
      pid=$!
    fi

    # Also when it was already running: it may have been started moments ago
    # (another terminal) and still be booting, and `adb install` fails until
    # the package manager is up. Returns at once if it has finished.
    #
    # Measured on laptop-intel: first boot (or the first after --wipe) 4m46s in
    # software rendering; cold boot with the host GPU ~75s; quick boot from the
    # snapshot 18s.
    if ! booted; then
      echo "Waiting for Android to finish booting..." >&2
      deadline=$((SECONDS + 600))
      until booted; do
        if [ -n "$pid" ] && ! kill -0 "$pid" 2>/dev/null; then
          echo "android-emulator: the emulator exited during boot. Last lines of $log:" >&2
          tail -n 30 "$log" >&2
          exit 1
        fi
        if [ "$SECONDS" -ge "$deadline" ]; then
          echo "android-emulator: not booted after 10 minutes; still running, see $log" >&2
          exit 1
        fi
        sleep 2
      done
    fi
    echo "Booted: $serial." >&2

    for apk in "''${apks[@]}"; do
      echo "Installing $apk..." >&2
      adb -s "$serial" install -r "$apk"
    done
  '';

  passthru = { inherit sdk; };
}
