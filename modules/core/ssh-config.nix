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
      user = "git";
      hostname = "github.com";
      identityFile = "~/.ssh/github-${hostname}-missionalgen";
    }
  ];

  # Generate SSH config entry for a GitHub account
  generateGitHubConfig = account: ''
    # GitHub ${account.name} account
    Host ${account.host}
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

  # Write SSH config to /etc/ssh/ssh_config.d/
  # This applies system-wide SSH configuration
  environment.etc."ssh/ssh_config.d/99-nix-config.conf".text = ''
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
  '';
}
