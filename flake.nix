{
  description = "Minimal NixOS RPi2 HA";

  nixConfig = {
    extra-substituters = [ "https://armv7-community.cachix.org" ];
    extra-trusted-public-keys = [ "armv7-community.cachix.org-1:4RWgBnB/TDvHS3tdP7k6QgrOVOrlR4HJEwhgRfQs3W8=" ];
  };

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, nixos-generators, ... }: let
    system = "armv7l-linux";
    pkgs = import nixpkgs { inherit system; };
    secrets = import ./secrets.nix;
    vars = {
      hostname = secrets.hostname;
      staticIp = secrets.staticIp;
      gateway = secrets.gateway;
      dns = secrets.dns;
      sshUser = secrets.sshUser;
      hashedPw = secrets.hashedPw;
      haPort = secrets.haPort or 8123;
      repoUrl = secrets.repoUrl;
      ipParts = builtins.split "/" secrets.staticIp;
      ipAddr = (builtins.head ipParts).string;
      prefixLen = pkgs.lib.toInt ((builtins.elemAt ipParts 1).string);
    };
  in {
    nixosConfigurations.rpi2 = nixpkgs.lib.nixosSystem {
      inherit system;
      modules = [
        "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-armv7l-multiplatform.nix"
        ({ config, ... }: {
          boot = {
            kernelPackages = pkgs.linuxPackages_rpi2;
            loader.raspberryPi = {
              enable = true;
              version = 2;
            };
          };
          networking = {
            hostName = vars.hostname;
            interfaces.eth0.ipv4.addresses = [{ address = vars.ipAddr; prefixLength = vars.prefixLen; }];
            defaultGateway = vars.gateway;
            nameservers = [ vars.dns ];
          };
          services.openssh = {
            enable = true;
            passwordAuthentication = true;
          };
          users.users.${vars.sshUser} = {
            isNormalUser = true;
            extraGroups = [ "wheel" ];
            hashedPassword = vars.hashedPw;
          };
          security.sudo.wheelNeedsPassword = false;

          services.home-assistant = {
            enable = true;
            autoStart = true;
            openFirewall = true;
            port = vars.haPort;
            config = {
              http.server_port = vars.haPort;
              logger.default = "info";
            };
            extraComponents = [ "default_config" "met" ];
          };

          services.unattended-upgrades = {
            enable = true;
            allowReboot = true;
          };

          # One-touch rebuild script in user's .local/bin
          environment.systemPackages = with pkgs; [
            (writeShellScriptBin "rebuild" ''
              #!/usr/bin/env bash
              set -euo pipefail

              echo "Pulling latest flake from github:${vars.repoUrl}..."
              nix flake update --flake github:${vars.repoUrl}#rpi2

              echo "Rebuilding and switching..."
              sudo nixos-rebuild switch --flake github:${vars.repoUrl}#rpi2

              echo "Done. HA should be live at http://${vars.ipAddr}:${toString vars.haPort}"
            '')
          ];

          system.stateVersion = "25.11";
        })
      ];
    };

    sdImage = nixos-generators.nixosGenerate {
      inherit system;
      modules = [ self.nixosConfigurations.rpi2 ];
      format = "sd-aarch64";
    };
  };
}
