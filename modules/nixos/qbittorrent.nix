{ inputs, ... }:
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
      namespace = "piavpn";
      ns = config.vpnNamespaces.${namespace};
    in
    {
      imports = [ inputs.vpn-confinement.nixosModules.default ];

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
        wireguardConfigFile = mkOption {
          type = types.str;
          description = "PIA WireGuard config (sops secret path) routing all qBittorrent traffic.";
        };
      };

      config = mkIf cfg.enable {
        vpnNamespaces.${namespace} = {
          enable = true;
          inherit (cfg) wireguardConfigFile;
          portMappings = [
            {
              from = cfg.webuiPort;
              to = cfg.webuiPort;
              protocol = "tcp";
            }
          ];
        };

        services.qbittorrent = {
          enable = true;
          inherit (cfg) group webuiPort;
          torrentingPort = cfg.torrentPort;
          serverConfig = {
            LegalNotice.Accepted = true;
            Preferences = {
              General.Locale = "en";
              WebUI = {
                Address = "*";
                AuthSubnetWhitelistEnabled = true;
                AuthSubnetWhitelist = "${ns.bridgeAddress}/32";
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

        systemd.services = {
          ${namespace} = {
            wants = [ "sops-install-secrets.service" ];
            after = [ "sops-install-secrets.service" ];
          };
          qbittorrent = {
            vpnConfinement = {
              enable = true;
              vpnNamespace = namespace;
            };
            serviceConfig.UMask = mkForce "0002";
          };
        };

        proxy.services.qbittorrent = {
          host = ns.namespaceAddress;
          port = cfg.webuiPort;
        };

        users.groups.${cfg.group} = { };
        users.users.${config.profile.username}.extraGroups = [ cfg.group ];

        systemd.tmpfiles.rules = [
          "d ${cfg.downloadDir} 2775 qbittorrent ${cfg.group} -"
        ];
      };
    };
}
