{ config, lib, pkgs, ... }:

{
  options.software.office.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Install LibreOffice and the PDF tools. laptop-intel turns this off: it is
      a thin client that runs office apps on devtower-intel.
    '';
  };

  config = lib.mkIf config.software.office.enable {
    environment.systemPackages = with pkgs; [
      libreoffice             # LibreOffice (Writer, Calc, Impress)
      qpdf                    # PDF manipulation
    ];
  };
}
