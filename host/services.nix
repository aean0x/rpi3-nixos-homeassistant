{
  config,
  settings,
  ...
}:
{
  # ===================
  # Docker Engine
  # ===================
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true; # Clean unused images
  };
  virtualisation.oci-containers = {
    backend = "docker";
    containers = {
      # ===================
      # Home Assistant
      # ===================
      home-assistant = {
        image = "ghcr.io/home-assistant/home-assistant:stable";
        volumes = [
          "/var/lib/home-assistant:/config"
          "/run/dbus:/run/dbus:ro" # For system integrations
        ];
        environment = {
          TZ = settings.timeZone;
        };
        # Note: With --network=host, ports are not mapped by Docker,
        # but listed here for documentation and systemd ordering.
        ports = [ "${toString settings.haPort}:8123" ];
        extraOptions = [
          "--network=host" # For discovery/multicast
          "--privileged" # For hardware access if needed
          "--device=${settings.threadRadioPath}" # If direct access required; else via OTBR
          "--device=${settings.zigbeeRadioPath}"
        ];
        autoStart = true;
      };
      # ===================
      # Matter Server
      # ===================
      matter-server = {
        image = "ghcr.io/home-assistant-libs/python-matter-server:stable";
        volumes = [ "/var/lib/matter-server:/data" ];
        extraOptions = [
          "--network=host"
          "--privileged"
          "--device=${settings.threadRadioPath}" # If direct, but OTBR handles
        ];
        environment = {
          LOG_LEVEL = "info";
        };
        ports = [ "${toString settings.matterPort}:5580" ]; # Websocket for HA
        autoStart = true;
      };
      # ===================
      # Tailscale VPN
      # ===================
      tailscale = {
        image = "tailscale/tailscale:stable";
        volumes = [ "/var/lib/tailscale:/var/lib/tailscale" ];
        environmentFiles = [ config.sops.secrets.tailscale_authKey.path ];
        environment = {
          TS_AUTHKEY = "@{TS_AUTHKEY}"; # From env file
          TS_STATE_DIR = "/var/lib/tailscale";
          TS_EXTRA_ARGS = "--ssh --accept-routes --accept-dns --advertise-routes=192.168.1.0/24";
          TS_ROUTES = "192.168.1.0/24";
        };
        extraOptions = [
          "--network=host"
          "--cap-add=NET_ADMIN"
          "--cap-add=NET_RAW"
          "--device=/dev/net/tun"
        ];
        autoStart = true;
      };
      # ===================
      # Pi-hole DNS
      # ===================
      pihole = {
        image = "pihole/pihole:latest";
        volumes = [
          "/var/lib/pihole/etc-pihole:/etc/pihole"
          "/var/lib/pihole/etc-dnsmasq.d:/etc/dnsmasq.d"
        ];
        environment = {
          TZ = settings.timeZone;
          DNS1 = settings.network.dns;
          DNS2 = "no"; # Single upstream
          WEB_PORT = "${toString settings.piholeWebPort}";
        };
        ports = [
          "${toString settings.piholeDnsPort}:53/tcp"
          "${toString settings.piholeDnsPort}:53/udp"
          "${toString settings.piholeWebPort}:80/tcp"
        ];
        extraOptions = [
          "--network=host"
          "--cap-add=NET_ADMIN"
        ];
        autoStart = true;
      };
      # ===================
      # OpenThread Border Router (OTBR)
      # ===================
      otbr = {
        image = "openthread/border-router:latest";
        volumes = [ "/var/lib/otbr:/data" ];
        environment = {
          OT_INFRA_IF = settings.network.interface;
          OT_RCP_DEVICE = "spinel+hdlc+uart://${settings.threadRadioPath}?uart-baudrate=460800&uart-flow-control";
          OT_WEB_PORT = "${toString settings.otbrPort}";
          OT_LOG_LEVEL = "info";
        };
        extraOptions = [
          "--network=host"
          "--privileged"
          "--device=${settings.threadRadioPath}"
          "--device=/dev/net/tun"
          "--sysctl=net.ipv6.conf.all.forwarding=1"
          "--sysctl=net.ipv4.conf.all.forwarding=1"
          "--sysctl=net.ipv6.conf.all.accept_ra=2"
        ];
        autoStart = true;
      };
    };
  };

  # Firewall openings (homepage handled by openFirewall in its own module)
  networking.firewall = {
    allowedTCPPorts = [
      settings.haPort
      settings.otbrPort
      settings.matterPort
      settings.piholeWebPort
    ];
    allowedUDPPorts = [ settings.piholeDnsPort ];
  };
  # ===================
  # Auto-upgrade
  # ===================
  system.autoUpgrade = {
    enable = true;
    allowReboot = true;
    flake = "github:${settings.repoUrl}#rpi3";
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
      ${config.virtualisation.docker.package}/bin/docker restart home-assistant matter-server tailscale pihole otbr || true
    '';
    serviceConfig.Type = "oneshot";
  };
}
