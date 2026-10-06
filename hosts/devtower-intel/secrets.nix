{ ... }:

# Agenix secrets for devtower-intel (full stage only, like laptop-intel).
#
# Declared here rather than by importing modules/core/secrets-desktop.nix:
# that module also references *-devtower-intel.age files that do not exist yet
# (LUKS OS key, vault-master-key, server-acme-*), which would fail the build.
# Move entries into secrets-desktop.nix once every one of its files exists.
#
# Bootstrap: these files are encrypted to sam-laptop only (devtowerIntelKeys in
# secrets/secrets.nix), so the host cannot decrypt them until its own key is a
# recipient. Follow docs/INSTALL-INTEL-MANUALLY.md section 8 before switching
# to this stage: create the host key, add it to devtowerIntelKeys on the laptop,
# `just rekey-secrets`, push, pull here, then switch.
# Until then the shared MCP launcher falls back to the credentials it captures
# from /mnt/ubuntu-home into ~/.config/ai-mcp/credentials.json.

let
  username = "sam-desktop";
  hostname = "devtower-intel";
  home = "/home/${username}";

  # Per-device GitHub key, placed where modules/core/ssh-config.nix points the
  # github-<account> host alias (IdentityFile ~/.ssh/github-<host>-<account>).
  githubKey = account: {
    file = ../../secrets/github-ssh-${account}-${hostname}.age;
    path = "${home}/.ssh/github-${hostname}-${account}";
    owner = username;
    group = "users";
    mode = "0600";
  };
in
{
  imports = [ ../../modules/core/typesafe-secret.nix ];

  age.identityPaths = [ "/etc/ssh/ssh_host_ed25519_key" ];

  # agenix installs secrets before users are created and makes a missing parent
  # directory as root, which would leave ~/.ssh root-owned (no known_hosts
  # writes). tmpfiles creates it, or fixes its owner and mode, on every boot and
  # switch.
  systemd.tmpfiles.rules = [ "d ${home}/.ssh 0700 ${username} users -" ];

  age.secrets = {
    # ========================================================================
    # GitHub SSH keys (per-device, no passphrases). Public halves are on the
    # matching GitHub accounts; the private halves only ever live here.
    # ========================================================================
    github-ssh-personal = githubKey "personal";       # SamBailey6194
    github-ssh-syntek = githubKey "syntek";           # syntek-studio
    github-ssh-missionalgen = githubKey "missionalgen"; # sam-missional-gen

    # ========================================================================
    # Claude Code + shared MCP secrets (env file at /run/agenix/claude-secrets)
    #   CLAUDE_MONITOR_TOKEN      claude-code-monitor hook auth (claude.nix)
    #   CONTEXT7_API_KEY          Context7 MCP          (all clients, via the
    #   ELEVENLABS_API_KEY        ElevenLabs MCP         shared launcher in
    #   ELEVENLABS_MCP_BASE_PATH  ElevenLabs file root   mcp-servers.nix)
    #   TYPESAFE_API_KEY         TypeSafe/Jev SDK (with-typesafe command)
    # ========================================================================
    claude-secrets = {
      file = ../../secrets/claude-secrets-${hostname}.age;
      owner = username;
      mode = "0400";
    };

    # ========================================================================
    # AWS CLI config (~/.aws/config, used by `aws sso login`)
    # Decrypted to /run/agenix/aws-config; home/modules/aws.nix symlinks it to
    # ~/.aws/config (not agenix's `path`, which would make ~/.aws root-owned).
    # ========================================================================
    aws-config = {
      file = ../../secrets/aws-config-${hostname}.age;
      owner = username;
      mode = "0400";
    };

    # ~/.aws/credentials (static IAM access keys), linked by aws.nix the same
    # way, whenever this secret is declared.
    aws-credentials = {
      file = ../../secrets/aws-credentials-${hostname}.age;
      owner = username;
      mode = "0400";
    };
  };
}
