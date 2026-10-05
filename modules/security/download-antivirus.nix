{ lib, ... }:

{
  # Download automation invokes clamscan directly so every scan can enforce
  # signature freshness, archive limits and encrypted-content alerts. It does
  # not depend on the optional Rust monitor or clamd availability.
  services.clamav.updater.enable = lib.mkDefault true;
  services.clamav.updater.interval = lib.mkDefault "hourly";
}
