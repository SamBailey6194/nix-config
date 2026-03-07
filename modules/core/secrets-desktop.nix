# Desktop-specific secrets configuration
# Use this for devtower host

{ config, ... }:

let
  # Determine username based on which user exists
  username =
    if config.users.users ? sam-desktop then "sam-desktop"
    else throw "No recognized desktop user found";

  hostname = config.networking.hostName;
in
{
  # Configure agenix to use the system SSH host key
  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  age.secrets = {
    # ========================================================================
    # GitHub SSH Keys (per-device, no passphrases)
    # Decrypted to ~/.ssh/ for SSH config to reference
    # ========================================================================
    github-ssh-personal = {
      file = ../../secrets/github-ssh-personal-${hostname}.age;
      path = "/home/${username}/.ssh/github-${hostname}-personal";
      owner = username;
      group = "users";
      mode = "0600";
    };

    github-ssh-syntek = {
      file = ../../secrets/github-ssh-syntek-${hostname}.age;
      path = "/home/${username}/.ssh/github-${hostname}-syntek";
      owner = username;
      group = "users";
      mode = "0600";
    };

    github-ssh-missionalgen = {
      file = ../../secrets/github-ssh-missionalgen-${hostname}.age;
      path = "/home/${username}/.ssh/github-${hostname}-missionalgen";
      owner = username;
      group = "users";
      mode = "0600";
    };

    # ========================================================================
    # LUKS Passphrase (fallback when TPM2 auto-unlock fails)
    # ========================================================================
    luks-passphrase = {
      file = ../../secrets/luks-passphrase-${hostname}.age;
      mode = "0400";
    };

    # ========================================================================
    # Malware Scanner Quarantine Key (256-bit AES-GCM)
    # ========================================================================
    malware-scanner-quarantine-key = {
      file = ../../secrets/malware-scanner-quarantine-key-${hostname}.age;
      mode = "0400";
    };

    # ========================================================================
    # Per-Folder Encryption Master Key (gocryptfs recovery)
    # ========================================================================
    vault-master-key = {
      file = ../../secrets/vault-master-key-${hostname}.age;
      owner = username;
      mode = "0400";
    };

    # ========================================================================
    # Server SSH Keys (per-device, with passphrases)
    # ========================================================================
    server-acme-key = {
      file = ../../secrets/server-acme-${hostname}-key.age;
      path = "/home/${username}/.ssh/server-acme-${hostname}-key";
      owner = username;
      group = "users";
      mode = "0600";
    };

    server-acme-passphrase = {
      file = ../../secrets/server-acme-${hostname}-passphrase.age;
      owner = username;
      mode = "0400";
    };

    # ========================================================================
    # Wi-Fi Passwords (shared across all devices)
    # TODO: Uncomment when wifi-passwords.age is created
    # ========================================================================
    # wifi-passwords = {
    #   file = ../../secrets/wifi-passwords.age;
    #   mode = "0400";
    # };
  };
}
