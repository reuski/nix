{
  config,
  lib,
  ...
}:
let
  localAddress = "192.168.1.11";
  tsHost = "ukko.tail2fc4c2.ts.net";
in
{
  networking.firewall = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };

  services.resolved.enable = lib.mkForce false;
  networking.resolvconf.enable = lib.mkForce false;
  environment.etc."resolv.conf".text = "nameserver 127.0.0.1\noptions edns0\n";

  services.adguardhome = {
    enable = true;
    host = "127.0.0.1";
    port = 3000;
    settings = {
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
        upstream_dns = [
          "https://dns.quad9.net/dns-query"
          "tls://dns.quad9.net"
        ];
        bootstrap_dns = [
          "9.9.9.9"
          "149.112.112.112"
        ];
        allowed_clients = [
          "127.0.0.1"
          "192.168.1.0/24"
        ];
        ratelimit = 0;
        cache_size = 67108864;
        cache_optimistic = true;
      };
      filtering = {
        protection_enabled = true;
        filtering_enabled = true;
        parental_enabled = false;
        safe_search.enabled = false;
        rewrites = [
          {
            domain = "home.reuski.dev";
            answer = localAddress;
            enabled = true;
          }
          {
            domain = "*.home.reuski.dev";
            answer = localAddress;
            enabled = true;
          }
          {
            domain = "valheim.reuski.dev";
            answer = localAddress;
            enabled = true;
          }
        ];
      };
      filters = [
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_1.txt";
        }
        {
          enabled = true;
          url = "https://adguardteam.github.io/HostlistsRegistry/assets/filter_2.txt";
        }
      ];
      querylog.enabled = true;
      statistics.enabled = true;
    };
  };

  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      addresses = true;
      workstation = true;
    };
  };

  sops.secrets = {
    "cloudflare/dns-token" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    "jellyfin/admin-password" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "jellyfin-setup.service" ];
    };
    "pia/username" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "gluetun.service" ];
    };
    "pia/password" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "gluetun.service" ];
    };
    "sonarr/api-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "heimdash.service" ];
    };
    "radarr/api-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "heimdash.service" ];
    };
    "jellyfin/api-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "heimdash.service" ];
    };
    "audiobookshelf/api-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "heimdash.service" ];
    };
    "prowlarr/api-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "heimdash.service" ];
    };
    "qbittorrent/api-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "heimdash.service" ];
    };
    "home-assistant/token" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "heimdash.service" ];
    };
    "vaultwarden/admin-token" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "heimdash.service" ];
    };
    "valheim/password" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "valheim.service" ];
    };
    "calibre/credentials" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "heimdash.service" ];
    };
  };

  sops.templates = {
    "acme-cloudflare-env" = {
      content = "CF_DNS_API_TOKEN=${config.sops.placeholder."cloudflare/dns-token"}";
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "acme-home.reuski.dev.service" ];
    };
    "vaultwarden-env" = {
      content = "ADMIN_TOKEN=${config.sops.placeholder."vaultwarden/admin-token"}";
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "vaultwarden.service" ];
    };
    "valheim-env" = {
      content = "PASSWORD=${config.sops.placeholder."valheim/password"}";
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "valheim.service" ];
    };
    "pia-gluetun-env" = {
      content = ''
        PIA_USER=${config.sops.placeholder."pia/username"}
        PIA_PASS=${config.sops.placeholder."pia/password"}
        VPN_PORT_FORWARDING_USERNAME=${config.sops.placeholder."pia/username"}
        VPN_PORT_FORWARDING_PASSWORD=${config.sops.placeholder."pia/password"}
      '';
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "gluetun.service" ];
    };
  };

  media.jellyfin = {
    enable = true;
    openFirewall = true;
    admin.passwordFile = config.sops.secrets."jellyfin/admin-password".path;
    libraries = [
      {
        name = "Movies";
        type = "movies";
        paths = [ "/srv/media/movies" ];
      }
      {
        name = "Series";
        type = "tvshows";
        paths = [ "/srv/media/series" ];
      }
    ];
  };
  media.audiobookshelf = {
    enable = true;
    libraries = [ "/srv/media/audiobooks" ];
  };

  media.maintainerr.enable = true;

  media.calibre.enable = true;

  media.tome.enable = true;

  vaultwarden = {
    enable = true;
    domain = "https://${tsHost}:8222";
    environmentFile = config.sops.templates."vaultwarden-env".path;
  };
  media.servarr.enable = true;

  hass.enable = true;

  media.qbittorrent = {
    enable = true;
    region = "ro";
    environmentFile = config.sops.templates."pia-gluetun-env".path;
  };

  media.valheim = {
    enable = true;
    name = "Lintukoto";
    world = "Lintukoto";
    crossplay = false;
    statusPort = 2459;
    environmentFile = config.sops.templates."valheim-env".path;
  };

  services.cloudflare-dyndns = {
    enable = true;
    apiTokenFile = config.sops.secrets."cloudflare/dns-token".path;
    domains = [ "valheim.reuski.dev" ];
  };

  services.skaldi.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    systemWide = true;
    pulse.enable = true;
    raopOpenFirewall = true;
    extraConfig.pipewire."10-raop-discover"."context.modules" = [
      { name = "libpipewire-module-raop-discover"; }
    ];
  };

  systemd.services.skaldi = {
    environment.PULSE_SERVER = "unix:/run/pulse/native";
    serviceConfig.SupplementaryGroups = lib.mkForce [
      "pipewire"
    ];
  };

  services.heimdash = {
    enable = true;
    mounts = [ "/" ];
    credentials = {
      sonarr-api-key.path = config.sops.secrets."sonarr/api-key".path;
      radarr-api-key.path = config.sops.secrets."radarr/api-key".path;
      prowlarr-api-key.path = config.sops.secrets."prowlarr/api-key".path;
      jellyfin-api-key.path = config.sops.secrets."jellyfin/api-key".path;
      audiobookshelf-api-key.path = config.sops.secrets."audiobookshelf/api-key".path;
      qbittorrent-api-key.path = config.sops.secrets."qbittorrent/api-key".path;
      home-assistant-token.path = config.sops.secrets."home-assistant/token".path;
      vaultwarden-admin-token.path = config.sops.secrets."vaultwarden/admin-token".path;
      calibre-credentials.path = config.sops.secrets."calibre/credentials".path;
    };
    services = [
      {
        name = "AdGuard";
        url = "https://adguard.home.reuski.dev";
        check = "https://adguard.home.reuski.dev/login.html";
        api = "http://127.0.0.1:3000";
        kind = "adguard";
      }
      {
        name = "Home Assistant";
        url = "https://hass.home.reuski.dev";
        api = "http://127.0.0.1:8123";
        kind = "home_assistant";
        credential = "home-assistant-token";
        entity = "weather.forecast_home";
      }
      {
        name = "qBittorrent";
        url = "https://qbittorrent.home.reuski.dev";
        api = "http://127.0.0.1:8080";
        kind = "qbittorrent";
        credential = "qbittorrent-api-key";
      }
      {
        name = "Jellyfin";
        url = "https://jellyfin.home.reuski.dev";
        check = "https://jellyfin.home.reuski.dev/System/Info/Public";
        api = "http://127.0.0.1:8096";
        kind = "jellyfin";
        credential = "jellyfin-api-key";
      }
      {
        name = "Maintainerr";
        url = "https://maintainerr.home.reuski.dev";
        check = "https://maintainerr.home.reuski.dev/api/health/ready";
        api = "http://127.0.0.1:6246";
        kind = "maintainerr";
      }
      {
        name = "Audiobookshelf";
        url = "https://audiobookshelf.home.reuski.dev";
        check = "https://audiobookshelf.home.reuski.dev/healthcheck";
        api = "http://127.0.0.1:8000";
        kind = "audiobookshelf";
        credential = "audiobookshelf-api-key";
      }
      {
        name = "Skaldi";
        url = "https://skaldi.home.reuski.dev";
      }
      {
        name = "Calibre";
        url = "https://calibre.home.reuski.dev";
        api = "http://127.0.0.1:8084";
        kind = "calibre";
        credential = "calibre-credentials";
      }
      {
        name = "Tome";
        url = "https://tome.home.reuski.dev";
        check = "https://tome.home.reuski.dev";
      }
      {
        name = "Valheim";
        url = "https://valheim.home.reuski.dev";
        check = "https://valheim.home.reuski.dev/health";
        api = "http://127.0.0.1:2459";
        kind = "valheim";
      }
      {
        name = "Sonarr";
        url = "https://sonarr.home.reuski.dev";
        check = "https://sonarr.home.reuski.dev/ping";
        api = "http://127.0.0.1:8989";
        kind = "sonarr";
        credential = "sonarr-api-key";
      }
      {
        name = "Radarr";
        url = "https://radarr.home.reuski.dev";
        check = "https://radarr.home.reuski.dev/ping";
        api = "http://127.0.0.1:7878";
        kind = "radarr";
        credential = "radarr-api-key";
      }
      {
        name = "Prowlarr";
        url = "https://prowlarr.home.reuski.dev";
        check = "https://prowlarr.home.reuski.dev/ping";
        api = "http://127.0.0.1:9696";
        kind = "prowlarr";
        credential = "prowlarr-api-key";
      }
      {
        name = "Vaultwarden";
        url = "https://${tsHost}:8222";
        check = "http://127.0.0.1:8222/alive";
        api = "http://127.0.0.1:8222";
        kind = "vaultwarden";
        credential = "vaultwarden-admin-token";
      }
    ];
  };

  tailnet.services = {
    audiobookshelf.port = 8000;
    vaultwarden.port = 8222;
  };

  proxy = {
    domain = "home.reuski.dev";
    dnsEnvironmentFile = config.sops.templates."acme-cloudflare-env".path;
    services = {
      adguard.port = 3000;
      heimdash.domain = "home.reuski.dev";
    };
  };

  services.caddy.globalConfig = "grace_period 1m";
}
