{
  config,
  lib,
  ...
}:
let
  localAddress = "192.168.1.11";
  tsHost = "ukko.tail2fc4c2.ts.net";
  inherit (lib) optionalAttrs;

  card =
    key:
    {
      name,
      kind,
      checkPath ? null,
      credential ? null,
      entity ? null,
    }:
    let
      p = config.proxy.services.${key};
      url = "https://${p.domain}";
    in
    {
      inherit name url kind;
      api = "http://${p.host}:${toString p.port}";
    }
    // optionalAttrs (checkPath != null) { check = "${url}${checkPath}"; }
    // optionalAttrs (credential != null) { inherit credential; }
    // optionalAttrs (entity != null) { inherit entity; };
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
    "cloudflare/dns-token" = { };
    "jellyfin/admin-password".restartUnits = [ "jellyfin-setup.service" ];
    "pia/username".restartUnits = [ "gluetun.service" ];
    "pia/password".restartUnits = [ "gluetun.service" ];
    "valheim/password".restartUnits = [ "valheim.service" ];
    "navidrome/admin-password".restartUnits = [
      "navidrome.service"
      "skaldi.service"
    ];
  }
  //
    lib.genAttrs
      [
        "audiobookshelf/api-key"
        "calibre/credentials"
        "home-assistant/token"
        "jellyfin/api-key"
        "lidarr/api-key"
        "prowlarr/api-key"
        "qbittorrent/api-key"
        "radarr/api-key"
        "sonarr/api-key"
        "vaultwarden/admin-token"
      ]
      (_: {
        restartUnits = [ "heimdash.service" ];
      });

  sops.templates = {
    "acme-cloudflare-env" = {
      content = "CF_DNS_API_TOKEN=${config.sops.placeholder."cloudflare/dns-token"}";
      restartUnits = [ "acme-home.reuski.dev.service" ];
    };
    "vaultwarden-env" = {
      content = "ADMIN_TOKEN=${config.sops.placeholder."vaultwarden/admin-token"}";
      restartUnits = [ "vaultwarden.service" ];
    };
    "valheim-env" = {
      content = "PASSWORD=${config.sops.placeholder."valheim/password"}";
      restartUnits = [ "valheim.service" ];
    };
    "navidrome-env" = {
      content = "ND_DEVAUTOCREATEADMINPASSWORD=${config.sops.placeholder."navidrome/admin-password"}";
      restartUnits = [ "navidrome.service" ];
    };
    "navidrome-heimdash-credentials" = {
      content = "admin:${config.sops.placeholder."navidrome/admin-password"}";
      restartUnits = [ "heimdash.service" ];
    };
    "pia-gluetun-env" = {
      content = ''
        PIA_USER=${config.sops.placeholder."pia/username"}
        PIA_PASS=${config.sops.placeholder."pia/password"}
        VPN_PORT_FORWARDING_USERNAME=${config.sops.placeholder."pia/username"}
        VPN_PORT_FORWARDING_PASSWORD=${config.sops.placeholder."pia/password"}
      '';
      restartUnits = [ "gluetun.service" ];
    };
  };

  jellyfin = {
    enable = true;
    openFirewall = true;
    admin.passwordFile = config.sops.secrets."jellyfin/admin-password".path;
    libraries = [
      {
        name = "Movies";
        type = "movies";
        paths = [ "${config.media.libraryDir}/movies" ];
      }
      {
        name = "Series";
        type = "tvshows";
        paths = [ "${config.media.libraryDir}/series" ];
      }
    ];
  };
  audiobookshelf = {
    enable = true;
    libraries = [ "${config.media.libraryDir}/audiobooks" ];
  };
  navidrome = {
    enable = true;
    environmentFile = config.sops.templates."navidrome-env".path;
  };

  maintainerr.enable = true;

  calibre.enable = true;

  tome.enable = true;

  vaultwarden = {
    enable = true;
    domain = "https://${tsHost}:8222";
    environmentFile = config.sops.templates."vaultwarden-env".path;
  };
  servarr.enable = true;

  hass.enable = true;

  qbittorrent = {
    enable = true;
    region = "ro";
    environmentFile = config.sops.templates."pia-gluetun-env".path;
  };

  valheim = {
    enable = true;
    name = "Lintukoto";
    world = "Lintukoto";
    crossplay = false;
    public = true;
    statusPort = 2459;
    environmentFile = config.sops.templates."valheim-env".path;
  };

  services.cloudflare-dyndns = {
    enable = true;
    apiTokenFile = config.sops.secrets."cloudflare/dns-token".path;
    domains = [ "valheim.reuski.dev" ];
  };

  services.skaldi.enable = true;
  services.skaldi.settings.opensubsonic = {
    enabled = true;
    library_id = "navidrome";
    base_url = "http://127.0.0.1:4533";
    username = "admin";
    token_file = "/run/credentials/skaldi.service/opensubsonic-token";
  };

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
    serviceConfig.LoadCredential = [
      "opensubsonic-token:${config.sops.secrets."navidrome/admin-password".path}"
    ];
  };

  services.heimdash = {
    enable = true;
    mounts = [ "/" ];
    credentials = {
      sonarr-api-key.path = config.sops.secrets."sonarr/api-key".path;
      radarr-api-key.path = config.sops.secrets."radarr/api-key".path;
      lidarr-api-key.path = config.sops.secrets."lidarr/api-key".path;
      prowlarr-api-key.path = config.sops.secrets."prowlarr/api-key".path;
      jellyfin-api-key.path = config.sops.secrets."jellyfin/api-key".path;
      audiobookshelf-api-key.path = config.sops.secrets."audiobookshelf/api-key".path;
      qbittorrent-api-key.path = config.sops.secrets."qbittorrent/api-key".path;
      home-assistant-token.path = config.sops.secrets."home-assistant/token".path;
      vaultwarden-admin-token.path = config.sops.secrets."vaultwarden/admin-token".path;
      calibre-credentials.path = config.sops.secrets."calibre/credentials".path;
      navidrome-credentials.path = config.sops.templates."navidrome-heimdash-credentials".path;
    };
    services = [
      (card "adguard" {
        name = "AdGuard";
        kind = "adguard";
        checkPath = "/login.html";
      })
      (card "hass" {
        name = "Home Assistant";
        kind = "home_assistant";
        credential = "home-assistant-token";
        entity = "weather.forecast_home";
      })
      (card "qbittorrent" {
        name = "qBittorrent";
        kind = "qbittorrent";
        credential = "qbittorrent-api-key";
      })
      (card "jellyfin" {
        name = "Jellyfin";
        kind = "jellyfin";
        checkPath = "/System/Info/Public";
        credential = "jellyfin-api-key";
      })
      (card "maintainerr" {
        name = "Maintainerr";
        kind = "maintainerr";
        checkPath = "/api/health/ready";
      })
      (card "audiobookshelf" {
        name = "Audiobookshelf";
        kind = "audiobookshelf";
        checkPath = "/healthcheck";
        credential = "audiobookshelf-api-key";
      })
      (card "skaldi" {
        name = "Skaldi";
        kind = "skaldi";
      })
      (card "navidrome" {
        name = "Navidrome";
        kind = "navidrome";
        checkPath = "";
        credential = "navidrome-credentials";
      })
      (card "calibre" {
        name = "Calibre";
        kind = "calibre";
        credential = "calibre-credentials";
      })
      (card "tome" {
        name = "Tome";
        kind = "tome";
        checkPath = "";
      })
      (card "valheim" {
        name = "Valheim";
        kind = "valheim";
        checkPath = "/health";
      })
      (card "sonarr" {
        name = "Sonarr";
        kind = "sonarr";
        checkPath = "/ping";
        credential = "sonarr-api-key";
      })
      (card "radarr" {
        name = "Radarr";
        kind = "radarr";
        checkPath = "/ping";
        credential = "radarr-api-key";
      })
      (card "lidarr" {
        name = "Lidarr";
        kind = "lidarr";
        checkPath = "/ping";
        credential = "lidarr-api-key";
      })
      (card "prowlarr" {
        name = "Prowlarr";
        kind = "prowlarr";
        checkPath = "/ping";
        credential = "prowlarr-api-key";
      })
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
    navidrome.port = 4533;
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
