# Mullvad VPN Setup with WireGuard

**Last Updated**: 29/01/2026
**Version**: 0.7.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

## Quick Start

**Time**: 5-10 minutes

```bash
# 1. Enter dev shell
cd /etc/nixos/nix-config
nix develop

# 2. Initialize VPN for your device
wireguard-helper init laptop-intel
# Output: Shows your WireGuard public key

# 3. Add public key to Mullvad account
# Go to: https://mullvad.net/account → WireGuard configuration
# Paste the public key shown above

# 4. Save Mullvad account number
agenix -e secrets/mullvad-account-laptop-intel.age
# Paste your account number (e.g., 1234567890123456)

# 5. Generate VPN configuration (2-hop: entry → exit)
just vpn-rotate laptop-intel
# Follow instructions to encrypt config with agenix

# 6. Rebuild system
just rebuild

# 7. Start VPN
just vpn-up

# 8. Verify connection
just vpn-verify
```

**Expected output**:

```
✅ VPN interface is up
✅ Connected via Mullvad
   Exit IP: 185.x.x.x
   Location: London, GB
✅ WireGuard handshake successful
```

---

## Prerequisites

1. ✅ NixOS installed and running
2. ✅ Mullvad account created at [mullvad.net](https://mullvad.net)
3. ✅ This repository cloned to `/etc/nixos/nix-config`
4. ✅ Secrets management configured (follow `SECRETS.md` first)

---

## Setup Guide

### Step 1: Enter Development Shell

The dev shell includes all VPN tools:

```bash
cd /etc/nixos/nix-config
nix develop
# Auto-builds: wireguard-helper CLI
```

### Step 2: Generate WireGuard Keys for Your Device

Initialize VPN for your specific device:

```bash
wireguard-helper init laptop-intel
```

**Output**:

```
Generated WireGuard keys for laptop-intel:

Private Key: ...
Public Key: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI...

⚠️  IMPORTANT: Add this public key to your Mullvad account
   Go to: https://mullvad.net/account → WireGuard configuration
   Then run: just vpn-rotate laptop-intel
```

Copy the public key.

### Step 3: Add Public Key to Mullvad Account

1. Go to: [mullvad.net/account](https://mullvad.net/account)
2. Navigate to "WireGuard configuration"
3. Click "Generate key" or "Add key"
4. Paste the public key from Step 2
5. Save

### Step 4: Save Mullvad Account Number

Create a secret with your Mullvad account number:

```bash
# Get your account number from Mullvad account page
agenix -e secrets/mullvad-account-laptop-intel.age
```

**In the editor**:

- Paste your 16-digit account number (e.g., `1234567890123456`)
- Save and exit (Ctrl+D in nano, :wq in vim)

**Agenix will encrypt it** and save as `secrets/mullvad-account-laptop-intel.age`.

### Step 5: Generate VPN Configuration (2-Hop Multi-Hop)

```bash
# Generate 2-hop multi-hop configuration (entry → exit)
just vpn-rotate laptop-intel
```

**Output**:

```
Generating 2-hop Mullvad WireGuard configuration for laptop-intel:

Entry relay: Amsterdam (NL)
Exit server: London (GB)

Configuration saved to: /tmp/mullvad-wg-config-laptop-intel.tmp

⚠️  Encrypt this config with agenix:

cat /tmp/mullvad-wg-config-laptop-intel.tmp | \
  agenix -e secrets/mullvad-wg-config-laptop-intel.age
```

**Follow the instructions** shown to encrypt the configuration:

```bash
cat /tmp/mullvad-wg-config-laptop-intel.tmp | \
  agenix -e secrets/mullvad-wg-config-laptop-intel.age
```

This encrypts the WireGuard config and saves it as `.age` file (safe to commit to git).

### Step 6: Update secrets/secrets.nix

Add entries for your VPN secrets to `secrets/secrets.nix`:

```nix
{
  "mullvad-account-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
  "mullvad-wg-config-laptop-intel.age".publicKeys = allUsers ++ [ laptop-intel ];
}
```

### Step 7: Enable VPN Module

Edit your host configuration (e.g., `hosts/laptop-intel/configuration.nix`):

```nix
imports = [
  ../../modules/network/wireguard-mullvad.nix
];

networking.wireguard-mullvad = {
  enable = true;              # Enable VPN module
  device = "laptop-intel";    # Your device name

  enableKillSwitch = true;    # Block traffic if VPN down

  currentExit = "uk";         # Exit location (uk/us/eu)

  autoRotate.enable = true;   # Weekly rotation (Sunday 3 AM)
  metricsLogging.enable = true; # Log every 5 minutes
};
```

### Step 8: Rebuild System

```bash
sudo nixos-rebuild switch --flake .#laptop-intel
```

Agenix will:

1. Decrypt VPN secrets
2. Configure WireGuard interface
3. Set up routing rules
4. Enable kill switch firewall
5. Start VPN service

### Step 9: Start VPN

```bash
just vpn-up
```

### Step 10: Verify Connection

```bash
just vpn-verify
```

**Expected output**:

```
✅ VPN interface is up
✅ Connected via Mullvad
   Exit IP: 185.x.x.x
   Location: London, GB
✅ WireGuard handshake successful
```

---

## Daily Usage

### Start/Stop VPN

```bash
just vpn-up       # Start VPN
just vpn-down     # Stop VPN
just vpn-restart  # Restart VPN
```

### Check Status

```bash
just vpn-status   # Detailed status (connections, routing, firewall)
just vpn-verify   # Quick connection check
```

### Switch Exit Location

```bash
just vpn-set-exit uk    # Switch to UK exit
just vpn-set-exit us    # Switch to US exit
just vpn-set-exit eu    # Switch to EU exit (NL/DE/FR/SE)
```

This automatically rotates servers and rebuilds.

### Rotate Servers Manually

```bash
just vpn-rotate laptop-intel  # Generate new 2-hop config
just rebuild                  # Apply configuration
just vpn-restart              # Restart VPN
```

**Note**: Automatic rotation happens every Sunday at 3 AM.

### Launch Apps Through VPN

```bash
just vpn-app firefox          # Firefox routes through VPN
just vpn-app transmission     # BitTorrent through VPN
just vpn-app docker pull      # Docker operations through VPN
```

### View Metrics

```bash
just vpn-metrics              # Last 20 log entries
journalctl -fu wireguard-metrics  # Real-time monitoring
```

---

## Architecture

### Network Routing

The VPN uses custom routing tables to separate:

- **LAN traffic** (bypasses VPN, direct to local network)
- **VPN traffic** (routed through WireGuard multi-hop chain)
- **Kill switch** (blocks all traffic if VPN is down)

### Routing Tables

| Table        | Purpose        | CIDR           | Priority |
| ------------ | -------------- | -------------- | -------- |
| `local`      | System routes  | N/A            | N/A      |
| `main`       | Default routes | N/A            | N/A      |
| `1000` (vpn) | VPN traffic    | 0.0.0.0/0      | 100      |
| LAN bypass   | Local networks | 192.168.0.0/16 | 50       |

### Multi-Hop Chain (2-Hop)

Mullvad WireGuard supports **2-hop multi-hop**: traffic enters at one server and exits at another. The entry relay only sees your IP, the exit server only sees the entry relay — neither has the full picture.

```
Your Device
    ↓ (encrypted tunnel)
Entry Relay (Amsterdam) — connects to exit via multihop_port
    ↓
Exit Server (London) → Internet
```

**Why 2-hop?**

- Entry relay sees your IP but not your traffic destination
- Exit server sees your traffic but not your real IP
- Mullvad cannot correlate entry and exit without cross-referencing logs
- This is the maximum hop count Mullvad's WireGuard infrastructure supports

> **Future: Custom Multi-Hop VPN** — For chains beyond 2 hops, we plan to deploy self-hosted WireGuard relay servers across multiple providers (Hetzner, DigitalOcean, Linode, etc.), each managed as a NixOS host in this flake. This will enable route-specific tunnelling with 3+ hops (e.g., Device → self-hosted relay → Mullvad entry → Mullvad exit). See Phase 12 planning.

### Kill Switch

If VPN connection drops, firewall rules block:

- ✅ Internet traffic (prevent leaks)
- ✅ Allow LAN access (local network still works)
- ✅ Allow VPN handshake traffic (to reconnect)

### Split Tunneling

```
LAN (192.168.0.0/16)
    ↓ Direct (no VPN)
    ↓ Bypass firewall
    ↓ Keep working if VPN down

Internet (0.0.0.0/0)
    ↓ Through VPN
    ↓ Multi-hop routing
    ↓ Blocked by kill switch if down
```

---

## Configuration

### Per-Device Settings

Edit `hosts/laptop-intel/configuration.nix`:

```nix
networking.wireguard-mullvad = {
  # Enable/disable
  enable = true;

  # Device name (must match folder name)
  device = "laptop-intel";

  # Production servers bypass VPN (optional)
  bypassIPs = [
    # "203.0.113.5"    # Example: production server
    # "203.0.113.6"    # Add as needed
  ];

  # Kill switch (block traffic if VPN down)
  enableKillSwitch = true;

  # Exit location
  currentExit = "uk";     # uk, us, eu

  # Per-app VPN routing (route specific apps through VPN)
  cgroupApps = [
    "firefox"           # Browse through VPN
    "transmission"      # Torrent through VPN
  ];

  # Automatic rotation
  autoRotate = {
    enable = true;      # Enable weekly rotation
    day = "Sunday";     # Day of week
    hour = 3;           # Hour of day (UTC)
  };

  # Metrics logging
  metricsLogging = {
    enable = true;      # Log VPN metrics
    interval = 5;       # Minutes between logs
  };
};
```

### Disable Kill Switch (Not Recommended)

```nix
enableKillSwitch = false;
```

⚠️ **Warning**: Without kill switch, all traffic leaks if VPN drops!

### Change Exit Location

```nix
currentExit = "us";  # Switch to US
```

Then: `sudo nixos-rebuild switch --flake .#laptop-intel`

### Add More Apps to Per-App VPN

```nix
cgroupApps = [
  "firefox"
  "transmission"
  "docker"           # Add your apps
  "wget"
];
```

---

## Testing

### Test VPN Connection

```bash
just vpn-verify
```

Output should show exit IP location.

### Test LAN Access (Should Work - Bypass VPN)

```bash
ping 192.168.1.1      # Should work (LAN is bypassed)
ping 192.168.1.100    # Should work (LAN is bypassed)
```

### Test Internet (Should Route Through VPN)

```bash
curl ipinfo.io/country  # Should return "GB" (exit location)
curl ipinfo.io/ip       # Should show exit IP (not your real IP)
```

### Test Kill Switch

```bash
# Stop VPN
just vpn-down

# Try to access internet (should fail immediately)
curl google.com
# Should timeout or connection refused (kill switch blocking)

# LAN should still work
ping 192.168.1.1
# Should work (LAN is allowed)

# Restore internet
just vpn-up
```

### Test Per-App VPN Routing

```bash
# Check which apps are configured
grep cgroupApps hosts/laptop-intel/configuration.nix

# Launch app through VPN
just vpn-app firefox

# Test inside Firefox
curl ipinfo.io/country  # Should show exit location
```

### View Real-Time Metrics

```bash
journalctl -fu wireguard-metrics
```

Metrics logged every 5 minutes:

- Connected clients
- Data sent/received
- Handshake status
- Routing table state

---

## Troubleshooting

### VPN Won't Connect

**Check logs**:

```bash
sudo journalctl -u wg-quick-mullvad0 -n 50
sudo journalctl -u wireguard-metrics -n 50
```

**Common causes**:

- Mullvad account number is wrong
- WireGuard keys are invalid
- Public key not added to Mullvad account
- Network connectivity issue

**Solution**:

```bash
# Verify Mullvad account
cat /run/agenix/mullvad-account-laptop-intel

# Check WireGuard interface
ip link show mullvad0

# Restart VPN service
sudo systemctl restart wg-quick-mullvad0
```

### Can't Access Internet

**Check kill switch**:

```bash
sudo iptables -L -n | grep -i wireguard
```

**Check routing**:

```bash
ip rule list
ip route list table 1000
```

**Temporarily disable kill switch**:

```nix
enableKillSwitch = false;
sudo nixos-rebuild switch --flake .#laptop-intel
just vpn-up
```

### Metrics Not Logging

**Check timer**:

```bash
systemctl list-timers | grep wireguard
```

**Check logs**:

```bash
cat /var/log/vpn-logs.txt
```

**Restart service**:

```bash
sudo systemctl restart wireguard-metrics.timer
```

### VPN Too Slow

**Reasons**:

- Multi-hop adds some latency (entry + exit)
- Exit server is geographically far
- Network congestion

**Solutions**:

```bash
# Rotate to different servers
just vpn-rotate laptop-intel
just rebuild
just vpn-restart

# Change exit location (closer geography)
just vpn-set-exit us   # Try different location
```

### Apps Not Routing Through VPN

**Check configuration**:

```bash
grep cgroupApps hosts/laptop-intel/configuration.nix
```

**Check if app is running**:

```bash
ps aux | grep firefox
```

**Verify cgroup setup**:

```bash
cat /proc/self/cgroup | grep net_cls
```

**Restart cgroup service**:

```bash
sudo systemctl restart wireguard-cgroups.service
just vpn-app firefox  # Try again
```

---

## Reference

### Just Commands

| Command                        | Purpose                |
| ------------------------------ | ---------------------- |
| `just vpn-up`                  | Start VPN              |
| `just vpn-down`                | Stop VPN               |
| `just vpn-status`              | Detailed status        |
| `just vpn-verify`              | Quick connection check |
| `just vpn-restart`             | Restart VPN            |
| `just vpn-set-exit uk`         | Switch to UK exit      |
| `just vpn-set-exit us`         | Switch to US exit      |
| `just vpn-rotate laptop-intel` | Generate new config    |
| `just vpn-app firefox`         | Launch Firefox via VPN |
| `just vpn-metrics`             | View metrics log       |

### Rust Tools (in `nix develop`)

| Tool                       | Purpose                 |
| -------------------------- | ----------------------- |
| `wireguard-helper init`    | Generate WireGuard keys |
| `wireguard-helper rotate`  | Rotate VPN servers      |
| `wireguard-helper status`  | Show VPN status         |
| `wireguard-helper verify`  | Verify connection       |
| `wireguard-helper metrics` | Display metrics         |

### File Locations

| Path                              | Purpose                    |
| --------------------------------- | -------------------------- |
| `secrets/mullvad-account-*.age`   | Encrypted account number   |
| `secrets/mullvad-wg-config-*.age` | Encrypted WireGuard config |
| `/etc/wireguard/mullvad0.conf`    | Active WireGuard config    |
| `/run/wireguard/`                 | Runtime WireGuard state    |
| `/var/log/vpn-logs.txt`           | VPN metrics log            |
| `~/.ssh/mullvad-priv-key`         | Private WireGuard key      |

### Systemd Services

| Service                     | Purpose              |
| --------------------------- | -------------------- |
| `wg-quick-mullvad0`         | WireGuard interface  |
| `wireguard-metrics.timer`   | Metrics logging      |
| `wireguard-metrics.service` | Metrics job          |
| `wireguard-firewall`        | Kill switch firewall |
| `wireguard-cgroups.service` | Per-app VPN routing  |

---

## Next Steps

1. **Complete Setup**: Follow the 10-step setup guide above
2. **Test All Features**: Follow the testing section
3. **Configure Auto-Rotation**: Set up weekly server rotation
4. **Per-App VPN**: Add apps to `cgroupApps` list
5. **Multi-Device**: Repeat setup for framework, devtower

## Security Notes

- ✅ 2-hop multi-hop (entry + exit) prevents provider correlation
- ✅ Kill switch prevents IP leaks
- ✅ Per-device keys contain blast radius
- ✅ Encrypted secrets in git (agenix)
- ✅ Split tunneling keeps LAN functional
- ✅ Route history prevents repeated servers

## Mullvad VPN Inforamtion

**Laptop-Intel**
Name: sharp oyster
IPv4: 10.74.122.237/32
IPv6: fc00:bbbb:bbbb:bb01::b:7aec/128

## Support

- **Mullvad**: [mullvad.net/support](https://mullvad.net/support)
- **WireGuard**: [wireguard.com](https://wireguard.com)
- **NixOS**: [nixos.org](https://nixos.org)
- **This Project**: `rust/wireguard-helper/README.md`
