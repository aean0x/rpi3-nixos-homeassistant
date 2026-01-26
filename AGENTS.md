# AGENTS.md

## Overview

Minimal NixOS flake for Raspberry Pi 2 running Home Assistant. Single-file config with secrets separation.

## Architecture

- **flake.nix** - Main config: boot, networking, SSH, HA service, rebuild script
- **secrets.nix** - Local-only credentials/network config (gitignored, must exist for eval)

## Key Patterns

1. **Secrets import at eval time** - `secrets.nix` imported directly, not via sops/agenix. File must exist locally or flake eval fails.

2. **Static IP parsing** - Uses `builtins.split "/" vars.staticIp` assuming CIDR format (`192.168.1.100/24`). Index 0 = address, index 2 = prefix length.

3. **Cachix ARM substituter** - `armv7-community.cachix.org` provides prebuilt ARMv7 binaries. Cache misses = slow local builds on RPi2.

4. **Rebuild script** - Embedded via `writeShellScriptBin`, pulls remote flake but uses local secrets.nix. Avoids secret overwrites on update.

5. **HA config as attrset** - `services.home-assistant.config` mirrors YAML structure. Extend via `extraComponents` and `extraPackages`.

## Gotchas

- SSH password auth enabled by default - disable post-setup
- RPi2 RAM (~1GB) limits heavy HA addons
- `linuxPackages_rpi2` kernel required, no generic ARM
- Unattended upgrades cover NixOS only, not HA itself