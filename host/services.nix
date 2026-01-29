# Service configurations for Home Assistant and related services
{
  settings,
  pkgs-otbr,
  ...
}:

{
  # ===================
  # Home Assistant
  # ===================
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
      http.server_port = settings.haPort;
      logger.default = "info";
      mqtt = {
        broker = "localhost";
        discovery = true;
      };
    };
  };

  # ===================
  # Mosquitto MQTT Broker
  # ===================
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

  # # ===================
  # # Zigbee2MQTT
  # # ===================
  # services.zigbee2mqtt = {
  #   enable = true;
  #   settings = {
  #     frontend.port = settings.zigbee2mqttPort;
  #     serial.port = settings.zigbeeRadioPath;
  #   };
  # };

  # ===================
  # Tailscale VPN
  # ===================
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
    settings.dns.upstreams = [ settings.network.dns ];
  };

  services.pihole-web = {
    enable = true;
    ports = [ 80 ];
  };

  # ===================
  # OpenThread Border Router (OTBR)
  # ===================
  services.openthread-border-router = {
    enable = true;
    package = pkgs-otbr.openthread-border-router;
    backboneInterface = settings.network.interface;
    radio = {
      device = settings.threadRadioPath;
      baudRate = 460800;
      flowControl = true; # Required for SkyConnect/ZBT radios
    };
    web = {
      enable = true;
      listenPort = settings.otbrPort;
    };
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
      systemctl restart home-assistant.service mosquitto.service tailscaled.service pihole-ftl.service otbr-agent.service otbr-web.service || true
    '';
    serviceConfig.Type = "oneshot";
  };

  # ===================
  # OTBR Tools
  # ===================
  environment.systemPackages = [
    pkgs-otbr.openthread-border-router
  ];
}
