{
  config,
  lib,
  pkgs,
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
    allowedUDPPorts = [
      53
      1900
      7359
    ];
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
          }
          {
            domain = "*.ukko.home.arpa";
            answer = localAddress;
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

  services.jellyfin = {
    enable = true;
    openFirewall = true;
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
      jellyfin.port = 8096;
      sonarr.port = 8989;
      radarr.port = 7878;
      prowlarr.port = 9696;
    };
  };

  services.caddy = let
    mkHost = _name: service: "http://${service.domain}${lib.optionalString (service.listen != 80) ":${toString service.listen}"}";
    hosts = lib.mapAttrsToList mkHost config.proxy.services;
  in {
    globalConfig = "grace_period 1m";
    virtualHosts = lib.genAttrs hosts (_: {
      extraConfig = ''
        header {
          X-Content-Type-Options "nosniff"
          X-Frame-Options "SAMEORIGIN"
          Referrer-Policy "strict-origin-when-cross-origin"
          X-Robots-Tag "noindex, nofollow"
        }
      '';
    });
  };

  boot.kernel.sysctl = {
    "fs.inotify.max_user_instances" = 1024;
    "fs.inotify.max_user_watches" = 1048576;
  };

  fonts = {
    fontconfig.enable = lib.mkForce true;
    packages = with pkgs; [
      liberation_ttf
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-color-emoji
    ];
  };

  users.groups.${mediaGroup} = { };
  users.users = {
    jellyfin.extraGroups = [
      mediaGroup
      "render"
      "video"
    ];
    ${config.profile.username}.extraGroups = [ mediaGroup ];
  };

  systemd.services = {
    jellyfin = {
      wants = [ "network-online.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        UMask = lib.mkForce "0002";
        SupplementaryGroups = [
          mediaGroup
          "render"
          "video"
        ];
      };
    };
    sonarr.serviceConfig.UMask = lib.mkForce "0002";
    radarr.serviceConfig.UMask = lib.mkForce "0002";
  };
}
