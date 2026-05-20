{ ... }:
{
  flake.modules.nixos.homeServer =
    { config, lib, ... }:
    let
      mediaGroup = "media";
      servarrSettings = {
        enable = true;
        openFirewall = true;
        settings.server.bindaddress = "*";
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
        settings = {
          Resolve = {
            DNSStubListener = "no";
          };
        };
      };

      services.adguardhome = {
        enable = true;
        openFirewall = true;
        host = "0.0.0.0";
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
        sonarr.serviceConfig.UMask = lib.mkForce "0002";
        radarr.serviceConfig.UMask = lib.mkForce "0002";
      };
    };
}
