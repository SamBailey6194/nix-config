{ pkgs, ... }:

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
      noto-fonts           # Google's Noto family
      noto-fonts-emoji     # Emoji support
      ubuntu_font_family   # Ubuntu fonts (includes Ubuntu Mono)

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
    };
  };
}
