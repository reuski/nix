{ ... }:
{
  flake.modules.nixos.homeServer =
    { lib, ... }:
    let
      mediaGroup = "media";
      mediaRoot = "/srv/media";
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
        allowedUDPPorts = [ 53 ];
      };

      environment.etc."resolv.conf".source = lib.mkForce "/run/systemd/resolve/resolv.conf";

      networking.nameservers = lib.mkForce [ "127.0.0.1" ];

      services.resolved = {
        dnssec = lib.mkForce "false";
        dnsovertls = lib.mkForce "false";
        fallbackDns = lib.mkForce [ ];
        extraConfig = ''
          DNSStubListener=no
        '';
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

      services.jellyfin = {
        enable = true;
        openFirewall = true;
      };

      services.sonarr = mediaService;
      services.radarr = mediaService;
      services.prowlarr = servarrSettings;

      users.groups.${mediaGroup} = { };
      users.users.jellyfin.extraGroups = [ mediaGroup ];

      systemd.services = {
        sonarr.serviceConfig.UMask = lib.mkForce "0002";
        radarr.serviceConfig.UMask = lib.mkForce "0002";
      };

      systemd.tmpfiles.rules = [
        "d ${mediaRoot} 2775 root ${mediaGroup} -"
        "d ${mediaRoot}/downloads 2775 root ${mediaGroup} -"
        "d ${mediaRoot}/movies 2775 radarr ${mediaGroup} -"
        "d ${mediaRoot}/series 2775 sonarr ${mediaGroup} -"
      ];
    };
}
