{
  description = "Minimal NixOS RPi3B Home Assistant Image";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-otbr.url = "github:mrene/nixpkgs/openthread-border-router";
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-otbr,
      ...
    }:
    let
      system = "aarch64-linux";
      pkgs = import nixpkgs { inherit system; };
      lib = pkgs.lib;

      # Load secrets from local file (gitignored)
      secrets = import ./secrets.nix;

      # Parse CIDR notation (e.g., "192.168.1.100/24") into address and prefix length
      parseCidr =
        cidr:
        let
          parts = builtins.split "/" cidr;
        in
        {
          address = builtins.elemAt parts 0;
          prefixLength = lib.strings.toInt (builtins.elemAt parts 2);
        };

      # Parsed IP configuration
      ipConfig = parseCidr secrets.staticIp;

      # All configuration variables in one place
      vars = {
        # Network
        hostname = secrets.hostname;
        ipAddress = ipConfig.address;
        prefixLength = ipConfig.prefixLength;
        gateway = secrets.gateway;
        dns = secrets.dns;

        # User
        sshUser = secrets.sshUser;
        hashedPw = secrets.hashedPw;

        # Services
        haPort = secrets.haPort or 8123;
        repoUrl = secrets.repoUrl;

        # Hardware
        threadRadioPath = secrets.threadRadioPath or "/dev/serial/by-id/usb-your-thread-radio-id";
      };

    in
    {
      nixosConfigurations.rpi3 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"

          # Import the OTBR module from mrene's nixpkgs fork
          "${nixpkgs-otbr}/nixos/modules/services/home-automation/openthread-border-router.nix"

          (
            { ... }:
            let
              # Get the openthread-border-router package from the fork
              pkgs-otbr = import nixpkgs-otbr { inherit system; };
            in
            {
              # ===================
              # Networking
              # ===================
              networking = {
                hostName = vars.hostname;
                interfaces.eth0.ipv4.addresses = [
                  {
                    address = vars.ipAddress;
                    prefixLength = vars.prefixLength;
                  }
                ];
                defaultGateway = vars.gateway;
                nameservers = [ vars.dns ];
                firewall.allowedTCPPorts = [
                  1883 # Mosquitto MQTT
                  8081 # Zigbee2MQTT frontend / OTBR web
                ];
              };

              # ===================
              # SSH & Users
              # ===================
              services.openssh = {
                enable = true;
                settings.PasswordAuthentication = true;
              };

              users.users.${vars.sshUser} = {
                isNormalUser = true;
                extraGroups = [ "wheel" ];
                hashedPassword = vars.hashedPw;
              };

              security.sudo.wheelNeedsPassword = false;

              # ===================
              # Home Assistant
              # ===================
              # default_config, met, esphome, rpi_power already included by module on ARM
              services.home-assistant = {
                enable = true;
                openFirewall = true;
                extraComponents = [
                  "matter"
                  "thread"
                  "otbr"
                  "zha"
                  "mqtt"
                  "systemmonitor"
                  "uptime"
                  "glances"
                  "pi_hole"
                  "tailscale"
                ];
                config = {
                  http.server_port = vars.haPort;
                  logger.default = "info";
                  mqtt = {
                    broker = "localhost";
                    discovery = true;
                  };
                };
              };

              # ===================
              # Mosquitto MQTT
              # ===================
              # No auth by default for local use
              # To add auth: listeners = [{ users.myuser = { password = "secret"; acl = ["readwrite #"]; }; }];
              services.mosquitto = {
                enable = true;
                listeners = [
                  {
                    acl = [ "pattern readwrite #" ];
                    omitPasswordAuth = true;
                    settings.allow_anonymous = true;
                  }
                ];
              };

              # ===================
              # Zigbee2MQTT
              # ===================
              # homeassistant auto-enabled, permit_join=false, serial=/dev/ttyACM0 are defaults
              services.zigbee2mqtt = {
                enable = true;
                settings.frontend.port = 8081;
              };

              # ===================
              # Tailscale VPN
              # ===================
              # Run `tailscale up` after first boot to authenticate
              services.tailscale = {
                enable = true;
                openFirewall = true;
              };

              # ===================
              # Pi-hole DNS
              # ===================
              services.pihole-ftl = {
                enable = true;
                openFirewallDNS = true;
                openFirewallWebserver = true;
                settings.dns.upstreams = [ vars.dns ];
              };

              services.pihole-web = {
                enable = true;
                ports = [ 80 ];
              };

              # ===================
              # OpenThread Border Router (OTBR)
              # ===================
              # For Thread/Matter support with USB radios (SkyConnect, ZBT-1, ZBT-2)
              services.openthread-border-router = {
                enable = true;
                package = pkgs-otbr.openthread-border-router;
                backboneInterface = "eth0";
                radio = {
                  device = vars.threadRadioPath;
                  baudRate = 460800;
                  flowControl = true; # Required for SkyConnect/ZBT radios
                };
                web = {
                  enable = true;
                  listenPort = 8081; # Must be 8081 for frontend to work correctly
                };
              };

              # ===================
              # Auto-upgrade
              # ===================
              system.autoUpgrade = {
                enable = true;
                allowReboot = true;
                flake = "github:${vars.repoUrl}#rpi3";
                dates = "Sun *-*-* 03:00:00";
              };

              # ===================
              # Service Restart Timer
              # ===================
              systemd.timers.restart-services = {
                wantedBy = [ "timers.target" ];
                timerConfig = {
                  OnCalendar = "Sun *-*-* 03:30:00";
                  Persistent = true;
                };
              };

              systemd.services.restart-services = {
                script = ''
                  systemctl restart home-assistant.service mosquitto.service zigbee2mqtt.service tailscaled.service pihole-ftl.service otbr-agent.service otbr-web.service || true
                '';
                serviceConfig.Type = "oneshot";
              };

              # ===================
              # Boot Configuration
              # ===================
              boot.loader.generic-extlinux-compatible.configurationLimit = 3;
              boot.kernelParams = [ "dtparam=watchdog=on" ];

              # ===================
              # System Packages
              # ===================
              environment.systemPackages = with pkgs; [
                # OTBR tools for manual Thread network management
                pkgs-otbr.openthread-border-router

                (writeShellScriptBin "rebuild" ''
                  #!/usr/bin/env bash
                  set -euo pipefail
                  echo "Pulling latest flake from github:${vars.repoUrl}..."
                  nix flake update --flake github:${vars.repoUrl}
                  echo "Rebuilding and switching..."
                  sudo nixos-rebuild switch --flake github:${vars.repoUrl}#rpi3
                  echo "Done. HA should be live at http://${vars.ipAddress}:${toString vars.haPort}"
                '')
              ];

              system.stateVersion = "25.11";
            }
          )
        ];
      };

      packages.${system}.sdImage = self.nixosConfigurations.rpi3.config.system.build.sdImage;
    };
}
