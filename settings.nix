# System settings - edit for your setup
# Secrets (passwords, SSH keys) go in secrets/secrets.yaml
let
  repoUrl = "aean0x/rpi3-nixos-homeassistant"; # Format: "owner/repo"
  parts = builtins.split "/" repoUrl;
in
{
  # System identification
  hostName = "homeassistant";
  description = "Raspberry Pi 3 Home Assistant";

  # Admin user
  adminUser = "user";

  # SSH configuration
  # When true, allows password auth using hashedPassword from secrets/secrets.yaml
  # When false, only SSH key authentication is allowed
  allowPasswordAuth = false;

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
  zigbee2mqttPort = 8081;
  otbrPort = 8081;
  mqttPort = 1883;

  # Hardware
  # Find with: ls /dev/serial/by-id/
  # Example: /dev/serial/by-id/usb-Nabu_Casa_SkyConnect_v1.0_xxxxx-if00-port0
  threadRadioPath = "/dev/serial/by-id/usb-your-thread-radio-id";
  zigbeeRadioPath = "/dev/ttyACM0";

  # System
  stateVersion = "25.11";
}
