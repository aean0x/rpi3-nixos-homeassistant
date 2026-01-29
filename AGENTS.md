# AGENTS.md

## Overview

NixOS flake for Raspberry Pi 3B (aarch64-linux) running Home Assistant with Zigbee, MQTT, Pi-hole, Tailscale, and Thread/Matter support. Remote-managed with SOPS-encrypted secrets.

## Architecture

```
├── flake.nix              # Entry point: nixosConfigurations.rpi3 + rpi3-sd
├── settings.nix           # Non-secret config (hostname, network, ports)
├── shell.nix              # Dev shell with age, sops, nix tools
├── build-sd               # SD image builder (injects SOPS key)
├── deploy                 # Remote management wrapper
├── host/
│   ├── configuration.nix  # Boot, networking, SSH, users, management scripts
│   └── services.nix       # HA, Mosquitto, Zigbee2MQTT, Pi-hole, Tailscale, OTBR
└── secrets/
    ├── .sops.yaml         # Age key configuration
    ├── secrets.yaml       # Encrypted secrets (safe to commit)
    ├── sops.nix           # NixOS SOPS module integration
    ├── encrypt            # Key generation + encryption script
    └── decrypt            # Decryption for editing
```

## Services Stack

- **Home Assistant** - Port 8123, MQTT discovery, Matter/Thread/Zigbee components
- **Mosquitto** - Port 1883, no auth by default
- **Zigbee2MQTT** - Port 8081 frontend, USB coordinator
- **Pi-hole** - DNS 53, web UI 80
- **Tailscale** - VPN mesh networking
- **OpenThread Border Router** - Thread/Matter support via SkyConnect/ZBT radios

## Key Patterns

1. **SOPS secrets** - `secrets/secrets.yaml` encrypted with age, decrypted at runtime via sops-nix. Key at `/var/lib/sops-nix/key.txt`.

2. **Settings vs Secrets split**:
   - `settings.nix` - hostname, network config, ports, radio paths (committed)
   - `secrets/secrets.yaml` - hashedPassword, SSH pubKey (encrypted, committed)

3. **Two flake outputs**:
   - `rpi3` - Main system config for rebuilds
   - `rpi3-sd` - SD image with password auth + key injection for initial setup

4. **Remote management** - `./deploy <cmd>` runs commands via SSH. All changes pushed from workstation, never edit on Pi.

5. **Management scripts** - `rebuild`, `rebuild-update`, `rebuild-reboot`, `rollback`, `cleanup`, `system-info`, `ha-help` available on host.

6. **Auto-upgrade** - Weekly pull from `github:${repoUrl}#rpi3` with `allowReboot = true`.

7. **pkgs-otbr injection** - OTBR packages from mrene/nixpkgs fork passed via `specialArgs`.

## Secrets Schema

```yaml
user:
    hashedPassword: "$6$..."  # mkpasswd -m SHA-512
    pubKey: "ssh-ed25519 AAAA..."  # SSH public key
```

## Workflow

1. Edit `settings.nix` or `secrets/` on workstation
2. `cd secrets && ./encrypt` if secrets changed
3. `git commit && git push`
4. `./deploy rebuild` or `./deploy rebuild-update`

## Gotchas

- SD image uses password auth (`setupPassword`) for initial setup only
- SSH key auth only after first rebuild from GitHub
- RPi3B RAM (~1GB) limits heavy HA addons
- Mosquitto has no auth - add users before exposing externally
- Zigbee2MQTT `permit_join = false` by default
- OTBR and Zigbee2MQTT share port 8081 - may need adjustment
- `threadRadioPath` must match actual USB device path (use `ls /dev/serial/by-id/`)
- Auto-upgrade covers NixOS only, not HA integrations/HACS