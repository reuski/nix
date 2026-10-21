{ ... }:
{
  flake.modules.nixos.backup =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.backup;
      host = config.networking.hostName;

      notifier = pkgs.writeShellApplication {
        name = "backup-notify";
        runtimeInputs = [ pkgs.curl ];
        text = ''curl -fsS -H "Priority: high" --data-raw "${host} // BACKUP OR CHECK FAILED" "${cfg.notify}" || true'';
      };

      stamper = pkgs.writeShellApplication {
        name = "backup-stamp";
        runtimeInputs = [ pkgs.coreutils ];
        text = ''
          mkdir -p "$(dirname "${cfg.stampPath}")"
          date -u +%s > "${cfg.stampPath}"
        '';
      };
    in
    {
      options.backup = {
        enable = lib.mkEnableOption "off-site restic backups over an rclone remote";
        paths = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = "Absolute paths backed up off-site.";
        };
        repository = lib.mkOption {
          type = lib.types.str;
          example = "rclone:filen:nixbackup/ukko";
          description = "restic repository; the provider lives in the rclone remote.";
        };
        passwordFile = lib.mkOption {
          type = lib.types.path;
          description = "restic repository password (sops).";
        };
        rcloneConfigFile = lib.mkOption {
          type = lib.types.path;
          description = "rclone config for the remote named in repository (sops).";
        };
        notify = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional ntfy topic for failed runs.";
        };
        stampPath = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional path overwritten with the Unix timestamp of each successful run, read by heimdash.";
        };
      };

      config = lib.mkIf cfg.enable {
        services.restic.backups.${host} = {
          inherit (cfg)
            repository
            passwordFile
            rcloneConfigFile
            paths
            ;
          initialize = true;
          extraBackupArgs = [
            "--retry-lock=30m"
            "--cleanup-cache"
          ];
          pruneOpts = [
            "--group-by host"
            "--keep-within 1d"
            "--keep-daily 7"
            "--keep-weekly 4"
            "--keep-monthly 3"
            "--retry-lock=30m"
          ];
          runCheck = true;
          checkOpts = [
            "--retry-lock=30m"
            "--cleanup-cache"
          ];
          timerConfig = {
            OnCalendar = "*-*-* 0/4:00:00";
            Persistent = true;
            RandomizedDelaySec = "30min";
          };
        };

        services.restic.backups."${host}-check" = {
          inherit (cfg)
            repository
            passwordFile
            rcloneConfigFile
            ;
          paths = [ ];
          initialize = false;
          pruneOpts = [ ];
          createWrapper = false;
          runCheck = true;
          checkOpts = [
            "--retry-lock=30m"
            "--cleanup-cache"
            "--read-data"
          ];
          timerConfig = {
            OnCalendar = "Sun 05:30:00";
            Persistent = true;
            RandomizedDelaySec = "30min";
          };
        };

        systemd.services = lib.mkMerge [
          (lib.mkIf (cfg.stampPath != null) {
            "restic-backups-${host}".serviceConfig.ExecStartPost = lib.getExe stamper;
          })
          (lib.mkIf (cfg.notify != null) {
            "restic-backups-${host}".onFailure = [ "backup-notify.service" ];
            "restic-backups-${host}-check".onFailure = [ "backup-notify.service" ];
            backup-notify = {
              description = "Notify ntfy on backup or check failure";
              serviceConfig = {
                Type = "oneshot";
                ExecStart = lib.getExe notifier;
              };
            };
          })
        ];
      };
    };
}
