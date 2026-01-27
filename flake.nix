{
  description = "Minimal NixOS RPi2 Home Assistant Image";
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
      system = "armv7l-linux";
      pkgs = import nixpkgs { inherit system; };
      secrets = import ./secrets.nix;
      # builtins.split returns [ "192.168.1.100" [ "/" ] "24" ]
      # so index 0 is IP, index 2 is prefix length
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
      nixosConfigurations.rpi2 = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-armv7l-multiplatform.nix"
          (
            { ... }:
            {
              # Allow broken packages (efivar is marked broken on armv7l)
              nixpkgs.config.allowBroken = true;

              # boot.kernelPackages and boot.loader are handled by sd-image-armv7l-multiplatform.nix
              # which uses U-Boot and linuxPackages_latest (works for RPi2)
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
                # Override default extraComponents to exclude default_config which pulls in
                # Matter integration -> python-matter-server -> debugpy (not available on armv7l)
                extraComponents = [
                  "met"
                  "esphome"
                  "rpi_power"
                ];
                config = {
                  http.server_port = vars.haPort;
                  logger.default = "info";
                  # Core integrations (manually specified since we excluded default_config)
                  automation = [ ];
                  counter = { };
                  frontend = { };
                  history = { };
                  input_boolean = { };
                  input_button = { };
                  input_datetime = { };
                  input_number = { };
                  input_select = { };
                  input_text = { };
                  logbook = { };
                  person = { };
                  scene = { };
                  script = { };
                  sun = { };
                  system_health = { };
                  tag = { };
                  timer = { };
                  zone = { };
                };
              };

              system.autoUpgrade = {
                enable = true;
                allowReboot = true;
                flake = "github:${vars.repoUrl}#rpi2";
              };

              # One-touch rebuild script in user's .local/bin
              environment.systemPackages = with pkgs; [
                (writeShellScriptBin "rebuild" ''
                  #!/usr/bin/env bash
                  set -euo pipefail

                  echo "Pulling latest flake from github:${vars.repoUrl}..."
                  nix flake update --flake github:${vars.repoUrl}

                  echo "Rebuilding and switching..."
                  sudo nixos-rebuild switch --flake github:${vars.repoUrl}#rpi2

                  echo "Done. HA should be live at http://${vars.ipAddr}:${toString vars.haPort}"
                '')
              ];

              system.stateVersion = "25.11";
            }
          )
        ];
      };

      # Build SD image using the native NixOS sdImage builder
      # Usage: nix build .#sdImage
      packages.${system}.sdImage = self.nixosConfigurations.rpi2.config.system.build.sdImage;
    };
}
