# rpi2-nixos-homeassistant

NixOS-declared Home Assistant setup for a single-purpose Raspberry Pi 2B build managed remotely.

## Overview

Minimal NixOS flake targeting RPi2 ARMv7 with:
- Home Assistant service
- Static IP networking
- SSH access
- One-touch remote rebuild

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
  haPort = 8123;
}
```

### 2. Build SD Image

```bash
nix build .#sdImage
# Output: result/sd-image/*.img
```

Flash to SD card:
```bash
sudo dd if=result/sd-image/*.img of=/dev/sdX bs=4M status=progress
```

### 3. Boot & Access

- Insert SD, power on RPi2
- SSH: `ssh admin@192.168.1.100`
- HA UI: `http://192.168.1.100:8123`

## Usage

### Remote Rebuild

On the Pi:
```bash
rebuild
```

Pulls latest flake from remote, rebuilds system, keeps local secrets.

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
- Cachix ARM substituter hits ~80-90% cache; misses = slow RPi2 builds
- RPi2 ~1GB RAM limits heavy HA addons
- Unattended upgrades cover NixOS only, not HA itself