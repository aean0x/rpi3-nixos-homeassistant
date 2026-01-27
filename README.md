# rpi3-nixos-homeassistant

Minimal NixOS flake targeting RPi3B (aarch64-linux) with:
- Home Assistant + MQTT discovery
- Zigbee2MQTT (USB coordinator on `/dev/ttyACM0`)
- Mosquitto MQTT broker
- Pi-hole DNS ad-blocking
- Tailscale VPN
- Static IP networking
- SSH access + passwordless sudo
- Auto-upgrade from GitHub flake
- One-touch `rebuild` script

## Setup

### 1. Create secrets.nix

Copy and customize (this file is gitignored):

```nix
{
  hostname = "rpi-ha";
  staticIp = "192.168.1.100/24";  # CIDR format required
  gateway = "192.168.1.1";
  dns = "8.8.8.8";
  sshUser = "admin";
  hashedPw = "$6$...";  # Generate: mkpasswd -m sha-512
  repoUrl = "youruser/rpi3-nixos-homeassistant";  # GitHub repo for auto-upgrade/rebuild
  # Optional:
  haPort = 8123;  # Default if omitted
  tailscaleKey = "/path/to/tskey";  # Auth key file for Tailscale
  piholePwFile = "/path/to/pihole-pw";  # Pi-hole admin password file
}
```

### 2. Build SD Image

```bash
nix build .#packages.aarch64-linux.sdImage
# Output: result/sd-image/*.img
```

Flash to SD card:
```bash
sudo dd if=result/sd-image/*.img of=/dev/sdX bs=4M status=progress
```

### 3. Boot & Access

- Insert SD, power on RPi3
- SSH: `ssh admin@192.168.1.100`
- HA UI: `http://192.168.1.100:8123`

## Services & Ports

| Service | Port | Notes |
|---------|------|-------|
| Home Assistant | 8123 (configurable) | `openFirewall = true` |
| Zigbee2MQTT | 8081 | Frontend UI |
| Mosquitto | 1883 | MQTT broker (no auth by default) |
| Pi-hole | 53, 80 | DNS + admin UI |
| Tailscale | - | VPN mesh, `openFirewall = true` |
| SSH | 22 | Password auth enabled |

## Usage

### Remote Rebuild

On the Pi:
```bash
rebuild
```

Pulls latest flake from `github:${repoUrl}`, rebuilds system, keeps local secrets.

### Extending Home Assistant

Edit `flake.nix` `services.home-assistant`:

```nix
extraComponents = [ "default_config" "met" "zwave_js" ];
extraPackages = ps: [ ps.aiodiscover ];
```

## Security Notes

- **Disable password auth after setup**: Set `passwordAuthentication = false` in `services.openssh`
- **secrets.nix stays local**: Never commit - required at eval time but gitignored

## Architecture

| File | Purpose |
|------|---------|
| `flake.nix` | System config, services |
| `secrets.nix` | Credentials, network |
| `AGENTS.md` | Agent context notes |

## Quirks

- Static IP parsing expects CIDR (`192.168.1.100/24`) - malformed input breaks eval
- RPi3B ~1GB RAM limits heavy HA addons
- `system.autoUpgrade` pulls from `github:${repoUrl}#rpi3` with `allowReboot = true`
- Mosquitto has no auth by default - see inline comment for adding users
- Zigbee2MQTT expects USB coordinator at `/dev/ttyACM0`
- Pi-hole/Tailscale require optional secrets for full functionality
