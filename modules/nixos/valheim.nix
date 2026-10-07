{ ... }:
{
  flake.modules.nixos.valheim =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.valheim;
      inherit (lib)
        concatStringsSep
        mapAttrsToList
        mkEnableOption
        mkIf
        mkOption
        optionalAttrs
        types
        ;
      stateDir = "/var/lib/valheim";
      bool = b: if b then "1" else "0";
      renderModifiers = concatStringsSep "," (
        mapAttrsToList (name: value: "${name}=${value}") cfg.modifiers
      );
    in
    {
      options.valheim = {
        enable = mkEnableOption "the Valheim dedicated server";
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
        modifiers = mkOption {
          type = types.attrsOf types.str;
          default = { };
          description = "Native world modifiers applied over the Normal preset.";
        };
        saveInterval = mkOption {
          type = types.ints.between 1 65535;
          default = 1800;
          description = "World save interval in seconds passed as -saveinterval.";
        };
        statusPort = mkOption {
          type = types.nullOr types.port;
          default = null;
          description = "Enable the huginn HTTP status server on this port and reverse-proxy it.";
        };
        environmentFile = mkOption {
          type = types.str;
          description = "sops env file providing PASSWORD=<server password>.";
        };
      };

      config = mkIf cfg.enable {
        quadlets.valheim = {
          image = "docker.io/mbround18/valheim:latest";
          containerConfig = {
            networks = [ "host" ];
            stopSignal = "SIGINT";
            stopTimeout = 120;
          };
          environment = {
            NAME = cfg.name;
            WORLD = cfg.world;
            PORT = toString cfg.port;
            PUBLIC = bool cfg.public;
            ENABLE_CROSSPLAY = bool cfg.crossplay;
            ADDRESS = "127.0.0.1:${toString (cfg.port + 1)}";
            PRESET = "Normal";
            MODIFIERS = renderModifiers;
            SAVE_INTERVAL = toString cfg.saveInterval;
            UPDATE_ON_STARTUP = "1";
            AUTO_UPDATE = "1";
            AUTO_UPDATE_SCHEDULE = "15 * * * *";
            AUTO_UPDATE_PAUSE_WITH_PLAYERS = bool (cfg.public && !cfg.crossplay);
            AUTO_BACKUP = "1";
            AUTO_BACKUP_SCHEDULE = "45 3-23/4 * * *";
            AUTO_BACKUP_REMOVE_OLD = "1";
            AUTO_BACKUP_DAYS_TO_LIVE = "3";
            AUTO_BACKUP_ON_UPDATE = "1";
            AUTO_BACKUP_ON_SHUTDOWN = "1";
            AUTO_BACKUP_PAUSE_WITH_NO_PLAYERS = "0";
          }
          // optionalAttrs (cfg.statusPort != null) {
            HTTP_PORT = toString cfg.statusPort;
          };
          environmentFiles = [ cfg.environmentFile ];
          volumes = [
            "${stateDir}/saves:/home/steam/.config/unity3d/IronGate/Valheim"
            "${stateDir}/server:/home/steam/valheim"
            "${stateDir}/backups:/home/steam/backups"
          ];
        }
        // optionalAttrs (cfg.statusPort != null) { port = cfg.statusPort; };

        systemd.services.valheim.serviceConfig.TimeoutStopSec = "180s";

        networking.firewall.allowedUDPPorts = [
          cfg.port
          (cfg.port + 1)
          (cfg.port + 2)
        ];

        systemd.tmpfiles.rules = map (dir: "d ${dir} 0750 root root -") [
          stateDir
          "${stateDir}/saves"
          "${stateDir}/server"
          "${stateDir}/backups"
        ];
      };
    };
}
