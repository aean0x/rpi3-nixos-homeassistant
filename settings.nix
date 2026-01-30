# System settings - edit for your setup
# Secrets (passwords) go in secrets/secrets.yaml
let
  repoUrl = "aean0x/rpi3-nixos-homeassistant"; # Format: "owner/repo"
  parts = builtins.split "/" repoUrl;
in
{
  # System identification
  hostName = "homeassistant";
  description = "Raspberry Pi 3 Home Assistant";
  timeZone = "Europe/Berlin";

  # Admin user
  adminUser = "user";

  # SSH configuration
  # When true, allows password auth using hashedPassword from secrets/secrets.yaml
  # When false, only SSH key authentication is allowed
  allowPasswordAuth = false;

  # SSH public keys for authentication (one per line)
  # Get your key with: cat ~/.ssh/id_ed25519.pub
  sshPubKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICB8EtGX5PD1QPF/jrdd5G+fQy4tV2L3fhCY1dhZc4ep aean@nix-pc"
    # "ssh-ed25519 AAAA... user@laptop"
  ];

  # Repository coordinates (parsed from repoUrl)
  inherit repoUrl;
  repoOwner = builtins.elemAt parts 0;
  repoName = builtins.elemAt parts 2;

  # Network configuration (static IP)
  network = {
    interface = "eth0";
    address = "192.168.1.100";
    prefixLength = 24;
    gateway = "192.168.1.1";
    dns = "1.1.1.1";
  };

  # Service ports
  haPort = 8123;
  otbrPort = 8082;
  matterPort = 5580;
  piholeWebPort = 3000;
  piholeDnsPort = 53;
  homepagePort = 80;

  # Hardware
  # Find with: ls /dev/serial/by-id/
  # Example: /dev/serial/by-id/usb-Nabu_Casa_SkyConnect_v1.0_xxxxx-if00-port0
  threadRadioPath = "/dev/serial/by-id/usb-Nabu_Casa_ZBT-2_DCB4D910EF08-if00";
  zigbeeRadioPath = "/dev/ttyACM0";

  # System
  stateVersion = "25.11";
}
