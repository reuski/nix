{ config, lib, ... }:
let
  localAddress = "192.168.1.11";
  tailnetDomain = "tail2fc4c2.ts.net";
in
{
  services.tailscale.extraSetFlags = [ "--accept-dns=false" ];

  networking.firewall = {
    allowedTCPPorts = [ 53 ];
    allowedUDPPorts = [ 53 ];
  };

  services.resolved.enable = lib.mkForce false;
  networking.resolvconf.enable = lib.mkForce false;
  environment.etc."resolv.conf".text = ''
    search ${tailnetDomain}
    nameserver 127.0.0.1
    options edns0
  '';

  services.adguardhome = {
    enable = true;
    host = "127.0.0.1";
    port = 3000;
    settings = {
      dns = {
        bind_hosts = [ "0.0.0.0" ];
        port = 53;
        upstream_dns = [
          "[/${tailnetDomain}/]100.100.100.100"
          "https://dns.quad9.net/dns-query"
          "https://dnsforge.de/dns-query"
        ];
        upstream_mode = "parallel";
        bootstrap_dns = [
          "9.9.9.9"
          "149.112.112.112"
        ];
        fallback_dns = [
          "9.9.9.9"
          "149.112.112.112"
        ];
        enable_dnssec = true;
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
            domain = "router.home.reuski.dev";
            answer = "192.168.1.1";
            enabled = true;
          }
          {
            domain = "wifi.home.reuski.dev";
            answer = "192.168.1.2";
            enabled = true;
          }
          {
            domain = "valheim.reuski.dev";
            answer = localAddress;
            enabled = true;
          }
          {
            domain = "mumble.reuski.dev";
            answer = localAddress;
            enabled = true;
          }
        ];
      };
      filters = [
        {
          enabled = true;
          url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/pro.txt";
        }
        {
          enabled = true;
          url = "https://raw.githubusercontent.com/hagezi/dns-blocklists/main/adblock/tif.txt";
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

  services.cloudflare-dyndns = {
    enable = true;
    apiTokenFile = config.sops.secrets."cloudflare/dns-token".path;
    domains = [
      "valheim.reuski.dev"
      "mumble.reuski.dev"
    ];
  };

  systemd.services.deploy = {
    after = [ "adguardhome.service" ];
    requires = [ "adguardhome.service" ];
  };
}
