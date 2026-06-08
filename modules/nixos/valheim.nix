{ ... }:
{
  flake.modules.nixos.valheim =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.media.valheim;
      media = config.media;
      inherit (lib) mkIf mkOption types;
      stateDir = "/var/lib/valheim";
      bool = b: if b then "1" else "0";
    in
    {
      options.media.valheim = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        name = mkOption {
          type = types.str;
          default = "Valheim";
        };
        world = mkOption {
          type = types.str;
          default = "Dedicated";
        };
        port = mkOption {
          type = types.port;
          default = 2456;
        };
        public = mkOption {
          type = types.bool;
          default = false;
        };
        crossplay = mkOption {
          type = types.bool;
          default = true;
        };
        environmentFile = mkOption {
          type = types.str;
          description = "sops env file providing PASSWORD=<server password>.";
        };
      };

      config = mkIf cfg.enable {
        quadlets.valheim = {
          image = "mbround18/valheim:3";
          environment = {
            NAME = cfg.name;
            WORLD = cfg.world;
            PORT = toString cfg.port;
            PUBLIC = bool cfg.public;
            ENABLE_CROSSPLAY = bool cfg.crossplay;
            UPDATE_ON_STARTUP = "1";
            AUTO_UPDATE = "1";
            AUTO_UPDATE_SCHEDULE = "0 4 * * *";
            AUTO_BACKUP = "1";
            AUTO_BACKUP_SCHEDULE = "0 */6 * * *";
            AUTO_BACKUP_REMOVE_OLD = "1";
            AUTO_BACKUP_DAYS_TO_LIVE = "3";
            AUTO_BACKUP_ON_UPDATE = "1";
            AUTO_BACKUP_ON_SHUTDOWN = "1";
            AUTO_BACKUP_PAUSE_WITH_NO_PLAYERS = "1";
          };
          environmentFiles = [ cfg.environmentFile ];
          volumes = [
            "${stateDir}/saves:/home/steam/.config/unity3d/IronGate/Valheim"
            "${stateDir}/server:/home/steam/valheim"
            "${stateDir}/backups:/home/steam/backups"
          ];
        };

        networking.firewall.allowedUDPPorts = [
          cfg.port
          (cfg.port + 1)
          (cfg.port + 2)
        ];

        systemd.tmpfiles.rules = [
          "d ${stateDir} 0750 ${media.user} ${media.group} -"
          "d ${stateDir}/saves 0750 ${media.user} ${media.group} -"
          "d ${stateDir}/server 0750 ${media.user} ${media.group} -"
          "d ${stateDir}/backups 0750 ${media.user} ${media.group} -"
        ];
      };
    };
}
