{
  description = "Minimal NixOS RPi3B Home Assistant Image";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
  };
  outputs =
    {
      self,
      nixpkgs,
      ...
    }:
    let
      system = "aarch64-linux";
      pkgs = import nixpkgs { inherit system; };
      secrets = import ./secrets.nix;
      ipParts = builtins.split "/" secrets.staticIp;
      vars = {
        hostname = secrets.hostname;
        staticIp = secrets.staticIp;
        gateway = secrets.gateway;
        dns = secrets.dns;
        sshUser = secrets.sshUser;
        hashedPw = secrets.hashedPw;
        haPort = secrets.haPort or 8123;
        repoUrl = secrets.repoUrl;
        ipAddr = builtins.elemAt ipParts 0;
        prefixLen = pkgs.lib.strings.toInt (builtins.elemAt ipParts 2);
      };
    in
    {
      nixosConfigurations.rpi3 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"
          (
            { ... }:
            {
              networking = {
                hostName = vars.hostname;
                interfaces.eth0.ipv4.addresses = [
                  {
                    address = vars.ipAddr;
                    prefixLength = vars.prefixLen;
                  }
                ];
                defaultGateway = vars.gateway;
                nameservers = [ vars.dns ];
                firewall.allowedTCPPorts = [ 1883 8081 ];
              };
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
              services.home-assistant = {
                enable = true;
                openFirewall = true;
                extraComponents = [
                  "default_config"
                  "matter"
                  "thread"
                  "otbr"
                  "zha"
                  "met"
                  "esphome"
                  "rpi_power"
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
              services.mosquitto = {
                enable = true;
                listeners = [ { address = "0.0.0.0"; } ];
                # Add auth: users.${secrets.mqttUser} = { password = secrets.mqttPw; acl = ["readwrite #"]; };
              };
              services.zigbee2mqtt = {
                enable = true;
                settings = {
                  homeassistant = true;
                  permit_join = false;
                  serial.port = "/dev/ttyACM0";
                  frontend = {
                    enable = true;
                    port = 8081;
                  };
                };
              };
              services.tailscale = {
                enable = true;
                openFirewall = true;
                # authKeyFile = secrets.tailscaleKey or null;
              };
              services.pi-hole = {
                enable = true;
                openFirewall = true;
                # adminPasswordFile = secrets.piholePwFile or null;
                interfaces = [ "eth0" ];
                dns.upstream = [ vars.dns ];
              };
              system.autoUpgrade = {
                enable = true;
                allowReboot = true;
                flake = "github:${vars.repoUrl}#rpi3";
                dates = "Sun *-*-* 03:00:00";
              };
              systemd.timers.restart-services = {
                wantedBy = [ "timers.target" ];
                timerConfig = {
                  OnCalendar = "Sun *-*-* 03:30:00";
                  Persistent = true;
                };
              };
              systemd.services.restart-services = {
                script = ''
                  systemctl restart home-assistant.service mosquitto.service zigbee2mqtt.service tailscale.service pi-hole.service || true
                '';
                serviceConfig.Type = "oneshot";
              };
              boot.loader.generic-extlinux-compatible.configurationLimit = 3;
              boot.kernelParams = [ "dtparam=watchdog=on" ];
              environment.systemPackages = with pkgs; [
                (writeShellScriptBin "rebuild" ''
                  #!/usr/bin/env bash
                  set -euo pipefail
                  echo "Pulling latest flake from github:${vars.repoUrl}..."
                  nix flake update --flake github:${vars.repoUrl}
                  echo "Rebuilding and switching..."
                  sudo nixos-rebuild switch --flake github:${vars.repoUrl}#rpi3
                  echo "Done. HA should be live at http://${vars.ipAddr}:${toString vars.haPort}"
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
