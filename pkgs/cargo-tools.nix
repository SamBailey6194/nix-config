# Cargo subcommands (and maturin) bumped ahead of nixpkgs. Only the source and the vendored
# dependencies change; build inputs, flags, wrappers and meta all come from the
# nixpkgs packages.
#
# To bump one: change its `version`, set `hash` and `cargoHash` to
# lib.fakeHash, and build to get the real hashes. Delete an entry (and use the
# plain nixpkgs attribute in modules/software/development.nix) once nixpkgs
# reaches the same version. Check with:
#   curl -s https://crates.io/api/v1/crates/<crate> | jq -r .crate.max_stable_version
{
  cargo-nextest,
  cargo-llvm-cov,
  cargo-edit,
  maturin,
  rust-bindgen,
  rust-bindgen-unwrapped,
  fetchFromGitHub,
  fetchCrate,
  rustPlatform,
}:

let
  # Swap a buildRustPackage derivation onto a new source. cargoDeps has to be
  # rebuilt explicitly: overrideAttrs does not re-run buildRustPackage, so the
  # old vendor directory would otherwise be kept and fail the lockfile check.
  bump =
    pkg:
    {
      version,
      src,
      cargoHash,
      extra ? { },
    }:
    pkg.overrideAttrs (
      old:
      {
        inherit version src;
        cargoDeps = rustPlatform.fetchCargoVendor {
          inherit src;
          name = "${old.pname}-${version}";
          hash = cargoHash;
        };
      }
      // extra
    );

  bindgen-unwrapped = bump rust-bindgen-unwrapped rec {
    version = "0.73.2";
    src = fetchCrate {
      pname = "bindgen-cli";
      inherit version;
      hash = "sha256-9RAgvrLO0Z2pu89ANmsolZjpNuRkm1jwxtXsNzpGi6w=";
    };
    cargoHash = "sha256-BRHAzgSbBYSJKThws/RcbCqwnNBbdzC7O8hHcdlguPo=";
  };
in
{
  cargo-nextest = bump cargo-nextest rec {
    version = "0.9.150";
    src = fetchFromGitHub {
      owner = "nextest-rs";
      repo = "nextest";
      tag = "cargo-nextest-${version}";
      hash = "sha256-8smZD0W9pcVEDnOHt5AOMpWkP5TawOGxsDksoKcb4Ys=";
    };
    cargoHash = "sha256-rY+6iJXf7j2Uz1Q7MtbntkBxYCDr+WaP9DUxm6P3hZ4=";
  };

  # Fetched from crates.io rather than GitHub: upstream does not commit
  # Cargo.lock (nixpkgs vendors its own), but the published crate carries one.
  #
  # Tests are off. In the build sandbox they fail even on nixpkgs' own 0.9.0:
  # the test harness merges profiles with nixpkgs' llvm-profdata (LLVM 22),
  # which cannot read what rustc 1.99's instrumentation writes ("no profile
  # can be merged"). Real use goes through rustup's llvm-tools-preview, which
  # matches the active rustc, so the binary itself is unaffected. See the
  # header of nixpkgs' pkgs/by-name/ca/cargo-llvm-cov/package.nix.
  cargo-llvm-cov = bump cargo-llvm-cov rec {
    version = "0.9.1";
    src = fetchCrate {
      pname = "cargo-llvm-cov";
      inherit version;
      hash = "sha256-GajnapkpjlSaKrs7SYl3NvXzfLfQvDEZtDuregBQqBw=";
    };
    cargoHash = "sha256-uSMRu+OjdEyxYyGc65Z5vYOcHyOcgf1L3Kxc4QHRM2o=";
    extra = {
      postPatch = "";
      doCheck = false;
    };
  };

  cargo-edit = bump cargo-edit rec {
    version = "0.13.14";
    src = fetchFromGitHub {
      owner = "killercup";
      repo = "cargo-edit";
      rev = "v${version}";
      hash = "sha256-Hp4hAaVVTBUwPMdCD27uqLUpj40zLN1RNaee1IsFVSY=";
    };
    cargoHash = "sha256-bDYIsDj5+t55ET9CE7DTyKqIv8Jp0ghPGMkDTTH6cQU=";
  };

  # Only the CLI on PATH. rustPlatform.maturinBuildHook (nixpkgs Python
  # packaging) keeps nixpkgs' own maturin.
  maturin = bump maturin rec {
    version = "1.16.0";
    src = fetchFromGitHub {
      owner = "PyO3";
      repo = "maturin";
      tag = "v${version}";
      hash = "sha256-Bqqq+oVivqrpbEXoWRwMQ6slefnPcEGSnLRXy5SIyys=";
    };
    cargoHash = "sha256-Ch2FOMk7KkZrb+iqJeUI0NfHltEI2sXpGkT0m6jnbp0=";
  };

  # The wrapper adds the libc/libc++ include flags; re-wrap the bumped binary.
  rust-bindgen = rust-bindgen.override { rust-bindgen-unwrapped = bindgen-unwrapped; };
}
