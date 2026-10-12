# Software Modules Organization

**Last Updated**: 28/09/2026
**Version**: 1.5.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---
This directory contains purpose-specific software modules that can be mixed and matched across devices.

## Module Overview

| Module | Purpose | Key Packages | Imported By |
|--------|---------|--------------|-------------|
| `browsers.nix` | Web browsers | LibreWolf, Firefox, Chrome | base-configuration |
| `communication.nix` | Chat & collaboration | Teams, Zoom, Slack | base-configuration |
| `media.nix` | Media playback | VLC, Spotify, MPV, image viewers | base-configuration |
| `development.nix` | Dev tools & IDEs | VS Code, Docker, language servers | base-configuration |
| `office.nix` | Office productivity | LibreOffice, PDF tools | base-configuration |
| `creative.nix` | Creative suite | DaVinci Resolve, Blender, Reaper | Framework & DevTower only |
| `craft-apps.nix` | ArtCraft Craft apps | PhotoCraft, VectorCraft, LightCraft, PdfCraft, DesignCraft, EffectCraft, FilmCraft, SoundCraft, WordCraft, DeckCraft | every `configuration-creative.nix` / `configuration-full.nix` (so devtower-intel creative + full too) |
| `local-llm.nix` | Local LLM inference (`services.localLlm.*`, off by default) | llama.cpp with CUDA + OpenBLAS, per-host CUDA architectures | `development.nix`; enabled on devtower-intel (dev stage and up) |

## Currently Installed on All Devices

These modules are imported in `modules/core/base-configuration.nix` and available on **all** devices:

- **Browsers**: LibreWolf (privacy), Firefox (dev testing), Chrome (Claude extension)
- **Communication**: Microsoft Teams, Zoom, Slack
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

## ArtCraft Craft Apps

`craft-apps.nix` installs the [ArtCraft](https://getartcraft.com/apps) "Craft"
apps from `pkgs/craft-apps`: native Rust/wgpu programs, packaged from the
upstream Linux x86_64 AppImages on GitHub (`storytold/<app>`) with
`appimageTools.wrapType2`. Each package installs the upstream `.desktop` entry,
hicolor icons, MIME types and AppStream metainfo.

It is imported wherever the Affinity apps are, i.e. every creative and full
stage of laptop-intel, framework and devtower. devtower-intel is built from the
devtower stage files, so `devtower-intel-creative` and `devtower-intel` get
them too. It is a separate module rather than part of `creative.nix` because
laptop-intel's creative stages do not import `creative.nix` (no dedicated GPU
for DaVinci Resolve) but should still get these. ArtCraft itself has no Linux
build and is not packaged; nor are craft-launcher, cadcraft and gridcraft.
The ten apps: PhotoCraft, VectorCraft, LightCraft, PdfCraft, DesignCraft,
EffectCraft, FilmCraft, SoundCraft, WordCraft and DeckCraft.

**Updating**: versions, URLs and SRI hashes are pinned in
`pkgs/craft-apps/sources.json`. `just update-craft` re-pins every app to its
latest GitHub release (hash from the release API `digest`, cross-checked
against `SHA256SUMS.txt`) and prints what changed; `just update-craft --check`
only reports and exits 1 when something is out of date. Set `GITHUB_TOKEN` to
avoid the anonymous API rate limit. The apps are not flake inputs, so
`just update` does not touch them. Tests: `scripts/tests/test_update_craft_apps.py`.

**Window classes** (for Hyprland window rules). On Wayland each app sets
`app_id` to the reverse-DNS id that is also its `.desktop` file name and icon
name; read from the binaries and desktop files, not from a running window:

| App | Binary | Desktop file / Icon | StartupWMClass | Wayland app_id |
|-----|--------|---------------------|----------------|----------------|
| PhotoCraft | `photocraft` | `ai.storyteller.photocraft` | `photocraft` | `ai.storyteller.photocraft` |
| VectorCraft | `vectorcraft` | `ai.storyteller.vectorcraft` | `ai.storyteller.vectorcraft` | `ai.storyteller.vectorcraft` |
| LightCraft | `lightcraft` | `ai.storyteller.lightcraft` | `ai.storyteller.lightcraft` | `ai.storyteller.lightcraft` |
| PdfCraft | `pdfcraft` | `ai.storyteller.pdfcraft` | `ai.storyteller.pdfcraft` | `ai.storyteller.pdfcraft` |
| DesignCraft | `designcraft` | `ai.storyteller.designcraft` | `ai.storyteller.designcraft` | `ai.storyteller.designcraft` |
| EffectCraft | `effectcraft` | `ai.storyteller.effectcraft` | `ai.storyteller.effectcraft` | `ai.storyteller.effectcraft` |
| FilmCraft | `filmcraft` | `ai.storyteller.filmcraft` | `ai.storyteller.filmcraft` | `ai.storyteller.filmcraft` |
| SoundCraft | `soundcraft` | `ai.storyteller.soundcraft` | `ai.storyteller.soundcraft` | `ai.storyteller.soundcraft` |
| WordCraft | `wordcraft` | `ai.storyteller.wordcraft` | `ai.storyteller.wordcraft` | `ai.storyteller.wordcraft` |
| DeckCraft | `deckcraft` | `ai.storyteller.deckcraft` | `ai.storyteller.deckcraft` | `ai.storyteller.deckcraft` |

PhotoCraft opens through Xwayland when it finds a pen tablet, or when
Preferences > Performance > Linux display server says so
(`PHOTOCRAFT_NATIVE_WAYLAND=1` keeps it on Wayland); its X11 class is then
probably `photocraft`, as its `StartupWMClass` says. A window rule with the
class regex `^(ai\.storyteller\.photocraft|photocraft)$` covers both.

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
- **Communication module** covers professional chat and calls (Teams, Zoom, Slack)

---

**Summary**: Modular software organization allows easy management of what's installed where, keeping device configurations clean and DRY.
