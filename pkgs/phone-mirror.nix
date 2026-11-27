# `phone-mirror`: scrcpy with somewhere sensible to put what it captures.
#
#     phone-mirror                   mirror and control the phone (workspace 42)
#     phone-mirror --record          the same, recording to <recordings>/<time>.mp4
#     phone-mirror --screenshot      save the phone's screen to <screenshots>/<time>.png
#     phone-mirror [...] -- <flags>  anything after -- goes to scrcpy
#
# scrcpy has no screenshot of its own and cannot start recording mid-session,
# so a screenshot is `adb exec-out screencap` (the phone's full resolution, not
# the window's) and a recording is a session started with --record. With more
# than one device attached (phone plus android-emulator), set ANDROID_SERIAL;
# adb and scrcpy both read it.
#
# Where files go is per host (modules/software/development.nix): the XDG
# Pictures/Videos folders on the SSD by default, or the data drive's layout on
# devtower-intel (docs/SHARED-DATA-DRIVES.md). With requireMount set, nothing
# is written unless that path is mounted: ~/Data without the drive behind it is
# an empty read-only folder, and a capture must not silently go elsewhere.
#
# Launched from a key there is no terminal, so outcomes go to notify-send too.
{
  android-tools,
  coreutils,
  libnotify,
  scrcpy,
  util-linux,
  writeShellApplication,
  # Shell expressions, expanded when the script runs ($HOME, $XDG_*).
  screenshotDir ? "\${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots/scrcpy",
  recordingDir ? "\${XDG_VIDEOS_DIR:-$HOME/Videos}/scrcpy",
  requireMount ? "",
}:

writeShellApplication {
  name = "phone-mirror";

  runtimeInputs = [
    android-tools
    coreutils
    libnotify
    scrcpy
    util-linux # mountpoint
  ];

  text = ''
    usage() {
      cat <<'EOF'
    Usage:
      phone-mirror                   mirror and control the phone
      phone-mirror --record          mirror, recording to an .mp4
      phone-mirror --screenshot      save the phone's screen as a .png
      phone-mirror [...] -- <flags>  pass flags through to scrcpy
    EOF
    }

    say() {
      echo "phone-mirror: $1" >&2
      notify-send --app-name=phone-mirror ''${2:+--urgency="$2"} "Phone" "$1" 2>/dev/null || true
    }

    fail() {
      say "$1" critical
      exit 1
    }

    mode=mirror
    while [ $# -gt 0 ]; do
      case "$1" in
        --record) mode=record; shift ;;
        --screenshot) mode=screenshot; shift ;;
        -h|--help) usage; exit 0 ;;
        --) shift; break ;;
        *) echo "phone-mirror: unknown option $1" >&2; usage >&2; exit 2 ;;
      esac
    done

    require_mount="${requireMount}"
    if [ "$mode" != mirror ] && [ -n "$require_mount" ] && ! mountpoint -q "$require_mount"; then
      fail "$require_mount is not mounted, so nothing was saved. Mount the data drive and try again."
    fi

    stamp=$(date +%Y-%m-%d_%H-%M-%S)

    case "$mode" in
      screenshot)
        dir="${screenshotDir}"
        mkdir -p "$dir" || fail "cannot create $dir"
        out="$dir/$stamp.png"
        tmp="$out.part"
        if ! adb exec-out screencap -p >"$tmp" 2>/dev/null || [ ! -s "$tmp" ]; then
          rm -f "$tmp"
          fail "screenshot failed: is one device attached (adb devices) with USB debugging allowed?"
        fi
        mv "$tmp" "$out"
        say "Screenshot saved to $out"
        ;;
      record)
        dir="${recordingDir}"
        mkdir -p "$dir" || fail "cannot create $dir"
        out="$dir/$stamp.mp4"
        say "Recording to $out (close the window to finish the file)"
        # MOD is left Alt only, so SUPER chords stay Hyprland's.
        scrcpy --shortcut-mod=lalt --window-title="Phone (recording)" --record="$out" "$@" \
          || fail "scrcpy exited with an error; see the terminal or adb devices"
        say "Recording saved to $out"
        ;;
      mirror)
        scrcpy --shortcut-mod=lalt --window-title=Phone "$@" \
          || fail "scrcpy exited with an error; see the terminal or adb devices"
        ;;
    esac
  '';
}
