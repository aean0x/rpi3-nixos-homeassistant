{
  description = "NixOS configuration for Raspberry Pi 3 Home Assistant";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      sops-nix,
      ...
    }@inputs:
    let
      settings = import ./settings.nix;
      system = "aarch64-linux";
      unstable = import nixpkgs-unstable { inherit system; };

      # Key file path for SD image (passed via environment)
      keyFilePath = builtins.getEnv "KEY_FILE_PATH";
      keyContent = if keyFilePath != "" then builtins.readFile keyFilePath else "";
    in
    {
      # Main system configuration
      nixosConfigurations.rpi3 = nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {
          inherit
            inputs
            settings
            unstable
            ;
        };
        modules = [
          # SD image support for RPi3
          "${nixpkgs}/nixos/modules/installer/sd-card/sd-image-aarch64.nix"

          # SOPS secrets
          sops-nix.nixosModules.sops

          # System configuration
          ./host/configuration.nix
          ./host/services.nix
          ./host/homepage.nix

          # Inject SOPS key into SD image (only when KEY_FILE_PATH is set during build)
          (
            { ... }:
            {
              system.activationScripts.setupSopsKey =
                if keyContent != "" then
                  ''
                    mkdir -p /var/lib/sops-nix
                    echo "${keyContent}" > /var/lib/sops-nix/key.txt
                    chmod 600 /var/lib/sops-nix/key.txt
                  ''
                else
                  ""; # No-op when not building SD image
            }
          )
        ];
      };

      # SD image output
      packages.${system}.sdImage = self.nixosConfigurations.rpi3.config.system.build.sdImage;
    };
}
