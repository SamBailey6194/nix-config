{ runCommand, resvg, jetbrains-mono }:

# Renders config/refind/icons (SVG) to the PNGs rEFInd needs. rEFInd reads
# PNG, BMP, JPEG and ICNS only, so the SVGs stay the editable source.
#
# os_nixos is left as SVG: its build badge (flake commit + generation) is
# filled in and rendered by the boot loader installer at switch time, because
# the generation number does not exist until then.
runCommand "refind-theme" {
  src = ../config/refind/icons;
  nativeBuildInputs = [ resvg ];
  passthru.fontDir = "${jetbrains-mono}/share/fonts";
  meta.description = "Themed rEFInd icons, selection halos and background";
} ''
  mkdir -p $out/icons
  render() { resvg --skip-system-fonts --use-fonts-dir ${jetbrains-mono}/share/fonts "$@"; }

  # Big OS icons at 256px, tool icons at 96px (big_icon_size/small_icon_size)
  render -w 256 -h 256 $src/os_win.svg $out/icons/os_win.png
  for icon in func_shutdown func_reset func_firmware func_about tool_shell; do
    render -w 96 -h 96 $src/$icon.svg $out/icons/$icon.png
  done

  # rEFInd's optimal selection sizes are 144 (big) and 64 (small) for its
  # default 128/48 icons; keep the same ratio for 256/96.
  render -w 288 -h 288 $src/selection_big.svg $out/selection_big.png
  render -w 128 -h 128 $src/selection_small.svg $out/selection_small.png
  render -w 2560 -h 1440 $src/background.svg $out/background.png

  cp $src/os_nixos.svg $out/os_nixos.svg
''
