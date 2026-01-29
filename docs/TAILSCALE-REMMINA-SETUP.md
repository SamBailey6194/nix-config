# Tailscale + Remmina Setup Guide

**Last Updated**: 29/01/2026
**Version**: 0.9.0
**Maintained By**: Development Team
**Language**: British English (en_GB)
**Timezone**: Europe/London

---

Complete guide for remote desktop access to client computers using Tailscale VPN and Remmina.

## Overview

**Tailscale** creates a secure mesh VPN network, allowing you to access client computers from anywhere as if they were on the same local network.

**Remmina** is a remote desktop client that supports VNC, RDP, and SSH protocols.

**Use Case**: Connect to clients' computers remotely to provide support, regardless of their physical location.

## Architecture

```
Your PC (NixOS)           Client Computer
┌─────────────────┐      ┌─────────────────┐
│  Remmina Client │      │  x11vnc Server  │
│  (VNC Client)   │◄────►│  (VNC Server)   │
└─────────────────┘      └─────────────────┘
         │                        │
         └────────────────────────┘
              Tailscale VPN
         (Encrypted mesh network)
```

## Installation

Already configured in your NixOS system! After rebuilding, you'll have:
- ✅ Tailscale service enabled
- ✅ Remmina remote desktop client installed
- ✅ Firewall rules configured
- ✅ Available on all hosts (laptop-intel, framework, devtower)

## Initial Setup

### 1. Authenticate Tailscale

After rebuilding your system, authenticate with Tailscale:

```bash
# Start Tailscale (should auto-start on boot)
sudo systemctl start tailscaled

# Authenticate (opens browser for login)
sudo tailscale up

# Check status
tailscale status

# Show your Tailscale IP
tailscale ip -4
```

**First-time setup:**
1. The `tailscale up` command will provide a URL
2. Open the URL in your browser
3. Log in with your Tailscale account (Google, Microsoft, etc.)
4. Approve the device

### 2. Verify Tailscale Connection

```bash
# List all devices on your Tailscale network
tailscale status

# Ping another device (by name or IP)
ping client-computer.tailnet-xyz.ts.net

# Or use Tailscale IP directly
ping 100.x.x.x
```

## Client Computer Setup

On each client computer you want to access:

### 1. Install Tailscale

**Ubuntu/Debian:**
```bash
curl -fsSL https://tailscale.com/install.sh | sh
sudo tailscale up
```

**Windows:**
- Download from https://tailscale.com/download/windows
- Install and log in

**macOS:**
- Download from https://tailscale.com/download/mac
- Install and log in

### 2. Install x11vnc (Linux clients)

**Ubuntu/Debian:**
```bash
sudo apt update
sudo apt install x11vnc

# Set VNC password
x11vnc -storepasswd
# Enter password twice (you'll use this in Remmina)
```

### 3. Start x11vnc Server

**Manual start (for testing):**
```bash
x11vnc -display :0 -auth guess -forever -loop -noxdamage -repeat -rfbauth ~/.vnc/passwd -rfbport 5900 -shared
```

**Auto-start on login (Ubuntu):**
Create `~/.config/autostart/x11vnc.desktop`:
```ini
[Desktop Entry]
Type=Application
Name=x11vnc
Exec=x11vnc -display :0 -auth guess -forever -loop -noxdamage -repeat -rfbauth /home/USERNAME/.vnc/passwd -rfbport 5900 -shared
Hidden=false
NoDisplay=false
X-GNOME-Autostart-enabled=true
```

Replace `USERNAME` with actual username.

### 4. Windows Clients (Alternative: RDP)

Windows has RDP built-in, no need for x11vnc:

1. Enable Remote Desktop:
   - Settings → System → Remote Desktop → Enable
2. Note the computer name
3. Use Remmina with RDP protocol (port 3389)

## Using Remmina

### 1. Launch Remmina

```bash
# From terminal
remmina

# Or press Super+D and search "Remmina"
```

### 2. Create New Connection

1. Click **+** (New connection)
2. **Name**: Client Name (e.g., "John's Laptop")
3. **Protocol**: VNC or RDP
   - VNC for Linux (port 5900)
   - RDP for Windows (port 3389)
4. **Server**: Tailscale hostname or IP
   - Format: `client-computer.tailnet-xyz.ts.net:5900`
   - Or: `100.x.x.x:5900` (Tailscale IP)
5. **Username**: (for RDP only)
6. **Password**: VNC password or RDP password
7. Click **Save**

### 3. Connect

1. Double-click the saved connection
2. Enter password if prompted
3. You're now controlling the client's desktop!

