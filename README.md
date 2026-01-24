# NixOS Full Configuration

## Final Project Tree

nix-config/
│
├── flake.nix
├── flake.lock
├── justfile
├── README.md
│
├── hosts/
│ │
│ │ # ─── PHYSICAL DEVICES ───
│ ├── framework/
│ │ ├── configuration.nix
│ │ └── hardware-configuration.nix
│ │
│ ├── devtower/
│ │ ├── configuration.nix
│ │ └── hardware-configuration.nix
│ │
│ │ # ─── LOCAL VMS ───
│ ├── vm-desktop/
│ │ └── configuration.nix
│ │
│ ├── vm-server/
│ │ └── configuration.nix
│ │
│ │ # ─── CLOUD (Phase 8+) ───
│ ├── cloud-staging/
│ │ └── configuration.nix
│ │
│ │ # ─── HOMELAB (Phase 12) ───
│ ├── nas/
│ │ ├── configuration.nix
│ │ └── hardware-configuration.nix
│ │
│ ├── server/
│ │ ├── configuration.nix
│ │ └── hardware-configuration.nix
│ │
│ └── router/
│ ├── configuration.nix
│ └── hardware-configuration.nix
│
├── modules/
│ │
│ ├── core/
│ │ ├── common.nix
│ │ ├── users.nix
│ │ └── nix-settings.nix
│ │
│ ├── desktop/
│ │ ├── hyprland/
│ │ │ ├── default.nix
│ │ │ ├── framework.nix
│ │ │ └── devtower.nix
│ │ ├── openrgb.nix
│ │ └── audio.nix
│ │
│ ├── server/
│ │ ├── nginx.nix
│ │ ├── gunicorn.nix
│ │ ├── cloudflared.nix
│ │ ├── openbao.nix
│ │ └── vaultwarden.nix
│ │
│ ├── networking/
│ │ ├── wireguard/
│ │ │ ├── default.nix
│ │ │ ├── hub.nix
│ │ │ └── client.nix
│ │ ├── tailscale.nix
│ │ ├── mullvad.nix
│ │ └── firewall.nix
│ │
│ └── security/
│ ├── secrets.nix
│ └── rust-wrapper.nix
│
├── home/
│ ├── default.nix
│ ├── shell.nix
│ ├── editor.nix
│ ├── git.nix
│ └── hyprland.nix
│
├── config/
│ │
│ ├── git/
│ │ ├── config
│ │ ├── config-personal
│ │ ├── config-syntek
│ │ ├── config-missional-gen
│ │ ├── gitmessage
│ │ └── hooks/
│ │ └── pre-commit
│ │
│ ├── zsh/
│ │ ├── .zshrc
│ │ ├── .zshenv
│ │ └── aliases.zsh
│ │
│ ├── nvim/
│ │ ├── init.lua
│ │ └── lua/
│ │ ├── options.lua
│ │ ├── keymaps.lua
│ │ ├── autocmds.lua
│ │ └── plugins/
│ │ ├── init.lua
│ │ ├── lsp.lua
│ │ ├── treesitter.lua
│ │ ├── telescope.lua
│ │ ├── cmp.lua
│ │ └── ui.lua
│ │
│ ├── zed/
│ │ ├── settings.json
│ │ ├── keymap.json
│ │ └── debug.json
│ │
│ ├── hypr/
│ │ ├── hyprland.base.conf
│ │ ├── hyprland.framework.conf
│ │ └── hyprland.devtower.conf
│ │
│ ├── waybar/
│ │ ├── config.jsonc
│ │ └── style.css
│ │
│ ├── wofi/
│ │ ├── config
│ │ └── style.css
│ │
│ ├── dunst/
│ │ └── dunstrc
│ │
│ ├── kitty/
│ │ └── kitty.conf
│ │
│ └── starship/
│ └── starship.toml
│
├── secrets/
│ ├── secrets.nix
│ │
│ │ # ─── DEVICE KEYS ───
│ ├── wireguard-framework.age
│ ├── wireguard-devtower.age
│ ├── wireguard-server.age
│ ├── wireguard-nas.age
│ ├── wireguard-router.age
│ │
│ │ # ─── GITHUB SSH ───
│ ├── github-personal-ssh.age
│ ├── github-personal-ssh-passphrase.age
│ ├── github-syntek-ssh.age
│ ├── github-syntek-ssh-passphrase.age
│ ├── github-missionalgen-ssh.age
│ ├── github-missionalgen-ssh-passphrase.age
│ │
│ │ # ─── SERVICES ───
│ ├── cloudflare-tunnel.age
│ ├── cloudflare-api-token.age
│ ├── nginx-basic-auth.age
│ │
│ │ # ─── OPENBAO BOOTSTRAP (Phase 9+) ───
│ ├── vault-token-framework.age
│ ├── vault-token-devtower.age
│ └── vault-token-server.age
│
├── packages/
│ │
│ └── secret-wrapper/
│ ├── Cargo.toml
│ ├── Cargo.lock
│ └── src/
│ ├── main.rs
│ │
│ ├── cli/
│ │ ├── mod.rs
│ │ ├── provision.rs
│ │ ├── get.rs
│ │ ├── set.rs
│ │ ├── rotate.rs
│ │ ├── encrypt.rs
│ │ ├── decrypt.rs
│ │ ├── ssh.rs
│ │ └── api.rs
│ │
│ ├── crypto/
│ │ ├── mod.rs
│ │ ├── engine.rs
│ │ ├── django.rs
│ │ ├── totp.rs
│ │ ├── ip.rs
│ │ ├── tokens.rs
│ │ └── zeroize.rs
│ │
│ ├── vault/
│ │ ├── mod.rs
│ │ ├── client.rs
│ │ └── paths.rs
│ │
│ ├── api_clients/
│ │ ├── mod.rs
│ │ ├── cloudflare.rs
│ │ ├── github.rs
│ │ └── traits.rs
│ │
│ ├── rotation/
│ │ ├── mod.rs
│ │ ├── scheduler.rs
│ │ ├── tls.rs
│ │ ├── tokens.rs
│ │ ├── totp_keys.rs
│ │ └── ip_keys.rs
│ │
│ ├── server/
│ │ ├── mod.rs
│ │ └── socket.rs
│ │
│ └── config/
│ ├── mod.rs
│ └── rotation_policy.rs
│
├── scripts/
│ ├── install.sh
│ ├── bootstrap-secrets.sh
│ └── generate-hardware-config.sh
│
├── docs/
│ ├── SETUP.md
│ ├── SECRETS.md
│ ├── WORKFLOW.md
│ └── TROUBLESHOOTING.md
│
└── linters/
├── .editorconfig
├── .eslintrc.json
├── eslint.config.js
├── .markdownlint.json
├── .prettierrc
├── pyrightconfig.json
└── ruff.toml

