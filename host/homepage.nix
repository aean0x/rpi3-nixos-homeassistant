{
  config,
  settings,
  ...
}:
{
  # ===================
  # Homepage Dashboard (Native)
  # ===================
  services.homepage-dashboard = {
    enable = true;
    listenPort = settings.homepagePort;
    openFirewall = true;
    settings = {
      title = "Home Server Dashboard";
      headerStyle = "clean";
      layout = "auto";
    };
    services = [
      {
        "Home Automation" = [
          {
            "Home Assistant" = {
              href = "http://${settings.network.address}:${toString settings.haPort}/";
              description = "Smart Home Hub";
              icon = "home-assistant.png";
              widget = {
                type = "homeassistant";
                url = "http://${settings.network.address}:${toString settings.haPort}";
                # key = "{{HOMEPAGE_VAR_HASS_TOKEN}}"; # Add to secrets
              };
            };
          }
          {
            "OTBR" = {
              href = "http://${settings.network.address}:${toString settings.otbrPort}/";
              description = "Thread Border Router";
              icon = "openthread.png";
            };
          }
        ];
      }
      {
        "Network" = [
          {
            "Pi-hole" = {
              href = "http://${settings.network.address}:${toString settings.piholeWebPort}/admin/";
              description = "DNS & Ad Blocker";
              icon = "pi-hole.png";
              widget = {
                type = "pihole";
                url = "http://${settings.network.address}:${toString settings.piholeWebPort}";
                # key = "{{HOMEPAGE_VAR_PIHOLE_TOKEN}}"; # Add to secrets
              };
            };
          }
        ];
      }
    ];
    widgets = [
      {
        search = {
          provider = "duckduckgo";
          target = "_blank";
        };
      }
      {
        resources = {
          cpu = true;
          disk = "/";
          memory = true;
        };
      }
      {
        docker = {
          container = "home-assistant";
        };
      }
      {
        docker = {
          container = "pihole";
        };
      }
      {
        docker = {
          container = "otbr";
        };
      }
      # Add more for others
    ];
    bookmarks = [
      {
        Developer = [
          {
            Github = [
              {
                abbr = "GH";
                href = "https://github.com/";
                icon = "github.png";
              }
            ];
          }
        ];
      }
    ];
    # For secrets in widgets (e.g., API keys)
    environmentFile = config.sops.secrets.homepage_env.path;
  };
  # Grant docker access for widgets
  systemd.services.homepage-dashboard.serviceConfig.SupplementaryGroups = [ "docker" ];
}
