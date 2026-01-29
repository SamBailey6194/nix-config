**Last Updated**: 29/01/2026
**Version**: 0.7.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

  # How to carry Out Updates

**Last Updated**: 27/01/2026
**Version**: 0.1.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

  1. Edit Anywhere (Preferred)

  You can edit .nix files on any device or even in a web editor because:
  - NixOS configs are declarative text files
  - They're device-independent until you apply them
  - Git is your single source of truth

  2. Typical Workflow

  On your editing device (could be laptop-intel or even non-NixOS)
  cd ~/Repos/personal/nix-config
  vim modules/software/browsers.nix  # Make your changes
  git add .
  git commit -m "Add Brave browser"
  git push

  On the TARGET device (laptop-intel, framework, or devtower)
  cd /etc/nixos/nix-config  # or wherever you cloned it
  git pull
  sudo nixos-rebuild switch --flake .#laptop-intel  # Use appropriate device name

  3. Advanced Workflow (Test Before Committing)

  If you're editing on a NixOS device, you can test changes before committing:

  On laptop-intel (editing for laptop-intel)
  cd ~/Repos/personal/nix-config
  vim modules/software/browsers.nix

  Test the changes (doesn't modify bootloader - safe)
  sudo nixos-rebuild test --flake .#laptop-intel

  If it works, make it permanent
  sudo nixos-rebuild switch --flake .#laptop-intel

  Then commit
  git add .
  git commit -m "Add Brave browser"
  git push

  Per-Device Configuration

  The flake handles device-specific configs automatically:

  Each device uses its own target
  sudo nixos-rebuild switch --flake .#laptop-intel  # For laptop
  sudo nixos-rebuild switch --flake .#framework     # For framework
  sudo nixos-rebuild switch --flake .#devtower      # For devtower

  The same git commit applies to all devices - the flake target determines which configuration is used.

  Common Scenarios

  Scenario 1: Add Software to All Devices

  Edit once
  vim modules/software/browsers.nix  # Add Brave

  Commit once
  git commit -m "Add Brave to all devices"
  git push

  Apply to each device
  On laptop-intel:
  git pull && sudo nixos-rebuild switch --flake .#laptop-intel

  On framework:
  git pull && sudo nixos-rebuild switch --flake .#framework

  Scenario 2: Device-Specific Change

  Edit device-specific config
  vim hosts/laptop-intel/configuration-full.nix  # Add laptop-only package

  Commit
  git commit -m "Add laptop-specific tool"
  git push

  Only affects laptop-intel
  git pull && sudo nixos-rebuild switch --flake .#laptop-intel

  Scenario 3: Multi-Device Editing

  You can edit configs for ALL devices from ONE location
  vim hosts/laptop-intel/configuration-full.nix  # Laptop changes
  vim hosts/framework/configuration-full.nix     # Framework changes
  vim hosts/devtower/configuration-full.nix      # Devtower changes

  git commit -m "Update all three devices"
  git push

  Then apply to each device when ready

  Best Practices

  1. Edit → Commit → Pull → Rebuild (not Edit → Rebuild → Commit)
  2. Test with nixos-rebuild test before switch if uncertain
  3. Use meaningful commit messages (you can rollback using git)
  4. Keep flake.lock in git (ensures reproducible builds)
  5. Use branches for experimental changes:
  git checkout -b test-hyprland-config
  Make changes, test
  git checkout main  # Revert easily

  Rollback if Needed

  If a rebuild breaks something:

  NixOS keeps previous generations
  sudo nixos-rebuild switch --rollback

  Or at boot: select previous generation in bootloader

  Summary

  Edit anywhere → Commit to git → Pull on device → Rebuild on device

  This workflow gives you:
  - ✅ Version control for all changes
  - ✅ Easy rollback
  - ✅ Can edit from any device
  - ✅ Can manage multiple devices from one place
  - ✅ Review changes before applying
  - ✅ Separation of concerns (editing vs. applying)

  Your NixOS config is infrastructure-as-code - treat it like any other code repository! 🚀
