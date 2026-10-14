# ArtCraft "Craft" apps (https://getartcraft.com/apps), packaged from the
# upstream Linux x86_64 AppImages published on GitHub (storytold/<app>).
#
# Returns an attrset of thirteen packages (use pkgs.callPackages, plural, so the
# result holds only derivations, each overridable):
#   photocraft vectorcraft lightcraft pdfcraft designcraft effectcraft filmcraft
#   soundcraft wordcraft deckcraft cadcraft figcraft gridcraft
#
# Versions, URLs and hashes live in ./sources.json; refresh them with
# `just update-craft` (scripts/update-craft-apps.py). Not packaged: ArtCraft
# itself (no Linux build) and craft-launcher.
#
# Each package wraps the AppImage with appimageTools.wrapType2 (an FHS env), so
# the binaries' dlopen()ed libraries (wgpu/winit: Vulkan, EGL, Wayland,
# xkbcommon, X11/xcb, D-Bus, ALSA) resolve from extraPkgs and the defaults.
# The upstream .desktop entry, hicolor icons, MIME type and AppStream metainfo
# are installed from the extracted AppImage. Wayland app_id is
# ai.storyteller.<app>, matching the .desktop file id, so docks pick up the
# icon; see modules/software/README.md for the window classes.
#
# Each AppImage also bundles a headless CLI (usr/bin/<app>-cli, e.g.
# photocraft-cli). It is exposed as $out/bin/<app>-cli: a copy of the GUI's
# bubblewrap launcher with only the /init entrypoint swapped, so it runs in the
# same FHS env (same rootfs, libraries and /etc/profile) from the same single
# extraction. Nothing here enables a control port: the GUI's --control flag and
# the CLIs' control-port/token variables are left to the user.
{
  lib,
  appimageTools,
  fetchurl,
  writeShellScript,
  sources ? lib.importJSON ./sources.json,
}:

let
  descriptions = {
    photocraft = "Photo editor for layered PSD documents";
    vectorcraft = "Vector illustration editor for SVG, PDF and AI files";
    lightcraft = "Photo library and non-destructive raw developer";
    pdfcraft = "PDF reader and editor: organise, combine, split and secure PDFs";
    designcraft = "Desktop publishing for magazines, books and print documents";
    effectcraft = "Motion graphics and visual effects compositor";
    filmcraft = "Video editor with colour grading and audio";
    soundcraft = "Audio and MIDI recording, editing and mixing";
    wordcraft = "Word processor and document designer with Word file support";
    deckcraft = "Slide deck editor and presenter";
    cadcraft = "Computer-aided design and drafting";
    figcraft = "Interface design and prototyping";
    gridcraft = "Spreadsheet editor";
  };

  mkCraftApp =
    pname: source:
    let
      inherit (source) version;
      src = fetchurl {
        inherit (source) url hash;
        name = "${pname}-${version}-linux-x86_64.AppImage";
      };
      # Same arguments as wrapType2's own extraction, so this is the same
      # derivation, not a second unpack.
      contents = appimageTools.extract { inherit pname version src; };
      desktopId = "ai.storyteller.${pname}";
      envPrefix = lib.toUpper pname;
      cliName = "${pname}-cli";
      # Entrypoint for the CLI launcher, mirroring what the GUI's init does
      # (source the FHS /etc/profile, then appimage-exec.sh -w, which exports
      # APPDIR) but exec'ing the CLI instead of AppRun.
      cliInit = writeShellScript "${pname}-${version}-cli-init" ''
        source /etc/profile
        export APPDIR=${contents}
        exec ${contents}/usr/bin/${cliName} "$@"
      '';
    in
    appimageTools.wrapType2 {
      inherit pname version src;

      # Libraries the binaries dlopen() (found with strings/readelf on the
      # extracted ELF files). Most are already in appimageTools' default FHS
      # set; listing them keeps the dependency explicit if that set shrinks.
      extraPkgs =
        pkgs: with pkgs; [
          vulkan-loader # libvulkan.so.1 (wgpu)
          libGL # libEGL.so.1 (wgpu GL fallback)
          wayland # libwayland-client.so, libwayland-egl.so
          libxkbcommon # libxkbcommon.so, libxkbcommon-x11.so
          libx11 # libX11.so, libX11-xcb.so (Xwayland / X11 path)
          libxcursor
          libxi
          libxrandr
          libxcb
          dbus # libdbus-1.so.3 (portals: file chooser, settings)
          fontconfig
          freetype
          alsa-lib # libasound.so.2 (effectcraft, filmcraft, soundcraft, deckcraft)
          libva # libva.so.2, libva-drm.so.2 (filmcraft hardware decode)
          pipewire
        ];

      # Never let an AppRun/binary "self-integrate" into ~/.local/share: Nix
      # installs the desktop entry and icons itself. The wrapper does not set
      # $APPIMAGE, which is what the integration keys on; this is belt and braces.
      profile = ''
        unset APPIMAGE
        export ${envPrefix}_NO_DESKTOP_INTEGRATION=1
      '';

      extraInstallCommands = ''
        # Headless CLI, only when the AppImage ships one (never invented). The
        # GUI launcher symlinks its init script to /init inside the sandbox;
        # the CLI launcher is the same script pointing /init at cliInit.
        if [ -x ${contents}/usr/bin/${cliName} ]; then
          init_re='--symlink /nix/store/[a-z0-9]\{32\}-${pname}-${version}-init /init'
          if [ "$(grep -c -e "$init_re" $out/bin/${pname})" != 1 ]; then
            echo "craft-apps: cannot find the /init symlink in the ${pname} launcher" >&2
            exit 1
          fi
          sed -e "s|$init_re|--symlink ${cliInit} /init|" $out/bin/${pname} > $out/bin/${cliName}
          chmod 555 $out/bin/${cliName}
        fi

        install -Dm444 ${contents}/usr/share/applications/${desktopId}.desktop \
          $out/share/applications/${desktopId}.desktop
        # Point Exec/TryExec at the wrapped binary ($out/bin/${pname}); keep the
        # field codes (%F/%U) and StartupWMClass as shipped.
        sed -i \
          -e 's|^Exec=[^ ]*|Exec=${pname}|' \
          -e 's|^TryExec=.*|TryExec=${pname}|' \
          -e '/^X-AppImage-/d' \
          $out/share/applications/${desktopId}.desktop

        mkdir -p $out/share
        cp -r ${contents}/usr/share/icons $out/share/icons
        if [ -d ${contents}/usr/share/mime ]; then
          cp -r ${contents}/usr/share/mime $out/share/mime
        fi
        if [ -d ${contents}/usr/share/metainfo ]; then
          cp -r ${contents}/usr/share/metainfo $out/share/metainfo
        fi
        chmod -R u+w $out/share
      '';

      passthru = {
        inherit contents desktopId;
        appId = desktopId;
      };

      meta = {
        description = descriptions.${pname} or "ArtCraft ${pname}";
        homepage = "https://getartcraft.com/apps/${pname}";
        downloadPage = "https://github.com/storytold/${pname}/releases";
        changelog = "https://github.com/storytold/${pname}/releases/tag/v${version}";
        # The GitHub repos are Apache-2.0; the AppStream metainfo declares
        # "MIT OR Apache-2.0".
        license = with lib.licenses; [
          asl20
          mit
        ];
        platforms = [ "x86_64-linux" ];
        mainProgram = pname;
        sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      };
    };
in
lib.mapAttrs mkCraftApp sources
