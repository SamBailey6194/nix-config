{ config, pkgs, ... }:

{
  # OpenRGB for controlling RGB peripherals and components
  # - Keyboards (HyperX Alloy Origins Core PBT)
  # - Mice
  # - Internal components (RAM, motherboard, fans, etc.)

  # Install OpenRGB package
  environment.systemPackages = with pkgs; [
    openrgb
  ];

  # Enable OpenRGB service for automatic detection
  services.hardware.openrgb = {
    enable = true;
    # Note: The server functionality is built-in to the main service
    # Start OpenRGB manually with --server flag if needed for remote control
  };

  # Udev rules for hardware access (required for USB devices)
  services.udev.packages = [ pkgs.openrgb ];

  # Add user to i2c group for SMBus access (motherboard RGB)
  # This is needed for internal components like RAM and motherboard
  users.groups.i2c = {};

  # Enable i2c-dev kernel module for SMBus RGB control
  boot.kernelModules = [ "i2c-dev" ];
}
