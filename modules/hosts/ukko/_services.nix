{
  config,
  lib,
  ...
}:
let
  localAddress = "192.168.1.11";
  mediaGroup = "media";
  servarrSettings = {
    enable = true;
    settings.server.bindaddress = "127.0.0.1";
  };
  mediaService = servarrSettings // {
    group = mediaGroup;
  };
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
        bind_hosts = [
          "127.0.0.1"
          localAddress
        ];
        port = 53;
        upstream_dns = [ "https://dns.quad9.net/dns-query" ];
        bootstrap_dns = [ "9.9.9.9" ];
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

  sops.secrets."jellyfin/admin-password" = {
    owner = "root";
    group = "root";
    mode = "0400";
    restartUnits = [ "jellyfin-setup.service" ];
  };

  media.jellyfin = {
    enable = true;
    group = mediaGroup;
    admin.passwordFile = config.sops.secrets."jellyfin/admin-password".path;
    libraries = {
      movies = {
        title = "Movies";
        collectionType = "movies";
        paths = [ "/srv/media/movies" ];
      };
      series = {
        title = "Series";
        collectionType = "tvshows";
        paths = [ "/srv/media/series" ];
      };
    };
  };
  services.sonarr = mediaService;
  services.radarr = mediaService;
  services.prowlarr = servarrSettings;

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

  users.groups.${mediaGroup} = { };

  systemd.services = {
    sonarr.serviceConfig.UMask = lib.mkForce "0002";
    radarr.serviceConfig.UMask = lib.mkForce "0002";
  };
}
