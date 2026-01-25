# Quick Start: Mullvad VPN Setup

## Prerequisites

1. ✅ NixOS installed on laptop-intel
2. ✅ Mullvad account created at [mullvad.net](https://mullvad.net)
3. ✅ This repository cloned to `/etc/nixos/nix-config`

## 5-Minute Setup

### Step 1: Enter Dev Shell

```bash
cd /etc/nixos/nix-config
nix develop
```

### Step 2: Initialize VPN for Device

```bash
wireguard-helper init laptop-intel
```

**Output**: Shows your WireGuard public key. Copy it!

### Step 3: Add Public Key to Mullvad

1. Go to [mullvad.net/account](https://mullvad.net/account)
2. Navigate to "WireGuard configuration"
3. Paste your public key
4. Save

### Step 4: Save Mullvad Account Number

```bash
agenix -e secrets/mullvad-account-laptop-intel.age
```

Paste your Mullvad account number (e.g., `1234567890123456`), save and exit.

### Step 5: Generate VPN Configuration

```bash
just vpn-rotate laptop-intel
```

This selects 5 random Mullvad servers (1 entry + 3 relays + 1 UK exit).

**Follow the instructions** to encrypt the config to agenix:
```bash
cat /tmp/mullvad-wg-config-laptop-intel.tmp | \
  agenix -e secrets/mullvad-wg-config-laptop-intel.age
```

### Step 6: Rebuild NixOS

```bash
just rebuild
```

Wait ~2 minutes for rebuild to complete.

### Step 7: Start VPN

```bash
just vpn-up
```

### Step 8: Verify Connection

```bash
just vpn-verify
```

**Expected**:
```
✅ VPN interface is up
✅ Connected via Mullvad
   Exit IP: 185.x.x.x
   Location: London, GB
✅ WireGuard handshake successful
```

## Daily Usage

### Start/Stop VPN

```bash
just vpn-up      # Start VPN
just vpn-down    # Stop VPN
just vpn-restart # Restart VPN
```

### Check Status

```bash
just vpn-status  # Detailed status
just vpn-verify  # Quick connection check
```

### Switch Exit Location

```bash
just vpn-set-exit us  # Switch to US exit
just vpn-set-exit uk  # Switch to UK exit
just vpn-set-exit eu  # Switch to EU exit (NL/DE/FR/SE)
```

This automatically rotates servers and rebuilds.

### Rotate Servers Manually

```bash
just vpn-rotate laptop-intel  # Generate new 5-hop config
just rebuild                  # Apply configuration
just vpn-restart              # Restart VPN
```

**Note**: Automatic rotation happens every Sunday at 3 AM.

### Launch Apps Through VPN

```bash
just vpn-app firefox          # Firefox through VPN
just vpn-app transmission     # Torrents through VPN
just vpn-app docker pull ...  # Docker through VPN
```

### View Metrics

```bash
just vpn-metrics  # Last 20 log entries
```

## Testing Split Tunneling

### Test LAN Access (Bypass VPN)

```bash
ping 192.168.1.1  # Should work (LAN bypass)
```

### Test Internet (Through VPN)

```bash
curl ipinfo.io/country  # Should return "GB" (UK exit)
```

### Test Kill Switch

```bash
just vpn-down           # Stop VPN
curl google.com         # Should timeout (kill switch blocks)
ping 192.168.1.1        # Should work (LAN allowed)
just vpn-up             # Restore internet
```

## Troubleshooting

### VPN Won't Connect

```bash
sudo journalctl -u wg-quick-mullvad0 -n 50  # Check logs
sudo systemctl restart wg-quick-mullvad0    # Restart service
```

### Can't Access Internet

```bash
ip rule list              # Check routing rules
sudo iptables -L -n       # Check firewall
```

### Metrics Not Logging

```bash
cat /var/log/vpn-logs.txt  # Check log file
systemctl list-timers      # Verify timer is active
```

## Configuration

VPN settings in `hosts/laptop-intel/configuration.nix`:

```nix
networking.wireguard-mullvad = {
  enable = true;              # Enable VPN
  device = "laptop-intel";    # Device name

  bypassIPs = [               # Production servers bypass VPN
    # "203.0.113.5"
  ];

  enableKillSwitch = true;    # Block traffic if VPN down

  cgroupApps = [              # Apps through VPN
    "firefox"
    "transmission"
  ];

  currentExit = "uk";         # Exit location (uk/us/eu)
  minHops = 5;                # Minimum hop count

  autoRotate.enable = true;   # Weekly rotation (Sunday 3 AM)
  metricsLogging.enable = true; # Log every 5 minutes
};
```

Modify and run `just rebuild` to apply changes.

## Support

- **Full Documentation**: `PHASE-6-WIREGUARD-MULLVAD.md`
- **Tool Reference**: `rust/wireguard-helper/README.md`
- **Project Overview**: `CLAUDE.md`
- **All Commands**: `just --list`

## Quick Reference Card

| Command | Description |
|---------|-------------|
| `just vpn-up` | Start VPN |
| `just vpn-down` | Stop VPN |
| `just vpn-status` | Show detailed status |
| `just vpn-verify` | Quick connection check |
| `just vpn-set-exit uk` | Switch to UK exit |
| `just vpn-rotate laptop-intel` | Generate new config |
| `just vpn-app firefox` | Launch Firefox via VPN |
| `just vpn-metrics` | View metrics log |

**Automatic Features**:
- ✅ Weekly server rotation (Sunday 3 AM)
- ✅ Metrics logging every 5 minutes
- ✅ Kill switch (blocks traffic if VPN down)
- ✅ Split tunneling (LAN bypass)
- ✅ API caching (6 hours)

**Security**:
- ✅ Minimum 5-hop chains
- ✅ Per-device secrets (agenix encrypted)
- ✅ Route history (avoid repeating servers)
- ✅ Kill switch (prevent IP leaks)

Enjoy your secure, multi-hop VPN! 🔒🌍
