# SOPS secrets configuration
# Decrypted at runtime via sops-nix
{ ... }:
{
  sops = {
    defaultSopsFile = ./secrets.yaml;
    age.keyFile = "/var/lib/sops-nix/key.txt";

    secrets = {
      # User password (used when allowPasswordAuth is enabled in settings.nix)
      user_hashedPassword = { };

      # Tailscale auth key for automatic network join
      # Generate at: https://login.tailscale.com/admin/settings/keys
      # Recommended: Reusable + Pre-authorized for declarative rebuilds
      tailscale_authKey = { };
    };
  };
}
