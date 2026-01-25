# Software Modules Organization

This directory contains purpose-specific software modules that can be mixed and matched across devices.

## Module Overview

| Module | Purpose | Key Packages | Imported By |
|--------|---------|--------------|-------------|
| `browsers.nix` | Web browsers | LibreWolf, Firefox, Chrome | base-configuration |
| `communication.nix` | Chat & collaboration | Discord, Teams, Zoom, Slack, Obsidian | base-configuration |
| `media.nix` | Media playback | VLC, Spotify, MPV, image viewers | base-configuration |
| `development.nix` | Dev tools & IDEs | VS Code, Docker, language servers | base-configuration |
| `office.nix` | Office productivity | LibreOffice, PDF tools | base-configuration |
| `creative.nix` | Creative suite | DaVinci Resolve, Blender, Reaper | Framework & DevTower only |

## Currently Installed on All Devices

These modules are imported in `modules/core/base-configuration.nix` and available on **all** devices:

- **Browsers**: LibreWolf (privacy), Firefox (dev testing), Chrome (Claude extension)
- **Communication**: Discord, Microsoft Teams, Zoom, Slack, Obsidian
- **Media**: VLC, Spotify, Audacity, image/PDF viewers
- **Development**: VS Code, Docker, Git, language servers, Python, Node.js
- **Office**: LibreOffice suite

## Creative Suite (GPU Required)

The `creative.nix` module is **only imported on devices with dedicated AMD GPUs**:

- **Framework** (AMD Radeon)
- **DevTower** (AMD Radeon + Go XLR)

**NOT on**:
- **laptop-intel** (Intel UHD integrated graphics - not powerful enough)

### Creative Software Included

- **Video Editing**: DaVinci Resolve Studio (requires AMD GPU)
- **3D Graphics**: Blender
- **Audio Production**: Reaper DAW
- **Affinity Apps**: Designer, Photo, Publisher (via `programs.affinity` - ALL devices)

## How to Add/Remove Software

### Add to All Devices

Edit the appropriate module in `modules/software/` and it will apply to all devices on next rebuild.

Example - Add Telegram to all devices:
```nix
# modules/software/communication.nix
telegram-desktop   # Uncomment or add this line
```

### Add to Specific Devices Only

Import the module in the device's `hosts/{device}/configuration.nix`:

```nix
# hosts/laptop-intel/configuration.nix
imports = [
  # ... existing imports ...
  ../../modules/software/some-module.nix  # Add this
];
```

### Remove from All Devices

Comment out or remove the package from the module:

```nix
# modules/software/communication.nix
# slack                # Comment out to remove
```

### Remove a Module from All Devices

Remove the import from `modules/core/base-configuration.nix`:

```nix
# Remove this line:
# ../software/office.nix
```

## Device-Specific Software Examples

### Laptop-Intel
- All base software
- NO creative suite (Intel integrated GPU insufficient)

### Framework (when hardware arrives)
- All base software
- PLUS creative suite (DaVinci Resolve, Blender, Reaper)

### DevTower (when hardware arrives)
- All base software
- PLUS creative suite
- PLUS Go XLR Utility (audio interface)

## Gaming

Gaming support (Steam, emulators, etc.) is **NOT** included as you have a Windows device for gaming.

If you change your mind, create `gaming.nix` and import it where needed.

## Unfree Software

Some packages require accepting unfree licenses:

- **Discord** - Proprietary
- **Zoom** - Proprietary
- **Spotify** - Proprietary
- **VS Code** - Microsoft license
- **Chrome** - Google license
- **Slack** - Proprietary

These are handled by NixOS's `allowUnfree` setting in `modules/core/common.nix`.

## Notes

- **Browsers module** includes Firefox configuration with privacy settings
- **Development module** enables Docker and libvirtd virtualization
- **Creative module** checks for AMD GPU requirement in comments
- **Media module** includes both playback and basic editing (Audacity)
- **Communication module** covers both casual (Discord) and professional (Teams, Zoom)

---

**Summary**: Modular software organization allows easy management of what's installed where, keeping device configurations clean and DRY.
