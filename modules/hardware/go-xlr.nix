{ config, pkgs, ... }:

{
  # Go XLR audio interface support
  # For: devtower only

  environment.systemPackages = with pkgs; [
    goxlr-utility # Go XLR control software
  ];

  # USB permissions for Go XLR
  services.udev.extraRules = ''
    # TC-Helicon GoXLR
    SUBSYSTEM=="usb", ATTR{idVendor}=="1220", ATTR{idProduct}=="8fe4", MODE="0666"
    SUBSYSTEM=="usb", ATTR{idVendor}=="1220", ATTR{idProduct}=="8fe0", MODE="0666"

    # GoXLR Mini
    SUBSYSTEM=="usb", ATTR{idVendor}=="1220", ATTR{idProduct}=="8fe1", MODE="0666"
  '';

  # Professional audio configuration
  services.pipewire.extraConfig.pipewire = {
    "context.properties" = {
      "default.clock.rate" = 48000;
      "default.clock.quantum" = 256;
      "default.clock.min-quantum" = 128;
    };
  };
}
