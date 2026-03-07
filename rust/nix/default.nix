# Nix derivations for all Rust CLI tools in the workspace.
# Each crate is built individually using rustPlatform.buildRustPackage
# but they all share the workspace Cargo.lock for dependency resolution.
#
# Usage:
#   packages = import ./rust/nix { inherit pkgs; };
#   packages.malware-scanner  # => /nix/store/...-malware-scanner-0.1.0
{ pkgs }:

let
  inherit (pkgs) lib rustPlatform pkg-config openssl;

  # Common source - the entire workspace root
  # Filter to only include Rust-relevant files
  workspaceSrc = lib.cleanSourceWith {
    src = ./..;
    filter = path: type:
      let
        relPath = lib.removePrefix (toString ./..) (toString path);
      in
      # Exclude build artifacts and nix directory
      !(lib.hasPrefix "/target" relPath) &&
      !(lib.hasPrefix "/fuzz/target" relPath) &&
      !(lib.hasPrefix "/fuzz/artifacts" relPath) &&
      !(lib.hasPrefix "/nix" relPath);
  };

  # Helper to build a single crate from the workspace
  buildWorkspaceCrate = {
    pname,
    nativeBuildInputs ? [],
    buildInputs ? [],
    description ? "${pname} - NixOS configuration tool",
  }: rustPlatform.buildRustPackage {
    inherit pname nativeBuildInputs buildInputs;
    version = "0.1.0";
    src = workspaceSrc;
    cargoLock.lockFile = ../Cargo.lock;
    cargoBuildFlags = [ "--package" pname ];
    cargoTestFlags = [ "--package" pname ];

    meta = {
      inherit description;
      license = lib.licenses.mit;
      platforms = lib.platforms.linux;
    };
  };

in {
  secrets-verify = buildWorkspaceCrate {
    pname = "secrets-verify";
    description = "Verify NixOS agenix secrets are deployed correctly";
  };

  agenix-helper = buildWorkspaceCrate {
    pname = "agenix-helper";
    description = "Helper CLI for agenix secrets management";
  };

  wireguard-helper = buildWorkspaceCrate {
    pname = "wireguard-helper";
    description = "Mullvad WireGuard VPN management tool";
    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ openssl ];
  };

  malware-scanner = buildWorkspaceCrate {
    pname = "malware-scanner";
    description = "NixOS malware scanner with real-time protection";
    nativeBuildInputs = [ pkg-config ];
    buildInputs = [ openssl ];
  };

  storage-manager = buildWorkspaceCrate {
    pname = "storage-manager";
    description = "Storage management tools (restic, zfs, raid)";
  };

  luks-manage = buildWorkspaceCrate {
    pname = "luks-manage";
    description = "LUKS encryption management with TPM2 support";
  };

  btrfs-manage = buildWorkspaceCrate {
    pname = "btrfs-manage";
    description = "BTRFS filesystem management and snapshots";
  };

  vault-manage = buildWorkspaceCrate {
    pname = "vault-manage";
    description = "Per-folder encryption management (gocryptfs)";
  };

  tpm-manage = buildWorkspaceCrate {
    pname = "tpm-manage";
    description = "TPM2 device management tool";
  };

  dev-layout = buildWorkspaceCrate {
    pname = "dev-layout";
    description = "Hyprland dev layout launcher (Zed + 2 terminals)";
  };
}
