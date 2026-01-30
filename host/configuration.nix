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
    hashedPasswordFile = config.sops.secrets.user_hashedPassword.path;
    # SSH keys from settings.nix
    openssh.authorizedKeys.keys = settings.sshPubKeys;
  };

  security.sudo.wheelNeedsPassword = false;

  # ===================
  # Swap & Memory (required for rebuilds on RPi3's limited RAM)
  # ===================
  # Disk swap for heavy operations (Nix rebuilds)
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 2048; # 2GB
    }
  ];

  # zram for daily operation (compressed RAM swap, reduces SD card wear)
  zramSwap = {
    enable = true;
    memoryPercent = 50; # Use up to 50% of RAM for zram
    algorithm = "zstd"; # Good compression ratio
  };

  # ===================
  # Boot Configuration
  # ===================
  boot.loader.generic-extlinux-compatible.configurationLimit = 3;
  boot.kernelParams = [ "dtparam=watchdog=on" ];

  # ===================
  # Nix Configuration
  # ===================
  nix.settings.trusted-users = [ "@wheel" ];

  # ===================
  # System
  # ===================
  time.timeZone = settings.timeZone;
  system.stateVersion = settings.stateVersion;
}
