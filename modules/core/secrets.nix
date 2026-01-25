# Agenix secrets module
# Wires encrypted secrets into the system
# Secrets are decrypted at boot and placed in /run/agenix/
#
# Usage in host configs:
#   imports = [ ../../modules/core/secrets.nix ];

{ config, pkgs, ... }:

{
  # Point agenix to our secrets configuration
  age.secrets = {
    # GitHub SSH keys for multi-account git setup
    github-ssh-personal = {
      file = ../../secrets/github-ssh-personal.age;
      path = "/home/${config.users.users.sam-laptop.name or config.users.users.sam-framework.name or config.users.users.sam-desktop.name}/.ssh/github-personal";
      owner = config.users.users.sam-laptop.name or config.users.users.sam-framework.name or config.users.users.sam-desktop.name;
      group = "users";
      mode = "0600";
    };

    github-ssh-syntek = {
      file = ../../secrets/github-ssh-syntek.age;
      path = "/home/${config.users.users.sam-laptop.name or config.users.users.sam-framework.name or config.users.users.sam-desktop.name}/.ssh/github-syntek";
      owner = config.users.users.sam-laptop.name or config.users.users.sam-framework.name or config.users.users.sam-desktop.name;
      group = "users";
      mode = "0600";
    };

    github-ssh-missionalgen = {
      file = ../../secrets/github-ssh-missionalgen.age;
      path = "/home/${config.users.users.sam-laptop.name or config.users.users.sam-framework.name or config.users.users.sam-desktop.name}/.ssh/github-missionalgen";
      owner = config.users.users.sam-laptop.name or config.users.users.sam-framework.name or config.users.users.sam-desktop.name;
      group = "users";
      mode = "0600";
    };

    # Future Wireguard keys will be added here in Phase 12
  };

  # Ensure agenix package is available for secret management
  environment.systemPackages = with pkgs; [
    age
  ];
}
