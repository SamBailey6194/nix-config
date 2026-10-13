{ pkgs, ... }:

{
  # Garbage collection
  # - Boot menu shows 5 entries (configurationLimit in base-configuration.nix;
  #   bootloader.refind.maxGenerations on devtower-intel's full stage)
  # - Keep the newest 5 system generations to match, with no age rule
  #   (nix-env --delete-generations +5 never deletes the current generation)
  # - Prune every user's home-manager profile to the newest 5 the same way
  # - Then collect anything without a GC root
  nix.gc.automatic = false; # We use a custom service instead
  systemd.services.nix-gc-custom = {
    description = "Nix garbage collection (keep newest 5 system and home-manager generations)";
    script = ''
      set -eu
      nixEnv=${pkgs.nix}/bin/nix-env

      echo "Pruning system generations to the newest 5"
      $nixEnv -p /nix/var/nix/profiles/system --delete-generations +5

      # home-manager runs as a NixOS module, so its profile is either the
      # legacy per-user one or the XDG one under the user's home. Check both
      # for every account, skip missing ones, and prune as the profile's owner
      # so no root-owned files appear in the user's profile directory. One
      # failing profile must not stop the rest or the GC.
      ${pkgs.getent}/bin/getent passwd | while IFS=: read -r user _ _ _ _ home _; do
        for profile in \
          "/nix/var/nix/profiles/per-user/$user/home-manager" \
          "$home/.local/state/nix/profiles/home-manager"; do
          [ -L "$profile" ] || continue
          owner=$(${pkgs.coreutils}/bin/stat -c %U "$(${pkgs.coreutils}/bin/dirname "$profile")")
          echo "Pruning home-manager generations to the newest 5: $profile"
          ${pkgs.util-linux}/bin/runuser -u "$owner" -- \
            $nixEnv -p "$profile" --delete-generations +5 \
            || echo "Warning: could not prune $profile" >&2
        done
      done

      ${pkgs.nix}/bin/nix-store --gc
    '';
    serviceConfig.Type = "oneshot";
    startAt = "weekly";
  };
}
