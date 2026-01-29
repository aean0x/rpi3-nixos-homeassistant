# SOPS secrets configuration
# Decrypted at runtime via sops-nix
{ ... }:
{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets = {
      # User credentials
      "user.hashedPassword" = { };

      # SSH public keys (one file per key, will be concatenated)
      # Each key in the YAML list becomes a separate secret
      "user.pubKeys" = {
        mode = "0444"; # Readable by all (needed for SSH)
      };
    };
  };
}
