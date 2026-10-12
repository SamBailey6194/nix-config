{ config, lib, pkgs, ... }:

# Themed rEFInd boot menu: config/refind/icons rendered by pkgs/refind-theme.nix,
# installed by ./install.py.
#
# Deliberately not nixpkgs' boot.loader.refind: that writes one icon per
# generation, scans every disk (stray Ubuntu ESPs, raw kernels) and, when
# installed as the removable loader, leaves refind.conf and the icons away
# from the binary, where rEFInd does not resolve icons_dir/banner. This
# module replaces systemd-boot when enabled.

let
  cfg = config.bootloader.refind;
  efi = config.boot.loader.efi;
  theme = pkgs.callPackage ../../../pkgs/refind-theme.nix { };

  installConfig = pkgs.writeText "refind-install.json" (builtins.toJSON {
    refindPath = pkgs.refind;
    efibootmgrPath = pkgs.efibootmgr;
    resvgPath = pkgs.resvg;
    fontDir = theme.fontDir;
    fontPath = "${pkgs.refind}/share/refind/fonts/ubuntu-mono-24.png";
    themePath = theme;
    efiMountPoint = efi.efiSysMountPoint;
    efiRemovable = !efi.canTouchEfiVariables;
    inherit (efi) canTouchEfiVariables;
    inherit (config.boot.loader) timeout;
    inherit (cfg) maxGenerations windows tools;
    flakeRev = cfg.flakeRev.text;
    flakeRevDirty = cfg.flakeRev.dirty;
    shellPath = if cfg.shell then "${pkgs.edk2-uefi-shell}/shell.efi" else null;
  });

  installer = pkgs.replaceVarsWith {
    src = ./install.py;
    isExecutable = true;
    replacements = {
      python3 = pkgs.python3;
      configPath = installConfig;
    };
  };
in
{
  options.bootloader.refind = {
    enable = lib.mkEnableOption "the themed rEFInd boot menu in place of systemd-boot";

    maxGenerations = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "Generations listed (the current one plus older ones in its submenu).";
    };

    flakeRev = {
      text = lib.mkOption {
        type = lib.types.str;
        default = "unknown";
        example = "87eb3c0";
        description = "Flake revision for the NixOS icon's build badge (hosts/devtower-intel/full.nix derives it from inputs.self).";
      };
      dirty = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Whether the flake had uncommitted changes (adds an orange * to the badge).";
      };
    };

    windows = lib.mkOption {
      type = lib.types.nullOr (lib.types.submodule {
        options = {
          title = lib.mkOption {
            type = lib.types.str;
            default = "Windows";
            description = "Menu title for the Windows entry.";
          };
          partUuid = lib.mkOption {
            type = lib.types.str;
            example = "89590b26-8a8f-4bc2-885f-3ba0241256bb";
            description = ''
              PARTUUID of the ESP holding EFI/Microsoft/Boot/bootmgfw.efi
              (`lsblk -o NAME,PARTTYPENAME,PARTUUID`). A partition GUID, so it
              survives disks being added or reordered.
            '';
          };
        };
      });
      default = null;
      description = "Chainload entry for Windows on another ESP.";
    };

    tools = lib.mkOption {
      type = lib.types.listOf (lib.types.enum [ "shell" "reboot" "shutdown" "firmware" "about" "hidden_tags" ]);
      default = [ "reboot" "shutdown" "firmware" "about" ] ++ lib.optional cfg.shell "shell";
      description = "Second-row tools, in order (rEFInd's showtools).";
    };

    shell = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Install the EDK2 UEFI shell as EFI/tools/shellx64.efi for the shell tool.
        Off by default: with Secure Boot off, the shell can start the kernel with
        init=/bin/sh and PCR 7 still unseals TPM-bound LUKS, the same hole
        hideui editor closes. Turning it off removes the installed copy.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isx86_64;
        message = "bootloader.refind: only x86_64 (refind_x64.efi) is supported.";
      }
      {
        assertion = config.boot.initrd.secrets == { };
        message = "bootloader.refind does not install boot.initrd.secrets.";
      }
      {
        assertion = !config.boot.loader.grub.enable;
        message = "bootloader.refind replaces systemd-boot; GRUB must be off.";
      }
    ];

    boot.loader.systemd-boot.enable = lib.mkForce false;
    # GRUB defaults to on; systemd-boot normally turns it off, but not once disabled
    boot.loader.grub.enable = lib.mkDefault false;
    system.boot.loader.id = "refind";
    system.build.installBootLoader = installer;
  };
}
