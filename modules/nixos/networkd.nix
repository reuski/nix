{ ... }:
{
  flake.modules.nixos.networkd =
    { ... }:
    {
      boot.kernelModules = [ "tcp_bbr" ];
      boot.kernel.sysctl = {
        "net.core.default_qdisc" = "fq";
        "net.ipv4.tcp_congestion_control" = "bbr";
      };

      networking = {
        useDHCP = false;
        useNetworkd = true;
        nftables.enable = true;
        firewall = {
          enable = true;
          allowPing = true;
          checkReversePath = "loose";
          logRefusedConnections = false;
          trustedInterfaces = [ "tailscale0" ];
        };
      };

      systemd.network = {
        enable = true;
        wait-online.anyInterface = true;
        networks."10-wan" = {
          matchConfig.Name = "en* eth*";
          networkConfig = {
            DHCP = "yes";
            IPv6AcceptRA = true;
            LinkLocalAddressing = "ipv6";
          };
          dhcpV4Config.RouteMetric = 100;
          ipv6AcceptRAConfig.RouteMetric = 100;
          linkConfig.RequiredForOnline = "routable";
        };
      };

      services.resolved = {
        enable = true;
        settings.Resolve = {
          DNSSEC = "allow-downgrade";
          DNSOverTLS = "opportunistic";
          FallbackDNS = [
            "1.1.1.1#cloudflare-dns.com"
            "9.9.9.9#dns.quad9.net"
          ];
        };
      };
    };
}
