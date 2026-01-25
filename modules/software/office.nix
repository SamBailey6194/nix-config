{ config, pkgs, ... }:

{
  # Office and productivity software
  # Document editing, spreadsheets, presentations

  environment.systemPackages = with pkgs; [
    # Office suite
    libreoffice-fresh        # LibreOffice (Writer, Calc, Impress)
    # onlyoffice-bin          # ONLY Office (MS Office compatible)

    # PDF tools
    # pdftk                   # PDF toolkit
    qpdf                    # PDF manipulation
    # poppler_utils           # PDF utilities (pdfinfo, pdftotext, etc.)

    # Markdown editors
    # marktext                # Markdown editor
    # typora                  # Commercial markdown editor

    # Diagram tools
    # drawio                  # Diagram editor
    # dia                     # Diagram creation
  ];

  # LibreOffice configuration
  # Enable Java support for LibreOffice Base
  # programs.libreoffice = {
  #   enable = true;
  # };
}
