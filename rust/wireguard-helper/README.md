# wireguard-helper

**Last Updated**: 29/01/2026
**Version**: 0.7.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---
Mullvad WireGuard VPN management tool with multi-hop routing, split tunneling, and automatic server rotation.

## Features

- **Multi-Hop Routing**: Minimum 5-hop chains (1 entry + 3-4 relays + 1 exit)
- **Split Tunneling**: Bypass VPN for LAN and production servers
- **Kill Switch**: Block all traffic if VPN drops
- **Automatic Rotation**: Weekly server rotation (Sunday 3 AM)
- **Exit Location Switching**: UK, US, or EU exit nodes
- **Metrics Logging**: Bandwidth, latency, uptime tracking
- **Per-App VPN Routing**: Route specific apps through VPN via cgroups
- **API Caching**: 6-hour cache to avoid redundant Mullvad API calls
- **Route History**: Avoid reusing servers within 10 rotations

## Commands

### Initialize Device

Generate WireGuard keypair and encrypt to agenix:

```bash
wireguard-helper init <device>
```

Example:
```bash
wireguard-helper init laptop-intel
```

### Rotate Servers

Generate new multi-hop configuration:

```bash
wireguard-helper rotate <device> [--exit uk|us|eu] [--hops 5-10]
```

Examples:
```bash
wireguard-helper rotate laptop-intel
wireguard-helper rotate laptop-intel --exit us --hops 7
```

### Verify Connection

Check VPN status and exit location:

```bash
wireguard-helper verify
```

### Show Status

Display detailed VPN information:

```bash
wireguard-helper status
```

### Switch Exit Location

Change exit location and trigger rotation:

```bash
wireguard-helper set-exit <location>
```

Examples:
```bash
wireguard-helper set-exit uk
wireguard-helper set-exit us
wireguard-helper set-exit eu
```

### View Metrics

Display VPN metrics from log file:

```bash
wireguard-helper metrics [--tail] [--lines N]
```

Examples:
```bash
wireguard-helper metrics --tail --lines 20
wireguard-helper metrics  # Show full log
```

### Launch App via VPN

Route specific application through VPN:

```bash
wireguard-helper vpn-app <command>
```

Examples:
```bash
wireguard-helper vpn-app firefox
wireguard-helper vpn-app transmission-gtk
wireguard-helper vpn-app docker pull ubuntu:latest
```

## Architecture

### Multi-Hop Chain

Build 5+ hop chains by selecting random servers from different countries:

1. **Entry Relay**: European server (non-exit country)
2. **Relay Hops**: 3-4 servers from different countries
3. **Exit Relay**: UK/US/EU based on preference

### API Caching

Mullvad relay list cached for 6 hours at `/var/lib/wireguard/relay-cache.json`.

### Route History

Last 10 rotations tracked at `/var/lib/wireguard/route-history-<device>.json` to avoid repeating servers.

### Metrics Logging

VPN metrics logged every 5 minutes to `/var/log/vpn-logs.txt`:

```
[timestamp] rx_mb=X tx_mb=Y latency=Zms exit=City,Country uptime_min=M handshake=...
```

## Setup Workflow

### 1. Initialize Device

```bash
wireguard-helper init laptop-intel
```

This generates:
- WireGuard keypair
- Encrypted private key in `secrets/wireguard-laptop-intel-private.age`

### 2. Add Public Key to Mullvad

Copy the public key from step 1 and add it at [mullvad.net/account](https://mullvad.net/account).

### 3. Save Account Number

```bash
agenix -e secrets/mullvad-account-laptop-intel.age
```

Paste your Mullvad account number.

### 4. Generate Initial Config

```bash
wireguard-helper rotate laptop-intel
```

### 5. Encrypt Config to Agenix

```bash
cat /tmp/mullvad-wg-config-laptop-intel.tmp | agenix -e secrets/mullvad-wg-config-laptop-intel.age
```

### 6. Rebuild NixOS

```bash
sudo nixos-rebuild switch --flake .#laptop-intel
```

### 7. Start VPN

```bash
sudo systemctl start wg-quick-mullvad0
```

### 8. Verify Connection

```bash
wireguard-helper verify
```

## Dependencies

- `wireguard-tools` - WireGuard CLI tools
- `curl` - IP verification
- `jq` - JSON parsing
- `systemd` - Cgroup routing

## File Locations

- Cache: `/var/lib/wireguard/relay-cache.json`
- Route history: `/var/lib/wireguard/route-history-<device>.json`
- Exit config: `/var/lib/wireguard/exit-location.txt`
- Metrics log: `/var/log/vpn-logs.txt`
- Secrets: `secrets/wireguard-*-private.age`, `secrets/mullvad-*.age`

## Integration with NixOS

This tool is designed to work with the NixOS module at `modules/network/wireguard-mullvad.nix`.

Enable VPN in host configuration:

```nix
networking.wireguard-mullvad = {
  enable = true;
  device = "laptop-intel";
  bypassIPs = [ "203.0.113.5" ];  # Production servers
  enableKillSwitch = true;
  cgroupApps = [ "firefox" "transmission" ];
  currentExit = "uk";
  minHops = 5;
  autoRotate.enable = true;
  metricsLogging.enable = true;
};
```

## Troubleshooting

### VPN won't start

```bash
# Check interface
ip link show mullvad0

# Check systemd service
sudo systemctl status wg-quick-mullvad0

# Check logs
sudo journalctl -u wg-quick-mullvad0
```

### Can't reach internet

```bash
# Verify routing rules
ip rule list

# Check firewall
sudo iptables -L -n

# Check kill switch is not blocking
sudo systemctl stop wg-quick-mullvad0
```

### No metrics logged

```bash
# Check timer
systemctl list-timers | grep vpn-metrics

# Manually trigger
sudo systemctl start vpn-metrics-logger.service

# Check log file
cat /var/log/vpn-logs.txt
```

## License

MIT
