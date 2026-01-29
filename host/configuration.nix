# Base system configuration for Raspberry Pi 3 Home Assistant
# Handles: boot, networking, SSH, users
{
  config,
  settings,
  ...
}:

{
  imports = [
    ../secrets/sops.nix
    ./scripts.nix
  ];

  # ===================
  # Networking
  # ===================
  networking = {
    hostName = settings.hostName;
    interfaces.${settings.network.interface}.ipv4.addresses = [
      {
        address = settings.network.address;
        prefixLength = settings.network.prefixLength;
      }
    ];
    defaultGateway = settings.network.gateway;
    nameservers = [ settings.network.dns ];
    firewall.allowedTCPPorts = [
      settings.mqttPort
      settings.zigbee2mqttPort
    ];
  };

  # ===================
  # SSH & Remote Access
  # ===================
  services.openssh = {
    enable = true;
    settings.PasswordAuthentication = settings.allowPasswordAuth;
    settings.PermitRootLogin = "no";
  };

  # mDNS for hostname.local resolution
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    publish.enable = true;
    publish.addresses = true;
  };

  # ===================
  # User Configuration
  # ===================
  users.users.${settings.adminUser} = {
    isNormalUser = true;
    description = settings.description;
    extraGroups = [ "wheel" ];
    # Password from SOPS (used when allowPasswordAuth is true)
    hashedPasswordFile = config.sops.secrets."user.hashedPassword".path;
    # SSH keys from SOPS (multi-line file with one key per line)
    openssh.authorizedKeys.keyFiles = [ config.sops.secrets."user.pubKeys".path ];
  };

  security.sudo.wheelNeedsPassword = false;

  # ===================
  # Boot Configuration
  # ===================
  boot.loader.generic-extlinux-compatible.configurationLimit = 3;
  boot.kernelParams = [ "dtparam=watchdog=on" ];

  system.stateVersion = settings.stateVersion;
}
