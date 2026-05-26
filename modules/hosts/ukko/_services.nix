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
  };

  media.jellyfin = {
    enable = true;
    group = mediaGroup;
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
    services = [
      {
        name = "AdGuard";
        url = "http://adguard.ukko.home.arpa";
      }
      {
        name = "Jellyfin";
        url = "http://jellyfin.ukko.home.arpa";
      }
      {
        name = "Sonarr";
        url = "http://sonarr.ukko.home.arpa";
      }
      {
        name = "Radarr";
        url = "http://radarr.ukko.home.arpa";
      }
      {
        name = "Prowlarr";
        url = "http://prowlarr.ukko.home.arpa";
      }
      {
        name = "qBittorrent";
        url = "http://qbittorrent.ukko.home.arpa";
      }
      {
        name = "Home Assistant";
        url = "http://home.ukko.home.arpa";
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
