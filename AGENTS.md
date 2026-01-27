# AGENTS.md

## Overview

Minimal NixOS flake for Raspberry Pi 3B (aarch64-linux) running Home Assistant with Zigbee, MQTT, Pi-hole, and Tailscale. Single-file config with secrets separation.

## Architecture

- **flake.nix** - `nixosConfigurations.rpi3`: sd-image-aarch64.nix, networking, SSH, HA, Mosquitto, Zigbee2MQTT, Tailscale, Pi-hole, autoUpgrade, rebuild script
- **secrets.nix** - Local-only credentials/network config (gitignored, must exist for eval)

## Services Stack

- **Home Assistant** - Port 8123 (configurable), MQTT discovery enabled, extensive extraComponents
- **Mosquitto** - Port 1883, no auth by default (see inline comment for user setup)
- **Zigbee2MQTT** - Port 8081 frontend, expects USB coordinator at `/dev/ttyACM0`
- **Pi-hole** - DNS ad-blocking on eth0, requires `piholePwFile` secret for admin
- **Tailscale** - VPN mesh, requires `tailscaleKey` secret for auth

## Key Patterns

1. **Secrets import at eval time** - `secrets.nix` imported directly, not via sops/agenix. File must exist locally or flake eval fails.

2. **Optional secrets with `or null`** - `tailscaleKey`, `piholePwFile` use `secrets.field or null` pattern for optional fields.

3. **Static IP parsing** - `builtins.split "/" secrets.staticIp` expects CIDR format. Index 0 = address, index 2 = prefix length.

4. **Firewall** - Explicit `allowedTCPPorts = [ 1883 8081 ]` + per-service `openFirewall = true` for HA, Tailscale, Pi-hole.

5. **Auto-upgrade** - `system.autoUpgrade` pulls `github:${vars.repoUrl}#rpi3` with `allowReboot = true`.

6. **Rebuild script** - `writeShellScriptBin "rebuild"` runs `nix flake update` then `nixos-rebuild switch` against remote flake. Local secrets.nix preserved.

7. **HA config as attrset** - `services.home-assistant.config` mirrors YAML structure. MQTT broker set to localhost with discovery.

## Gotchas

- SSH password auth + passwordless sudo enabled by default - harden post-setup
- RPi3B RAM (~1GB) limits heavy HA addons
- Mosquitto has no auth - add users via inline comment pattern before exposing externally
- Zigbee2MQTT `permit_join = false` by default - enable temporarily via frontend when pairing
- Auto-upgrade covers NixOS only, not HA integrations/HACS
- `repoUrl` required in secrets.nix for rebuild/autoUpgrade to function