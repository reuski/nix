{
  config,
  lib,
  ...
}:
let
  localAddress = "192.168.1.11";
  mediaGroup = "media";
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
            domain = "ukko.home.arpa";
            answer = localAddress;
            enabled = true;
          }
          {
            domain = "*.ukko.home.arpa";
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
    "jellyfin/admin-password" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "jellyfin-setup.service" ];
    };
    "servarr/admin-password" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [
        "sonarr.service"
        "radarr.service"
        "prowlarr.service"
      ];
    };
    "pia/wireguard" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "piavpn.service" ];
    };
    "home-assistant/admin-password" = {
      owner = "root";
      group = "root";
      mode = "0400";
      restartUnits = [ "home-assistant-setup.service" ];
    };
    "home-assistant/secrets.yaml" = {
      owner = "hass";
      group = "hass";
      mode = "0400";
      path = "${config.services.home-assistant.configDir}/secrets.yaml";
      restartUnits = [ "home-assistant.service" ];
    };
    "sonarr/api-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    "radarr/api-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
    };
    "jellyfin/api-key" = {
      owner = "root";
      group = "root";
      mode = "0400";
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
    "qbittorrent/password" = {
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
  };

  sops.templates."heimdash-qbittorrent-credentials" = {
    content = "${config.profile.username}:${config.sops.placeholder."qbittorrent/password"}";
    owner = "root";
    group = "root";
    mode = "0400";
    restartUnits = [ "heimdash.service" ];
  };

  media.jellyfin = {
    enable = true;
    group = mediaGroup;
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
    group = mediaGroup;
    tailscaleServe = true;
    libraries = [ "/srv/media/audiobooks" ];
  };
  media.servarr = {
    enable = true;
    group = mediaGroup;
    admin.passwordFile = config.sops.secrets."servarr/admin-password".path;
  };

  services.sonarr.enable = true;
  services.radarr.enable = true;
  services.prowlarr.enable = true;

  homeAssistant = {
    enable = true;
    admin.passwordFile = config.sops.secrets."home-assistant/admin-password".path;
    components = [
      "met"
      "hue"
      "cast"
      "webostv"
      "tplink"
      "dlna_dmr"
      "lg_thinq"
    ];
    settings.homeassistant = {
      name = "Cell";
      country = "FI";
      currency = "EUR";
      language = "en";
      time_zone = config.profile.timeZone;
      unit_system = "metric";
      latitude = "!secret latitude";
      longitude = "!secret longitude";
      elevation = "!secret elevation";
    };
  };

  media.qbittorrent = {
    enable = true;
    group = mediaGroup;
    wireguardConfigFile = config.sops.secrets."pia/wireguard".path;
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
      qbittorrent-credentials.path = config.sops.templates."heimdash-qbittorrent-credentials".path;
      home-assistant-token.path = config.sops.secrets."home-assistant/token".path;
    };
    services = [
      {
        name = "AdGuard";
        url = "http://adguard.ukko.home.arpa";
        check = "http://adguard.ukko.home.arpa/login.html";
        kind = "adguard";
      }
      {
        name = "Home Assistant";
        url = "http://home.ukko.home.arpa";
        kind = "home_assistant";
        credential = "home-assistant-token";
        entity = "weather.forecast_home";
      }
      {
        name = "qBittorrent";
        url = "http://qbittorrent.ukko.home.arpa";
        kind = "qbittorrent";
        credential = "qbittorrent-credentials";
      }
      {
        name = "Jellyfin";
        url = "http://jellyfin.ukko.home.arpa";
        check = "http://jellyfin.ukko.home.arpa/System/Info/Public";
        kind = "jellyfin";
        credential = "jellyfin-api-key";
      }
      {
        name = "Audiobookshelf";
        url = "http://audiobookshelf.ukko.home.arpa";
        check = "http://audiobookshelf.ukko.home.arpa/healthcheck";
        kind = "audiobookshelf";
        credential = "audiobookshelf-api-key";
      }
      {
        name = "Sonarr";
        url = "http://sonarr.ukko.home.arpa";
        check = "http://sonarr.ukko.home.arpa/ping";
        kind = "sonarr";
        credential = "sonarr-api-key";
      }
      {
        name = "Radarr";
        url = "http://radarr.ukko.home.arpa";
        check = "http://radarr.ukko.home.arpa/ping";
        kind = "radarr";
        credential = "radarr-api-key";
      }
      {
        name = "Prowlarr";
        url = "http://prowlarr.ukko.home.arpa";
        check = "http://prowlarr.ukko.home.arpa/ping";
        kind = "prowlarr";
        credential = "prowlarr-api-key";
      }
    ];
  };

  proxy = {
    services = {
      adguard.port = 3000;
      dashboard.domain = "ukko.home.arpa";
      sonarr.port = 8989;
      radarr.port = 7878;
      prowlarr.port = 9696;
    };
  };

  services.caddy = {
    globalConfig = "grace_period 1m";
    virtualHosts = {
      "http://ukko.local".extraConfig = ''
        reverse_proxy localhost:8082
      '';
      ":80".extraConfig = ''
        reverse_proxy localhost:8082
      '';
    };
  };
}
