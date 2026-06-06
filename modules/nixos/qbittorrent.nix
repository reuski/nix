{ ... }:
{
  flake.modules.nixos.qbittorrent =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.media.qbittorrent;
      media = config.media;
      quadlet = config.virtualisation.quadlet;
      inherit (lib)
        mkIf
        mkOption
        types
        ;
      port = toString cfg.webuiPort;
    in
    {
      options.media.qbittorrent = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        webuiPort = mkOption {
          type = types.port;
          default = 8080;
        };
        downloadDir = mkOption {
          type = types.str;
          default = "/srv/media/torrents";
        };
        environmentFile = mkOption {
          type = types.str;
          description = "gluetun PIA credentials env file (OPENVPN_USER/OPENVPN_PASSWORD), sops secret path.";
        };
      };

      config = mkIf cfg.enable {
        virtualisation.quadlet = {
          pods.vpn.podConfig.publishPorts = [ "127.0.0.1:${port}:${port}" ];

          containers.gluetun = {
            containerConfig = {
              image = "ghcr.io/qdm12/gluetun:latest";
              name = "gluetun";
              pod = quadlet.pods.vpn.ref;
              addCapabilities = [ "NET_ADMIN" ];
              devices = [ "/dev/net/tun" ];
              autoUpdate = "registry";
              environments = {
                VPN_SERVICE_PROVIDER = "private internet access";
                VPN_TYPE = "wireguard";
                VPN_PORT_FORWARDING = "on";
                FIREWALL_OUTBOUND_SUBNETS = "192.168.1.0/24";
                TZ = config.profile.timeZone;
              };
              environmentFiles = [ cfg.environmentFile ];
              volumes = [ "/var/lib/gluetun:/gluetun" ];
            };
          };

          containers.qbittorrent = {
            containerConfig = {
              image = "lscr.io/linuxserver/qbittorrent:latest";
              name = "qbittorrent";
              pod = quadlet.pods.vpn.ref;
              autoUpdate = "registry";
              environments = media.containerEnv // {
                WEBUI_PORT = port;
              };
              volumes = [
                "/var/lib/qbittorrent:/config"
                "${media.libraryDir}:${media.libraryDir}"
              ];
            };
            unitConfig = {
              After = [ "gluetun.service" ];
              Requires = [ "gluetun.service" ];
              BindsTo = [ "gluetun.service" ];
            };
          };
        };

        proxy.services.qbittorrent.port = cfg.webuiPort;

        systemd.tmpfiles.rules = [
          "d /var/lib/gluetun 0750 ${media.user} ${media.group} -"
          "d /var/lib/qbittorrent 0755 ${media.user} ${media.group} -"
          "d ${cfg.downloadDir} 2775 ${media.user} ${media.group} -"
        ];
      };
    };
}
