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

  environment.etc."resolv.conf".source = lib.mkForce "/run/systemd/resolve/resolv.conf";
  networking.nameservers = lib.mkForce [ "127.0.0.1" ];

  services.resolved = {
    dnssec = lib.mkForce "false";
    dnsovertls = lib.mkForce "false";
    fallbackDns = lib.mkForce [ ];
    settings.Resolve.DNSStubListener = "no";
  };

  services.adguardhome = {
    enable = true;
    host = "127.0.0.1";
    port = 3000;
    settings = {
      dns = {
        bind_hosts = [
          "0.0.0.0"
          "::"
        ];
        port = 53;
        upstream_dns = [
          "https://dns.quad9.net/dns-query"
          "https://cloudflare-dns.com/dns-query"
        ];
        bootstrap_dns = [
          "9.9.9.9"
          "1.1.1.1"
        ];
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
      filtering = {
        protection_enabled = true;
        filtering_enabled = true;
        parental_enabled = false;
        safe_search.enabled = false;
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

  proxy.services = {
    adguard.port = 3000;
    jellyfin.port = 8096;
    sonarr.port = 8989;
    radarr.port = 7878;
    prowlarr.port = 9696;
    dashboard = {
      domain = "ukko.local";
      listen = 8080;
    };
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
