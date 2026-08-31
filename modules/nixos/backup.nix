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
        text = ''curl -fsS -H "Priority: high" --data-raw "${host} // BACKUP FAILED" "${cfg.notify}" || true'';
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
          description = "Absolute paths backed up off-site: the unreproducible state a fresh install would lose.";
        };
        repository = lib.mkOption {
          type = lib.types.str;
          example = "rclone:filen:nixbackup/ukko";
          description = "restic repository. The provider lives in the rclone remote, so switching clouds is a one-line change.";
        };
        passwordFile = lib.mkOption {
          type = lib.types.path;
          description = "restic repository password (sops). Kept in encrypted git so a scratched host can restore itself.";
        };
        rcloneConfigFile = lib.mkOption {
          type = lib.types.path;
          description = "rclone config for the remote named in repository (sops). restic encrypts client-side before it is touched.";
        };
        notify = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional ntfy topic a failed run is POSTed to. A silent backup failure is the only one that matters.";
        };
        stampPath = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          description = "Optional path overwritten with the Unix timestamp of each successful run, feeding the heimdash backup card (age + freshness).";
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
          pruneOpts = [ "--keep-within 90d" ];
          checkOpts = [ "--read-data-subset=1/7" ];
          timerConfig = {
            OnCalendar = "*-*-* 0/4:00:00";
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
            backup-notify = {
              description = "Notify ntfy on backup failure";
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