## Phase 1: Foundation

Goal: Get NixOS + Hyprland running on one device (framework or devtower)

- Set up nix-config repo structure
- Create flake.nix with basic inputs (nixpkgs, home-manager, agenix, hyprland)
- Write core modules (common.nix, users.nix)
- Write base Hyprland module
- Create first host configuration
- Boot NixOS installer, partition, install
- Clone repo and rebuild with your config
- Get Hyprland working with basic keybinds

Secrets: None yet — just get it booting

## Phase 2: Secrets with agenix

Goal: Manage SSH keys and sensitive config securely

- Set up secrets/secrets.nix with machine host keys
- Create encrypted secrets for GitHub SSH keys (personal, syntek, missionalgen)
- Create encrypted Wireguard keys
- Wire secrets into host configs via age.secrets
- Test that secrets decrypt at boot and land in correct paths

Secrets: GitHub SSH keys, Wireguard keys (all via agenix)

## Phase 3: Second Device

Goal: Framework and devtower both running from same config

- Add second host configuration
- Split Hyprland config into base + device-specific (framework.nix, devtower.nix)
- Add device-specific modules (laptop power management, PC OpenRGB)
- Add second device's host key to secrets.nix
- Rekey secrets so both devices can decrypt shared secrets
- Install NixOS on second device
- Verify both machines rebuild from same repo

