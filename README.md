# Raspberry Pi 3 Home Assistant

A NixOS configuration for Raspberry Pi 3B with Home Assistant, featuring automated deployment and secure secrets management.

## Features

- **Home Assistant** with Matter, Thread, and Zigbee support
- **Mosquitto MQTT** broker with auto-discovery
- **Zigbee2MQTT** for Zigbee device management
- **Pi-hole** DNS ad-blocking
- **Tailscale** VPN mesh networking
- **OpenThread Border Router** for Thread/Matter devices
- **SOPS-encrypted secrets** - safe to commit publicly
- **Remote management** - 100% push-based from your workstation

## Prerequisites

- A Linux system with Nix installed
- Git
- SSH key pair

## Initial Setup

1. **Fork and Clone**
   ```bash
   git clone https://github.com/YOUR_USERNAME/rpi3-nixos-homeassistant.git
   cd rpi3-nixos-homeassistant
   ```

2. **Generate SSH Key** (if needed)
   ```bash
   ssh-keygen -t ed25519 -C "your_email@example.com"
   cat ~/.ssh/id_ed25519.pub
   ```

3. **Configure Settings**

   Edit `settings.nix`:
   - `repoUrl` - Your fork (e.g., `"your-username/rpi3-nixos-homeassistant"`)
   - `hostName` - System hostname (default: `homeassistant`)
   - `adminUser` - Your username
   - `network.*` - Static IP configuration

4. **Configure Secrets**

   Secrets are encrypted with SOPS and safe to commit publicly. Edit on your workstation:
   ```bash
   cd secrets
   ./encrypt
   ```
   This generates an encryption key, opens `secrets.yaml.work` in nano, and encrypts on save.

   Required values (see `secrets.yaml.example`):
   - `user.hashedPassword` - Generate with `mkpasswd -m SHA-512`
   - `user.pubKey` - Your SSH public key from step 2

5. **Commit and Push**
   ```bash
   git add .
   git commit -m "Initial configuration"
   git push
   ```

## Building the SD Image

1. **Build**
   ```bash
   ./build-sd
   ```

2. **Flash to SD Card**
   ```bash
   zstdcat result/sd-image/*.img.zst | sudo dd of=/dev/sdX bs=4M status=progress
   ```
   Replace `/dev/sdX` with your SD card device.

## First Boot

1. Insert SD card and power on the Pi
2. Connect via SSH:
   ```bash
   ssh your_username@homeassistant.local
   # Password: nixos (or as configured in settings.setupPassword)
   ```
3. After first boot, SSH key auth is enabled and password auth is disabled

## System Management

### Remote Deployment

Deploy changes from your workstation via `./deploy <command>`:

```bash
./deploy rebuild        # Rebuild from remote flake
./deploy rebuild-update # Update flake inputs and rebuild
./deploy rebuild-reboot # Rebuild and reboot
./deploy rebuild-log    # View last rebuild log
./deploy system-info    # Show system status
./deploy help           # List all commands
./deploy ssh            # Interactive session
```

### Available Commands

Run directly on the Pi or remotely via `deploy`:

| Command | Description |
|---------|-------------|
| `rebuild` | Rebuild system from remote flake |
| `rebuild-boot` | Rebuild, apply on next reboot |
| `rebuild-reboot` | Rebuild and reboot immediately |
| `rebuild-update` | Update flake inputs and rebuild |
| `rebuild-log` | View last rebuild log |
| `rollback` | Rollback to previous generation |
| `cleanup` | Garbage collect and optimize store |
| `system-info` | Show system status and disk usage |
| `ha-help` | List available commands |

### Editing Secrets

On your workstation (secrets cannot be decrypted on the Pi without the key):
```bash
cd secrets
./decrypt          # Decrypt to secrets.yaml.work
nano secrets.yaml.work
./encrypt          # Re-encrypt changes
```
Commit, push, and `rebuild` to apply.

## Services & Ports

| Service | Port | Notes |
|---------|------|-------|
| Home Assistant | 8123 | `openFirewall = true` |
| Zigbee2MQTT | 8081 | Frontend UI |
| OTBR Web | 8081 | Thread network management |
| Mosquitto | 1883 | MQTT broker (no auth by default) |
| Pi-hole | 53, 80 | DNS + admin UI |
| Tailscale | - | VPN mesh, `openFirewall = true` |
| SSH | 22 | Key-based auth only |

## Project Structure

```
├── flake.nix          # Nix flake entry point
├── settings.nix       # System configuration (hostname, network, etc.)
├── shell.nix          # Development shell
├── build-sd           # SD card image builder
├── deploy             # Remote management script
├── host/
│   ├── configuration.nix  # Boot, networking, SSH, users
│   └── services.nix       # HA, MQTT, Zigbee2MQTT, Pi-hole, etc.
└── secrets/
    ├── .sops.yaml         # SOPS configuration
    ├── secrets.yaml       # Encrypted secrets (safe to commit)
    ├── secrets.yaml.example
    ├── sops.nix           # NixOS SOPS module
    ├── encrypt            # Encryption script
    └── decrypt            # Decryption script
```

## Notable Features

- **Remote Flake** - No local config needed on Pi; rebuilds fetch directly from GitHub
- **Auto-upgrade** - System updates from GitHub weekly with automatic reboot
- **mDNS** - System broadcasts `hostname.local` for easy discovery
- **SOPS Secrets** - Encrypted at rest, decrypted at runtime on the Pi
- **Service Restart** - Weekly restart of all services for stability

## Hardware Notes

- **Zigbee Radio** - Expects USB coordinator at `/dev/ttyACM0` by default
- **Thread Radio** - Configure `threadRadioPath` in `settings.nix` for SkyConnect/ZBT radios
- **RPi3B Memory** - ~1GB RAM limits heavy HA addons; consider RPi4 for more components

## Security Notes

- SSH key authentication only (password disabled after initial setup)
- `secrets.yaml` is encrypted and safe to commit
- Never commit `secrets/key.txt` (gitignored by default)
- Workstation holds the decryption key; Pi only has the key at runtime

## Migrating from secrets.nix

If you're upgrading from the old `secrets.nix` approach:

1. Run `./secrets/encrypt` to set up SOPS
2. Copy values from old `secrets.nix` to `secrets.yaml.work`:
   - `hashedPw` → `user.hashedPassword`
   - Add your SSH public key as `user.pubKey`
3. Move non-secret values (hostname, IP, etc.) to `settings.nix`
4. Delete `secrets.nix` after migration
5. Rebuild the SD image with `./build-sd`