### 4. Remmina Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `Ctrl+Alt+F` | Toggle fullscreen |
| `Ctrl+Alt+M` | Minimize |
| `Ctrl+Alt+K` | Grab keyboard |
| `Ctrl+Alt+T` | Take screenshot |
| `Ctrl+Alt+D` | Disconnect |

## Tailscale Management

### View Connected Devices

```bash
tailscale status
```

Example output:
```
100.101.102.103  laptop-intel         sam@        linux   -
100.101.102.104  client-laptop        john@       linux   -
100.101.102.105  client-desktop       jane@       windows -
```

### Share Your Computer (Optional)

If you want clients to connect TO your computer:

1. Uncomment x11vnc section in `modules/network/remote-desktop.nix`
2. Rebuild system
3. Set VNC password: `x11vnc -storepasswd`
4. VNC server will auto-start on login

### Exit Nodes (Optional)

Use Tailscale as VPN for internet traffic:

```bash
# List available exit nodes
tailscale exit-node list

# Use an exit node
tailscale up --exit-node=<node-name>

# Disable exit node
tailscale up --exit-node=
```

### Disconnect from Tailscale

```bash
# Disconnect (but keep daemon running)
sudo tailscale down

# Reconnect
sudo tailscale up
```

## Troubleshooting

### Tailscale Not Connecting

**Check service status:**
```bash
sudo systemctl status tailscaled
```

**Restart Tailscale:**
```bash
sudo systemctl restart tailscaled
sudo tailscale up
```

**Check logs:**
```bash
journalctl -u tailscaled -f
```

### Can't Connect to Client Computer

**Verify Tailscale connectivity:**
```bash
# Ping the client
ping client-computer.tailnet-xyz.ts.net

# Check if VNC port is open
nc -zv 100.x.x.x 5900
```

**On client computer, verify x11vnc is running:**
```bash
ps aux | grep x11vnc
```

**Check firewall on client:**
```bash
# Ubuntu
sudo ufw status
sudo ufw allow from 100.0.0.0/8 to any port 5900

# Tailscale should automatically configure firewall
```

### Remmina Connection Fails

**Error: "Unable to connect to VNC server"**
- Verify x11vnc is running on client
- Check VNC password is correct
- Verify Tailscale IP is correct

**Error: "Connection refused"**
- Check VNC port (5900) is correct
- Verify x11vnc is listening: `netstat -tlnp | grep 5900`

**Slow performance:**
- In Remmina, change Quality to "Poor" for faster response
- Reduce color depth to 8-bit or 16-bit

### Firewall Issues

**If Tailscale traffic is blocked:**

```bash
# Check firewall status
sudo firewall-cmd --list-all
# or
sudo ufw status

# Tailscale should be on trusted interface (tailscale0)
# This is already configured in modules/network/tailscale.nix
```

## Security Best Practices

### ✅ DO:
- Use strong VNC passwords
- Only allow VNC connections from Tailscale network
- Keep Tailscale client updated
- Use MFA on Tailscale account
- Regularly audit connected devices

### ❌ DON'T:
- Don't expose VNC port (5900) to public internet
- Don't use weak/default passwords
- Don't share Tailscale credentials
- Don't leave x11vnc running when not needed (on client computers)

## Advanced Configuration

### Custom VNC Port

Edit x11vnc command to use different port:
```bash
x11vnc ... -rfbport 5901
```

Then in Remmina, connect to `100.x.x.x:5901`

### SSH Tunneling (Extra Security Layer)

Even with Tailscale, you can add SSH tunnel:
```bash
# On your PC
ssh -L 5900:localhost:5900 user@client-computer.tailnet-xyz.ts.net

# In Remmina, connect to localhost:5900
```

### Tailscale ACLs (Access Control Lists)

Control which devices can access which devices:

1. Go to https://login.tailscale.com/admin/acls
2. Define rules (example):
```json
{
  "acls": [
    {
      "action": "accept",
      "src": ["laptop-intel"],
      "dst": ["*:*"]
    }
  ]
}
```

## Mullvad Integration

Since you already have Mullvad VPN via Wireguard, you can:

**Option 1: Use Mullvad exit nodes in Tailscale (requires Mullvad Tailscale integration)**

**Option 2: Use both separately**
- Mullvad for general internet privacy
- Tailscale for accessing client computers
- They work independently

## References

- [Tailscale Documentation](https://tailscale.com/kb/)
- [Remmina Wiki](https://gitlab.com/Remmina/Remmina/-/wikis/home)
- [x11vnc Documentation](http://www.karlrunge.com/x11vnc/)

## Related Files

- `modules/network/tailscale.nix` - Tailscale configuration
- `modules/network/remote-desktop.nix` - Remmina + x11vnc configuration
- `hosts/*/configuration-full.nix` - Host configurations with Tailscale enabled
