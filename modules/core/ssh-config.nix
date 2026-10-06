{ config, pkgs, lib, ... }:

# SSH Configuration Module
# Generates SSH config using per-device keys for GitHub and servers
#
# Benefits:
# - Each device uses its own SSH key
# - Device compromise only exposes that device's credentials
# - Independent key rotation per device
# - Automatic config generation from hostname

let
  # Get the current hostname to determine which keys to use
  hostname = config.networking.hostName;

  # GitHub account configurations
  githubAccounts = [
    {
      name = "personal";
      host = "github-personal";
      user = "git";
      hostname = "github.com";
      identityFile = "~/.ssh/github-${hostname}-personal";
    }
    {
      name = "syntek";
      host = "github-syntek";
      user = "git";
      hostname = "github.com";
      identityFile = "~/.ssh/github-${hostname}-syntek";
    }
    {
      name = "missionalgen";
      host = "github-missionalgen";
      # Older clones (made on Ubuntu) still use git@github-mg: remotes.
      aliases = [ "github-mg" ];
      user = "git";
      hostname = "github.com";
      identityFile = "~/.ssh/github-${hostname}-missionalgen";
    }
  ];

  # Generate SSH config entry for a GitHub account
  generateGitHubConfig = account: ''
    # GitHub ${account.name} account
    Host ${lib.concatStringsSep " " ([ account.host ] ++ account.aliases or [ ])}
      HostName ${account.hostname}
      User ${account.user}
      IdentityFile ${account.identityFile}
      IdentitiesOnly yes
      AddKeysToAgent yes
  '';

  # Generate SSH config for all GitHub accounts
  githubSSHConfig = lib.concatMapStringsSep "\n" generateGitHubConfig githubAccounts;

in
{
  # Enable SSH agent for managing keys
  programs.ssh.startAgent = true;

  # Add SSH client package
  environment.systemPackages = with pkgs; [
    openssh
  ];

  # Write the host blocks into the NixOS-generated /etc/ssh/ssh_config itself:
  # it does not Include /etc/ssh/ssh_config.d/*, so a file there is never read.
  # mkAfter keeps them after any top-level Include lines other modules put in
  # extraConfig; the global block goes last so the per-host values win.
  programs.ssh.extraConfig = lib.mkMerge [
    (lib.mkAfter ''
      # ============================================================================
      # Auto-Generated SSH Config (Per-Device Keys)
      # Device: ${hostname}
      # ============================================================================

      ${githubSSHConfig}

      # ============================================================================
      # Server Configurations (Add per-device server keys here)
      # ============================================================================

      # Example: Client ACME Server
      # Host client-acme
      #   HostName acme.example.com
      #   User root
      #   IdentityFile ~/.ssh/server-acme-${hostname}-key
      #   IdentitiesOnly yes
      #   AddKeysToAgent yes
    '')
    (lib.mkOrder 2000 ''
      # ============================================================================
      # Global SSH Settings
      # ============================================================================

      # Use SSH keys from ssh-agent when available
      Host *
        AddKeysToAgent yes
        ServerAliveInterval 60
        ServerAliveCountMax 3
        # Disable HashKnownHosts for easier management
        HashKnownHosts no
    '')
  ];

  # GitHub's published host keys (https://api.github.com/meta, checked against
  # ssh-keyscan fingerprints), so the github-* aliases never prompt on first use.
  programs.ssh.knownHosts = lib.mapAttrs' (type: publicKey:
    lib.nameValuePair "github.com-${type}" {
      hostNames = [ "github.com" ];
      inherit publicKey;
    }) {
      ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOMqqnkVzrm0SdG6UOoqKLsabgH5C9okWi0dh2l9GKJl";
      ecdsa = "ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=";
      rsa = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQCj7ndNxQowgcQnjshcLrqPEiiphnt+VTTvDP6mHBL9j1aNUkY4Ue1gvwnGLVlOhGeYrnZaMgRK6+PKCUXaDbC7qtbW8gIkhL7aGCsOr/C56SJMy/BCZfxd1nWzAOxSDPgVsmerOBYfNqltV9/hWCqBywINIR+5dIg6JTJ72pcEpEjcYgXkE2YEFXV1JHnsKgbLWNlhScqb2UmyRkQyytRLtL+38TGxkxCflmO+5Z8CSSNY7GidjMIZ7Q4zMjA2n1nGrlTDkzwDCsw+wqFPGQA179cnfGWOWRVruj16z6XyvxvjJwbz0wQZ75XK5tKSb7FNyeIEs4TT4jk+S4dhPeAUC5y+bDYirYgM4GC7uEnztnZyaVWQ7B381AK4Qdrwt51ZqExKbQpTUNn+EjqoTwvqNj4kqx5QUCI0ThS/YkOxJCXmPUWZbhjpCg56i+2aB6CmK2JGhn57K5mj0MNdBXA4/WnwH6XoPWJzK5Nyu2zB3nAZp+S5hpQs+p1vN1/wsjk=";
    };
}
