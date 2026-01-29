# Minimal Configuration Template

**Last Updated**: 29/01/2026
**Version**: 0.7.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---
This guide explains how to create minimal installation configurations for new NixOS devices. Minimal configurations are used during `nixos-install` to avoid tmpfs space issues when building large configurations.

## Table of Contents

- [Purpose](#purpose)
- [When to Use Minimal Configs](#when-to-use-minimal-configs)
- [Standard Pattern Structure](#standard-pattern-structure)
- [Device Type Guide](#device-type-guide)
- [Step-by-Step Instructions](#step-by-step-instructions)
- [What to Include vs. Exclude](#what-to-include-vs-exclude)
- [Examples by Device Type](#examples-by-device-type)
- [Troubleshooting](#troubleshooting)

## Purpose

Minimal configurations solve a specific problem during NixOS installation:

**Problem**: During `nixos-install`, the installer runs in a tmpfs ramdisk with limited space. Building a full configuration with desktop environments, secrets, home-manager, and all software can exceed available tmpfs space, causing the installation to fail.

**Solution**: Use a minimal configuration that includes only essential system components. After the system boots successfully, rebuild with the full configuration which has access to the actual disk.

## When to Use Minimal Configs

Create a minimal configuration for **every** new device, regardless of type:

- **Workstations** (laptops, desktops) - Always use minimal for installation
- **Servers** (cloud VMs, bare metal) - Essential for server installations
- **Network devices** (routers, NAS) - Critical for embedded/low-memory devices
- **Virtual machines** - Useful even for VMs to speed up initial deployment

**Exception**: Only skip minimal configs for devices where you're confident the full configuration will fit in tmpfs (typically < 4GB RAM allocated to installer).

## Standard Pattern Structure

All minimal configurations follow this exact structure:

```nix
{ config, pkgs, inputs, ... }:

{
  # MINIMAL INSTALLATION CONFIGURATION
  # Use this for initial nixos-install to avoid tmpfs space issues
  # After successful boot, switch to configuration.nix and rebuild

  imports = [
    # Hardware (required)
    ./hardware-configuration.nix

    # Essential only
    ../../modules/core/nix-settings.nix
    ../../modules/hardware/{device-type}.nix
    ../../modules/users/{device-name}.nix
  ];

  # Device identity
  networking.hostName = "{hostname}";

  # Boot Loader
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.networkmanager.enable = true;

  # Time Zone & Locale
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  # Minimal system packages
  environment.systemPackages = with pkgs; [
    vim
    wget
    git
    htop
  ];

  # Enable zsh (required for user shell)
  programs.zsh.enable = true;

  # System State Version
  system.stateVersion = "24.11";
}
```

## Device Type Guide

Choose the appropriate hardware module based on your device:

### Workstations

| Device Type | Hardware Module | Example |
|-------------|----------------|---------|
| Intel laptop | `intel-laptop.nix` | laptop-intel |
| AMD laptop | `amd-laptop.nix` | framework |
| AMD desktop | `amd-desktop.nix` | devtower |
| NVIDIA desktop | `nvidia-desktop.nix` | (future) |

### Servers

| Device Type | Hardware Module | Example |
|-------------|----------------|---------|
| Cloud VM (Intel) | `cloud-intel.nix` | cloud-staging |
| Cloud VM (AMD) | `cloud-amd.nix` | cloud-prod |
| Bare metal server | `server-baremet.nix` | nas |
| ARM server | `server-arm.nix` | (future) |

### Network Devices

| Device Type | Hardware Module | Example |
|-------------|----------------|---------|
| DIY router | `router.nix` | router |
| NAS | `nas.nix` | nas |
| Firewall appliance | `firewall.nix` | (future) |

**Note**: Server and network device hardware modules don't exist yet. Create them when implementing those phases, following the pattern established in existing hardware modules.

## Step-by-Step Instructions

### 1. Create User Module (if new device type)

If this is a new device type (not just a new instance of an existing type), create a user module first:

**Location**: `modules/users/{device-name}.nix`

```nix
{ config, pkgs, ... }:

{
  # User configuration for {device-name} device

  users.users.{username} = {
    isNormalUser = true;
    description = "{Full Name} ({Device})";
    extraGroups = [
      "wheel"          # sudo access
      "networkmanager" # network management
      "video"          # video devices (workstations only)
      "audio"          # audio devices (workstations only)
      # Add device-specific groups as needed
    ];
    shell = pkgs.zsh;

    # Password will be set during installation
    # Use: passwd {username}

    # SSH authorized keys (will be added in Phase 2 via secrets)
    # openssh.authorizedKeys.keys = [ ];
  };

  # Root user configuration
  users.users.root = {
    hashedPassword = "!"; # Locked password - use sudo
  };

  # Sudo configuration
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };
}
```

**Important considerations**:
- **Servers**: Typically don't need `video` or `audio` groups
- **Routers/NAS**: May need `dialout`, `tty`, or storage-specific groups
- **Multi-user servers**: May need multiple user definitions in one module

### 2. Create Hardware Module (if needed)

If the hardware type doesn't exist yet, create a hardware module:

**Location**: `modules/hardware/{device-type}.nix`

**Workstation example** (laptop/desktop):
```nix
{ config, lib, pkgs, ... }:

{
  # Hardware-specific configuration for {device type}

  # Boot configuration
  boot.kernelModules = [ /* hardware-specific modules */ ];
  boot.initrd.kernelModules = [ /* initrd modules */ ];

  # Graphics
  hardware.graphics = {
    enable = true;
    # GPU-specific settings
  };

  # Power management (laptops only)
  powerManagement.enable = true;

  # Audio (workstations only)
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
}
```

**Server example**:
```nix
{ config, lib, pkgs, ... }:

{
  # Server hardware configuration

  # Minimal boot
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  # No graphics needed
  hardware.graphics.enable = false;

  # Server-specific kernel parameters
  boot.kernelParams = [
    "nomodeset"  # No graphics mode setting
    "console=ttyS0,115200"  # Serial console
  ];
}
```

**Router/NAS example**:
```nix
{ config, lib, pkgs, ... }:

{
  # Network device hardware configuration

  # Minimal boot
  boot.loader.grub.enable = true;

  # Network interfaces
  # (specific interfaces configured per device)

  # No graphics, audio, or power management
  hardware.graphics.enable = false;

  # Firewall (configure specific rules in device config)
  networking.firewall.enable = true;
}
```

### 3. Create Minimal Configuration

**Location**: `hosts/{device-name}/configuration-minimal.nix`

Use the [Standard Pattern Structure](#standard-pattern-structure) template and replace:
- `{device-type}` → Your hardware module (e.g., `amd-laptop.nix`)
- `{device-name}` → Your user module (e.g., `framework.nix`)
- `{hostname}` → Device hostname (e.g., `framework`)

**Device-specific adjustments**:

**Servers**:
- Add `services.openssh.enable = true;` for remote access
- Consider adding `services.tailscale.enable = true;` for VPN access
- May need specific network interface configuration

**Routers/Network devices**:
- Add firewall configuration
- Add specific network interface configuration
- May need VPN configuration (WireGuard, etc.)
- Consider adding `services.openssh.enable = true;` for management

**Virtual machines**:
- Add VM-specific kernel modules
- May need guest agent packages

### 4. Add Flake Target

**Location**: `flake.nix`

Add a new `nixosSystem` output for the minimal configuration:

```nix
# Minimal installation configuration for {device-name}
{device-name}-minimal = nixpkgs.lib.nixosSystem {
  system = "x86_64-linux";  # or "aarch64-linux" for ARM
  specialArgs = { inherit inputs; };
  modules = [
    ./hosts/{device-name}/configuration-minimal.nix
  ];
};
```

**Placement**: Add immediately after the full configuration for the same device.

### 5. Verify Configuration

Run syntax and build checks:

```bash
# Syntax validation
nix-instantiate --parse hosts/{device-name}/configuration-minimal.nix

# Flake check
nix flake check

# Dry-run build (ensures all dependencies resolve)
nixos-rebuild dry-build --flake .#{device-name}-minimal
```

## What to Include vs. Exclude

### ✅ Always Include (Minimal Config)

- **Hardware configuration**: `./hardware-configuration.nix`
- **Nix settings**: `../../modules/core/nix-settings.nix`
- **Hardware module**: Device-specific hardware configuration
- **User module**: Device-specific user accounts
- **Hostname**: `networking.hostName`
- **Boot loader**: Basic systemd-boot or GRUB
- **Networking**: NetworkManager or basic networking
- **Time & Locale**: Timezone and locale settings
- **Minimal packages**: vim, wget, git, htop
- **Shell**: zsh (required for user shell)
- **State version**: `system.stateVersion`

### ❌ Always Exclude (Minimal Config)

- **Base configuration**: `../../modules/core/base-configuration.nix` (pulls in everything)
- **Desktop environments**: Hyprland, GNOME, KDE, etc.
- **Secrets**: agenix, SSH configs, encrypted files
- **Home Manager**: User environment management
- **Software suites**: Development tools, creative apps, etc.
- **SSH config**: Auto-generated SSH configuration
- **Optional services**: Docker, virtualization, etc.
- **Display managers**: GDM, SDDM, LightDM

### 🤔 Conditional Inclusion

**Include if needed**:
- **OpenSSH**: For servers and remote devices
- **Tailscale/VPN**: For remote access to servers
- **Specific network interfaces**: For routers and network devices
- **Serial console**: For headless devices
- **VM guest tools**: For virtual machines

## Examples by Device Type

### Workstation (Laptop)

```nix
{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/nix-settings.nix
    ../../modules/hardware/amd-laptop.nix
    ../../modules/users/framework.nix
  ];

  networking.hostName = "framework";
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  networking.networkmanager.enable = true;
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  environment.systemPackages = with pkgs; [
    vim wget git htop
  ];

  programs.zsh.enable = true;
  system.stateVersion = "24.11";
}
```

### Server (Cloud VM)

```nix
{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/nix-settings.nix
    ../../modules/hardware/cloud-intel.nix
    ../../modules/users/cloud-staging.nix
  ];

  networking.hostName = "cloud-staging";
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  # Server-specific: Enable SSH for remote access
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
    settings.PasswordAuthentication = false;
  };

  # Basic networking (server doesn't need NetworkManager)
  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    vim wget git htop curl
  ];

  programs.zsh.enable = true;
  system.stateVersion = "24.11";
}
```

### Router (DIY Router/Firewall)

```nix
{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/nix-settings.nix
    ../../modules/hardware/router.nix
    ../../modules/users/router.nix
  ];

  networking.hostName = "router";
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  # Router-specific: Enable SSH for management
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
  };

  # Router-specific: Configure network interfaces
  networking.useDHCP = false;
  networking.interfaces = {
    wan0.useDHCP = true;   # WAN interface
    lan0.ipv4.addresses = [{  # LAN interface
      address = "192.168.1.1";
      prefixLength = 24;
    }];
  };

  # Router-specific: Enable forwarding
  boot.kernel.sysctl = {
    "net.ipv4.ip_forward" = 1;
    "net.ipv6.conf.all.forwarding" = 1;
  };

  # Basic firewall (specific rules in full config)
  networking.firewall.enable = true;

  time.timeZone = "UTC";
  i18n.defaultLocale = "en_US.UTF-8";

  environment.systemPackages = with pkgs; [
    vim wget git htop iptables
  ];

  programs.zsh.enable = true;
  system.stateVersion = "24.11";
}
```

### NAS (Storage Server)

```nix
{ config, pkgs, inputs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/core/nix-settings.nix
    ../../modules/hardware/nas.nix
    ../../modules/users/nas.nix
  ];

  networking.hostName = "nas";
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/sda";

  # NAS-specific: Enable SSH for management
  services.openssh = {
    enable = true;
    settings.PermitRootLogin = "no";
  };

  networking.useDHCP = false;
  networking.interfaces.eth0.useDHCP = true;

  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";

  environment.systemPackages = with pkgs; [
    vim wget git htop
    zfs  # ZFS tools (if using ZFS)
  ];

  programs.zsh.enable = true;
  system.stateVersion = "24.11";
}
```

## Troubleshooting

### Build Errors

**Error**: `attribute 'hardware-configuration' missing`

**Solution**: The `hardware-configuration.nix` file is generated during `nixos-generate-config`. If it doesn't exist yet, that's expected - you'll generate it during installation.

---

**Error**: `error: undefined variable '{module}'`

**Solution**: Ensure the referenced hardware or user module exists at the specified path. Check the imports section for typos.

---

**Error**: `infinite recursion encountered`

**Solution**: Check for circular imports. Minimal configs should NOT import `base-configuration.nix`, which can create circular dependencies.

### Installation Issues

**Problem**: Installation still fails with "No space left on device"

**Solutions**:
1. Increase tmpfs size: `mount -o remount,size=8G /mnt`
2. Remove unnecessary packages from `environment.systemPackages`
3. Disable any remaining optional services
4. Consider installing from a USB with more RAM

---

**Problem**: User can't log in after installation

**Solutions**:
1. Ensure you ran `passwd {username}` during installation
2. Verify the user shell (zsh) is enabled: `programs.zsh.enable = true;`
3. Check user groups include `wheel` for sudo access

---

**Problem**: Network doesn't work after reboot

**Solutions**:
1. Verify NetworkManager is enabled: `networking.networkmanager.enable = true;`
2. For servers without NetworkManager, ensure network interfaces are configured
3. Check firewall isn't blocking required ports

### Post-Installation

**Problem**: Can't rebuild with full configuration

**Solutions**:
1. Ensure full configuration imports agenix module
2. Verify all secrets are accessible (check host SSH keys)
3. Try building without secrets first to isolate the issue
4. Check that home-manager is properly configured

---

**Problem**: Services fail to start after switching to full config

**Solutions**:
1. Check service logs: `journalctl -u {service-name}`
2. Verify all required secrets are deployed
3. Ensure hardware modules are compatible with actual hardware
4. Try rebuilding with `--show-trace` for detailed error info

## Workflow Summary

1. **Create user module** (if new device type)
2. **Create hardware module** (if needed)
3. **Copy template** → `hosts/{device-name}/configuration-minimal.nix`
4. **Customize** for device type (replace placeholders)
5. **Add flake target** in `flake.nix`
6. **Verify** with `nix flake check`
7. **Use during installation** with `nixos-install --flake .#{device-name}-minimal`
8. **After boot**, rebuild with full config: `nixos-rebuild switch --flake .#{device-name}`

## Additional Resources

- **Installation Guide**: `MINIMAL-INSTALL-GUIDE.md` - Complete installation walkthrough
- **Architecture**: `ARCHITECTURE.md` - System architecture overview
- **Secrets Setup**: `PHASE-2-SECRETS-SETUP.md` - Per-device secrets configuration
- **Project Instructions**: `CLAUDE.md` - Quick reference for all commands

## Questions?

If you encounter issues not covered here:
1. Check the installation guide for device-specific guidance
2. Review existing minimal configs for examples
3. Verify syntax with `nix-instantiate --parse`
4. Test build with `nixos-rebuild dry-build --flake`
