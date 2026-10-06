{ pkgs, ... }:

{
  # Garbage collection
  # - Boot menu shows 5 entries (configurationLimit in base-configuration.nix)
  # - Always keep the 3 most recent generations regardless of age
  # - Delete generations older than 90 days beyond those 3
  nix.gc.automatic = false; # We use a custom service instead
  systemd.services.nix-gc-custom = {
    description = "Nix garbage collection (keep min 3 generations, remove >90d)";
    script = ''
      set -eu
      profile="/nix/var/nix/profiles/system"
      cutoff=$(date -d '90 days ago' +%Y-%m-%d)

      # List generations newest first, skip the 3 most recent,
      # then collect generation numbers older than 90 days
      to_delete=$(${pkgs.nix}/bin/nix-env -p "$profile" --list-generations \
        | sort -rn \
        | tail -n +4 \
        | while read -r gen date rest; do
            if [ "$date" \< "$cutoff" ]; then
              echo "$gen"
            fi
          done \
        | tr '\n' ' ')

      if [ -n "$to_delete" ]; then
        echo "Deleting old generations: $to_delete"
        ${pkgs.nix}/bin/nix-env -p "$profile" --delete-generations $to_delete
      else
        echo "No generations to clean up"
      fi

      ${pkgs.nix}/bin/nix-store --gc
    '';
    serviceConfig.Type = "oneshot";
    startAt = "weekly";
  };
}
