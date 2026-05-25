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
      inherit (lib)
        mkForce
        mkIf
        mkOption
        types
        ;
    in
    {
      options.media.qbittorrent = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        group = mkOption {
          type = types.str;
          default = "media";
        };
        downloadDir = mkOption {
          type = types.str;
          default = "/srv/media/torrents";
        };
        webuiPort = mkOption {
          type = types.port;
          default = 8080;
        };
        torrentPort = mkOption {
          type = types.port;
          default = 51413;
        };
        openFirewall = mkOption {
          type = types.bool;
          default = true;
        };
      };

      config = mkIf cfg.enable {
        services.qbittorrent = {
          enable = true;
          inherit (cfg) group webuiPort;
          torrentingPort = cfg.torrentPort;
          serverConfig = {
            LegalNotice.Accepted = true;
            Preferences = {
              General.Locale = "en";
              WebUI = {
                Address = "127.0.0.1";
                LocalHostAuth = false;
                HostHeaderValidation = false;
                CSRFProtection = false;
              };
            };
            BitTorrent.Session = {
              DefaultSavePath = cfg.downloadDir;
              TempPath = "${cfg.downloadDir}/.incomplete";
              TempPathEnabled = true;
            };
          };
        };

        proxy.services.qbittorrent.port = cfg.webuiPort;

        users.groups.${cfg.group} = { };
        users.users.${config.profile.username}.extraGroups = [ cfg.group ];

        systemd.tmpfiles.rules = [
          "d ${cfg.downloadDir} 2775 qbittorrent ${cfg.group} -"
        ];

        systemd.services.qbittorrent.serviceConfig.UMask = mkForce "0002";

        networking.firewall = mkIf cfg.openFirewall {
          allowedTCPPorts = [ cfg.torrentPort ];
          allowedUDPPorts = [ cfg.torrentPort ];
        };
      };
    };
}