Secrets: Same as Phase 2, now decryptable by both devices

## Phase 4: Home Manager + Dotfiles

Goal: Manage user environment declaratively

- Set up Home Manager integration in flake
- Create home modules (shell, editor, hyprland user config)
- Move config files into config/ directory (git, zsh, nvim, zed, hypr)
- Wire Home Manager to symlink configs into place
- Move Hyprland configs to config/hypr/ with base + per-device files

Secrets: Unchanged

## Phase 5: Local VM Testing

Goal: Test config changes before deploying to real hardware

- Add vm-desktop configuration with QEMU virtualisation
- Add vm-server configuration for testing server modules
- Create just commands for building and running VMs
- Establish workflow: change → test in VM → deploy to hardware

Secrets: VMs don't need real secrets — use dummy values or skip

## Phase 6: Wireguard Network

Goal: Connect your devices over VPN

- Write Wireguard module (hub and client variants)
- Decide topology (which device is hub — probably devtower or router later)
- Generate keypairs for each device, store in agenix
- Configure peers in Wireguard module
- Test connectivity between devices over VPN

Secrets: Wireguard private keys for each device

## Phase 7: Server Modules (Prep for Hetzner)

Goal: Build server infrastructure locally so it's ready when you get Hetzner

- Write nginx module
- Write Cloudflare Tunnel module (cloudflared)
- Write gunicorn + uvicorn module
- Test in vm-server locally
- Expose test services through Cloudflare Tunnel (if you have a domain ready)

Secrets: Cloudflare tunnel credentials, nginx basic auth (all agenix)

## Phase 8: Hetzner Staging Environment

Goal: Deploy server config to cloud for staging

- Provision Hetzner VM
- Add cloud-staging host configuration
- Deploy NixOS to Hetzner (nixos-infect or manual install)
- Point Cloudflare Tunnel to staging server
- Test full stack: nginx → gunicorn → app

Secrets: Same agenix secrets, staging VM added to secrets.nix

## Phase 9: OpenBao Setup

Goal: Migrate from agenix-only to OpenBao for runtime secrets

- Deploy OpenBao on Hetzner server
- Initialise and unseal OpenBao
- Create secret structure (devices, services, keys)
- Migrate secrets from agenix to OpenBao (keep agenix for bootstrap token only)
- Write basic Rust wrapper (provision command)
- Test: device boots → agenix decrypts OpenBao token → Rust fetches remaining secrets

Secrets: Bootstrap token in agenix, everything else in OpenBao

## Phase 10: Rust Wrapper Expansion

Goal: Full secrets management via Rust

- Add CLI commands (get, set, list, ssh)
- Add encryption modules (Django-compatible, TOTP, IP)
- Add API clients (Cloudflare, GitHub)
- Add rotation scheduler (TLS, signing keys)
- Integrate with NixOS (systemd service, provision before other services start)
- Add Unix socket server for other services to query secrets

Secrets: All managed via OpenBao, accessed via Rust wrapper

## Phase 11: Production Workflow

Goal: Proper CI/CD pipeline

- Establish branch strategy (feature → dev → staging → main)
- Add GitHub Actions for building and testing configs
- Staging deploys automatically on merge to staging branch
- Production (main) requires manual approval or tag
- Devices pull from main: nixos-rebuild switch --flake github:user/nix-config#hostname

## Phase 12: Additional Infrastructure

Goal: Expand to full homelab

- Add NAS configuration
- Add router configuration (if running NixOS on router)
- Add Raspberry Pi configuration (if applicable)
- Integrate Tailscale or expand Wireguard mesh
- Add Mullvad exit node on server
- Add Vaultwarden for password management
