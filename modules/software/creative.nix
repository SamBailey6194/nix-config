{ config, pkgs, ... }:

{
  # Professional creative software suite
  # Video editing, graphic design, photo editing
  # Requires dedicated GPU (AMD Radeon recommended)

  environment.systemPackages = with pkgs; [
    # Video Editing
    davinci-resolve-studio   # Professional video editing (requires AMD GPU)
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

  # Note: Affinity Apps (Designer, Photo, Publisher) are enabled via
  # programs.affinity in base-configuration.nix, so all devices get them.
  # They're listed here conceptually as part of the creative suite.

  # GPU requirements note
  # DaVinci Resolve Studio requires:
  # - AMD Radeon GPU (recommended)
  # - OR NVIDIA GPU with proprietary drivers
  # - Intel integrated graphics NOT supported for DaVinci
}
