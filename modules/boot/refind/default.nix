{ config, lib, pkgs, ... }:

# Themed rEFInd boot menu: config/refind/icons rendered by pkgs/refind-theme.nix,
# installed by ./install.py.
#
# Deliberately not nixpkgs' boot.loader.refind: that writes one icon per
# generation, scans every disk (stray Ubuntu ESPs, raw kernels) and, when
# installed as the removable loader, leaves refind.conf and the icons away
# from the binary, where rEFInd does not resolve icons_dir/banner. This
# module replaces systemd-boot when enabled, or with chainload = true sits
# beside it as one extra systemd-boot menu entry.

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
    # Chainloaded rEFInd has its own directory; as the main loader without
    # NVRAM access it takes the firmware's removable fallback slot.
    efiRemovable = !cfg.chainload && !efi.canTouchEfiVariables;
    registerNvram = !cfg.chainload && efi.canTouchEfiVariables;
    inherit (config.boot.loader) timeout;
    inherit (cfg) maxGenerations windows tools logLevel resolution;
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

    chainload = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Keep systemd-boot as the boot loader and add rEFInd (EFI/refind) as one
        extra entry in its menu, so a rEFInd that fails to start costs a
        reboot rather than a rescue USB.
      '';
    };

    logLevel = lib.mkOption {
      type = lib.types.ints.between 0 4;
      default = 0;
      description = "rEFInd's log_level: above 0 it writes refind.log (and refind.log-old) beside its binary.";
    };

    resolution = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "max";
      description = ''
        rEFInd's resolution token ("max", "1920 1080", or a GOP mode number).
        Null keeps the mode the firmware set, which every monitor that showed
        the firmware screen can display.
      '';
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

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
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
          message = "bootloader.refind replaces or chainloads from systemd-boot; GRUB must be off.";
        }
      ];
    }

    (lib.mkIf (!cfg.chainload) {
      boot.loader.systemd-boot.enable = lib.mkForce false;
      # GRUB defaults to on; systemd-boot normally turns it off, but not once disabled
      boot.loader.grub.enable = lib.mkDefault false;
      system.boot.loader.id = "refind";
      system.build.installBootLoader = installer;
    })

    (lib.mkIf cfg.chainload {
      assertions = [
        {
          assertion = config.boot.loader.systemd-boot.enable;
          message = "bootloader.refind.chainload adds rEFInd to systemd-boot's menu; systemd-boot must be on.";
        }
      ];

      # Sorts after the NixOS generations, so systemd-boot's default is unchanged.
      # The systemd-boot builder deletes the entry again once chainload is off.
      boot.loader.systemd-boot.extraEntries."refind.conf" = ''
        title rEFInd
        efi /EFI/refind/refind_x64.efi
        sort-key z-refind
      '';
      # Runs after systemd-boot has installed this generation, with the profile
      # already pointing at it, as the installer expects.
      boot.loader.systemd-boot.extraInstallCommands = "${installer}";
    })
  ]);
}
