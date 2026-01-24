{ config, pkgs, lib, ... }:

{
  # Professional creative software suite
  # Video editing, graphic design, photo editing
  # Requires dedicated GPU (AMD Radeon recommended)

  environment.systemPackages = with pkgs; [
    # Video Editing
    davinci-resolve-studio   # Professional video editing (requires AMD GPU + Rusticl)
    # kdenlive                # Open-source video editor (lighter alternative)
    # shotcut                 # Another open-source video editor
    # openshot-qt             # Simple video editor

    # 3D Graphics & Animation
    blender                  # 3D creation suite

    # Audio Production (if doing video work)
    reaper                  # Digital audio workstation
    # lmms                    # Music production

    # Color grading tools (additional to DaVinci)
    # (DaVinci Resolve includes color grading)
  ];

  # DaVinci Resolve Studio: AMD GPU configuration with Rusticl (OpenCL via Mesa)
  # See: https://wiki.nixos.org/wiki/DaVinci_Resolve
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      mesa.opencl  # Enables Rusticl (OpenCL) support for AMD GPU
    ];
  };

  # Environment variables for DaVinci Resolve Studio
  environment.variables = {
    # Enable Rusticl (OpenCL) for AMD GPU support
    RUSTICL_ENABLE = "radeonsi";

    # OpenFX plugin path (plugins go in /run/current-system/sw/OFX/Plugins or user-specified)
    # OFX_PLUGIN_PATH = lib.concatStringsSep ";" [
    #   # Add OpenFX plugin packages here
    #   # Example: "${pkgs.some-ofx-plugin}"
    # ];
  };

  # IMPORTANT: DaVinci Resolve Studio cannot run on native Wayland (qtwayland version mismatch)
  # Must use XWayland or pure X11 session. Launch command:
  #   ROC_ENABLE_PRE_VEGA=1 RUSTICL_ENABLE=amdgpu,amdgpu-pro,radv,radeon,radeonsi DRI_PRIME=1 QT_QPA_PLATFORM=xcb davinci-resolve-studio
  #
  # For convenience, create a wrapper script in your home directory or add to shell aliases:
  #   alias resolve='ROC_ENABLE_PRE_VEGA=1 RUSTICL_ENABLE=amdgpu,amdgpu-pro,radv,radeon,radeonsi DRI_PRIME=1 QT_QPA_PLATFORM=xcb davinci-resolve-studio'

  # Note: Affinity Apps (Designer, Photo, Publisher) are enabled via
  # programs.affinity in base-configuration.nix, so all devices get them.
  # They're listed here conceptually as part of the creative suite.

  # GPU requirements for DaVinci Resolve Studio:
  # - AMD Radeon GPU with Rusticl/OpenCL support (recommended for NixOS)
  # - OR NVIDIA GPU with proprietary drivers + CUDA
  # - Intel integrated graphics NOT supported
}
