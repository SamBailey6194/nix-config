{ pkgs, ... }:

let
  # nixpkgs' `inter` installs only InterVariable{,-Italic}.ttf, and those register
  # under the family name "Inter Variable" — nothing on the system answers to a
  # plain request for "Inter". XeTeX also cannot select a named instance out of a
  # variable font, so `\setmainfont{Inter}` would hand you Regular at every weight.
  # The upstream release archive (already in the store as `pkgs.inter.src`) ships
  # the static instances under extras/otf, so install those next to the variable
  # faces: apps that understand variable fonts keep using "Inter Variable", while
  # "Inter" / "Inter Display" resolve to real per-weight files.
  # NOTE: this reaches into pkgs.inter.src's layout — if a nixpkgs bump changes it
  # from the release zip to a plain git checkout, this build fails loudly.
  inter-static = pkgs.runCommand "inter-static-${pkgs.inter.version}" { } ''
    install -Dm444 -t "$out/share/fonts/opentype" ${pkgs.inter.src}/extras/otf/*.otf
  '';

  # Segoe UI is proprietary and only licensed alongside Windows, so it can't be
  # installed here. Selawik is Microsoft's own OFL-licensed stand-in for it:
  # metric-compatible, so layouts designed for Segoe UI keep their line breaks.
  # Five upright weights (Light, Semilight, Regular, Semibold, Bold), no italics.
  # The fontconfig aliases below make requests for "Segoe UI" resolve to it.
  selawik = pkgs.stdenvNoCC.mkDerivation rec {
    pname = "selawik";
    version = "1.01";
    src = pkgs.fetchzip {
      url = "https://github.com/microsoft/Selawik/releases/download/${version}/Selawik_Release.zip";
      stripRoot = false;
      hash = "sha256-BbjXJ8HFXrRklMOnGXyZIZeQ5Oksda4AqQXHmNqN6AQ=";
    };
    installPhase = ''
      install -Dm444 -t "$out/share/fonts/truetype" *.ttf
    '';
    meta.license = pkgs.lib.licenses.ofl;
  };
in
{
  # Font configuration shared across all systems
  # Similar to Ubuntu Sans Mono with modern alternatives

  fonts = {
    # Enable font directory
    fontDir.enable = true;

    # Install system fonts
    packages = with pkgs; [
      # Primary monospace fonts (similar to Ubuntu Sans Mono)
      jetbrains-mono       # Modern, excellent readability, ligatures
      fira-code            # Clean design, programming ligatures
      cascadia-code        # Microsoft's developer font
      ibm-plex             # IBM's professional font family

      # Classic monospace fallbacks
      dejavu_fonts         # DejaVu Sans Mono
      liberation_ttf       # Liberation Mono
      source-code-pro      # Adobe's monospace font

      # Sans-serif fonts
      noto-fonts                # Google's Noto family
      noto-fonts-color-emoji    # Emoji support (renamed from noto-fonts-emoji)
      ubuntu-classic       # Ubuntu fonts (includes Ubuntu Mono)

      # Design / document sans-serifs — all weights (100-900) plus italics, as
      # static per-weight files so fontspec (XeLaTeX) and Affinity can address
      # each weight by name, not just the variable default instance.
      inter                # variable faces, family "Inter Variable"
      inter-static         # static faces, families "Inter" + "Inter Display"
      montserrat           # Thin..Black + italics (otf/ttf)
      poppins              # Thin..Black + italics (ttf, plus "Poppins Latin")
      selawik              # open Segoe UI substitute, aliased as "Segoe UI"

      # Icon fonts (for terminal prompts and UI)
      nerd-fonts.fira-code
      nerd-fonts.jetbrains-mono
      font-awesome
    ];

    # Font configuration
    fontconfig = {
      enable = true;
      defaultFonts = {
        monospace = [ "Ubuntu Sans Mono" "Ubuntu Mono" "JetBrains Mono" "DejaVu Sans Mono" ];
        sansSerif = [ "Ubuntu" "Noto Sans" "DejaVu Sans" ];
        serif = [ "Noto Serif" "DejaVu Serif" ];
        emoji = [ "Noto Color Emoji" ];
      };

      # Several upstream font packages (jetbrains-mono, montserrat, ...) ship
      # web fonts alongside the desktop ones, and fontconfig happily indexes
      # them. When a .woff2 wins the match, XeLaTeX resolves the family fine but
      # xdvipdfmx then dies with "Cannot proceed without the font: ....woff2"
      # because it cannot embed a compressed web font. Nothing on a desktop
      # wants woff/woff2 from fontconfig, so drop them from the font set.
      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
        <fontconfig>
          <selectfont>
            <rejectfont>
              <glob>*.woff</glob>
              <glob>*.woff2</glob>
            </rejectfont>
          </selectfont>

          <!-- Segoe UI is not installable (see selawik above); hand its
               family names to Selawik's matching weights instead. -->
          <alias binding="same">
            <family>Segoe UI</family>
            <prefer><family>Selawik</family></prefer>
          </alias>
          <alias binding="same">
            <family>Segoe UI Light</family>
            <prefer><family>Selawik Light</family></prefer>
          </alias>
          <alias binding="same">
            <family>Segoe UI Semilight</family>
            <prefer><family>Selawik Semilight</family></prefer>
          </alias>
          <alias binding="same">
            <family>Segoe UI Semibold</family>
            <prefer><family>Selawik Semibold</family></prefer>
          </alias>
        </fontconfig>
      '';
    };
  };
}
