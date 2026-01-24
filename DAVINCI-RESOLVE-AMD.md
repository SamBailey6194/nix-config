# DaVinci Resolve Studio on NixOS with AMD GPU

Configuration guide for running DaVinci Resolve Studio on NixOS with AMD Radeon GPU using Rusticl (OpenCL via Mesa).

## Overview

DaVinci Resolve Studio requires:
- **AMD Radeon GPU** with Rusticl/OpenCL support
- **Rusticl** (OpenCL via Mesa) instead of ROCm
- **X11/XWayland** (cannot run on native Wayland due to qtwayland version mismatch)
- Specific environment variables for AMD GPU detection

## NixOS Configuration

The configuration is in `modules/software/creative.nix`:

```nix
{
  # Install DaVinci Resolve Studio
  environment.systemPackages = with pkgs; [
    davinci-resolve-studio
  ];

  # Enable AMD GPU with Rusticl (OpenCL via Mesa)
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs; [
      mesa.opencl  # Enables Rusticl (OpenCL) support
    ];
  };

  # Environment variables for DaVinci Resolve
  environment.variables = {
    RUSTICL_ENABLE = "radeonsi";  # Enable Rusticl for AMD GPU
  };
}
```

## Launch Command

DaVinci Resolve **must** be launched with specific environment variables:

```bash
ROC_ENABLE_PRE_VEGA=1 \
RUSTICL_ENABLE=amdgpu,amdgpu-pro,radv,radeon,radeonsi \
DRI_PRIME=1 \
QT_QPA_PLATFORM=xcb \
davinci-resolve-studio
```

### Environment Variables Explained

| Variable | Purpose |
|----------|---------|
| `ROC_ENABLE_PRE_VEGA=1` | Enable support for pre-Vega AMD GPUs |
| `RUSTICL_ENABLE=...` | Enable all AMD GPU drivers for Rusticl |
| `DRI_PRIME=1` | Use discrete GPU instead of integrated graphics |
| `QT_QPA_PLATFORM=xcb` | Force X11/XWayland (not native Wayland) |

## Shell Aliases (DevTower Only)

For convenience, shell aliases are configured in `home/devtower.nix`:

```bash
# Full command
resolve

# Short alias
dvr
```

Both aliases launch DaVinci Resolve Studio with all necessary AMD GPU flags.

## Wayland vs X11

**Important**: DaVinci Resolve **cannot** run on native Wayland.

- **Problem**: qtwayland version mismatch between DaVinci and NixOS
- **Solution**: Force X11/XWayland mode with `QT_QPA_PLATFORM=xcb`
- **Hyprland**: Automatically handles XWayland, no additional configuration needed

When running on Hyprland (Wayland compositor):
1. Hyprland detects `QT_QPA_PLATFORM=xcb`
2. Automatically launches DaVinci in XWayland mode
3. Window rules in `config/hypr/devices/devtower.conf` still apply

## Workspace Configuration

In Hyprland (`config/hypr/devices/devtower.conf`):

```conf
# DaVinci Resolve: fullscreen on workspace 5, left 4K monitor
windowrulev2 = workspace 5, class:^(resolve)$
windowrulev2 = fullscreen, class:^(resolve)$
```

**Recommended layout for devtower:**
- **Left monitor (4K)**: DaVinci Resolve (workspace 5)
- **Center monitor (1440p)**: Preview/timeline (workspace 5)
- **Right monitor (1080p vertical)**: Color grading scopes, effects panel

## OpenFX Plugins

DaVinci Resolve supports OpenFX plugins. On NixOS, plugins cannot be installed to `/usr/OFX/Plugins`.

**Solution**: Configure `OFX_PLUGIN_PATH` in `modules/software/creative.nix`:

```nix
environment.variables = {
  OFX_PLUGIN_PATH = lib.concatStringsSep ";" [
    # Add plugin packages here
    # "${pkgs.some-ofx-plugin}"
  ];
};
```

**Manual plugin installation:**
1. Download `.ofx.bundle` plugin
2. Place in `~/.local/share/OFX/Plugins/` or custom location
3. Add path to `OFX_PLUGIN_PATH`

## Testing GPU Acceleration

After installation, verify GPU acceleration:

1. **Launch DaVinci Resolve:**
   ```bash
   resolve
   ```

2. **Check GPU detection:**
   - DaVinci Resolve → Preferences → System → Memory and GPU
   - Should show your AMD Radeon GPU
   - OpenCL should show as available

3. **Test playback:**
   - Import 4K footage
   - Playback should be smooth with GPU acceleration
   - If stuttering, check `RUSTICL_ENABLE` flags

## Troubleshooting

### DaVinci won't launch
- Check that `hardware.graphics.enable = true`
- Verify `mesa.opencl` in `extraPackages`
- Try launching from terminal to see error messages

### GPU not detected
- Verify environment variables: `echo $RUSTICL_ENABLE`
- Check DaVinci logs: `~/.local/share/DaVinciResolve/logs/`
- Try adding more GPU drivers to `RUSTICL_ENABLE`

### XWayland issues
- Ensure `QT_QPA_PLATFORM=xcb` is set
- Check Hyprland XWayland status: `hyprctl clients | grep -A5 resolve`
- If native Wayland is attempted, force X11 in launch command

### Performance issues
- Check GPU utilization: `radeontop` or `nvtop`
- Verify playback resolution matches timeline settings
- Try optimized media (proxies) for 4K/8K footage
- Check if GPU is thermal throttling

## Hardware Requirements

**Minimum:**
- AMD Radeon RX 580 or newer
- 16GB RAM
- SSD for cache/media storage

**Recommended (devtower):**
- AMD Radeon RX 6000/7000 series or Pro series
- 64GB RAM
- NVMe SSD for cache
- Separate SSD/HDD for media storage

## Related Files

- `modules/software/creative.nix` - DaVinci + AMD GPU configuration
- `home/devtower.nix` - Shell aliases for easy launching
- `config/hypr/devices/devtower.conf` - Hyprland window rules
- `modules/hardware/amd-desktop.nix` - AMD GPU hardware configuration

## References

- [NixOS Wiki: DaVinci Resolve](https://wiki.nixos.org/wiki/DaVinci_Resolve)
- [DaVinci Resolve Linux Requirements](https://www.blackmagicdesign.com/products/davinciresolve)
- [Mesa Rusticl Documentation](https://docs.mesa3d.org/rusticl.html)

## Post-Installation Checklist

After installing NixOS on devtower:

- [ ] Verify AMD GPU drivers loaded: `lspci -k | grep -A 3 VGA`
- [ ] Test DaVinci launch: `resolve`
- [ ] Check GPU detection in DaVinci preferences
- [ ] Import sample 4K footage and test playback
- [ ] Configure workspace 5 for video editing
- [ ] Install OpenFX plugins (if needed)
- [ ] Set up project/media storage locations
- [ ] Configure color management settings
