{ ... }:
{
  flake.modules.nixos.janitorr =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.media.janitorr;
      inherit (lib)
        mkIf
        mkOption
        types
        ;

      appConfig = pkgs.writeText "janitorr-application.yml" ''
        management:
          endpoints:
            web:
              exposure:
                include: health,info

        application:
          dry-run: ${lib.boolToString cfg.dryRun}
          leaving-soon: 14d
          exclusion-tags:
            - janitorr_keep
          media-deletion:
            enabled: true
            movie-expiration:
              5: 15d
              10: 30d
              15: 60d
              20: 90d
            season-expiration:
              5: 15d
              10: 20d
              15: 60d
              20: 120d
          tag-based-deletion:
            enabled: false
          episode-deletion:
            enabled: false

        clients:
          sonarr:
            enabled: true
            url: http://127.0.0.1:8989
            delete-empty-shows: true
          radarr:
            enabled: true
            url: http://127.0.0.1:7878
          jellyfin:
            enabled: true
            url: http://127.0.0.1:8096
            delete: true
            exclude-favorited: true
            leaving-soon-type: NONE
      '';
    in
    {
      options.media.janitorr = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        dryRun = mkOption {
          type = types.bool;
          default = false;
        };
        secretsFile = mkOption {
          type = types.str;
          description = "Path to YAML file with API key overrides (managed by sops).";
        };
        port = mkOption {
          type = types.port;
          default = 8978;
        };
        user = mkOption {
          type = types.str;
          default = "janitorr";
        };
        group = mkOption {
          type = types.str;
          default = "janitorr";
        };
      };

      config = mkIf cfg.enable {
        users.users.${cfg.user} = {
          isSystemUser = true;
          group = cfg.group;
        };
        users.groups.${cfg.group} = { };

        proxy.services.janitorr.port = cfg.port;

        systemd.services.janitorr = {
          description = "Janitorr media cleanup";
          wantedBy = [ "multi-user.target" ];
          wants = [ "network-online.target" ];
          after = [
            "network-online.target"
            "sops-install-secrets.service"
          ];
          serviceConfig = {
            Type = "simple";
            User = cfg.user;
            Group = cfg.group;
            StateDirectory = "janitorr";
            WorkingDirectory = "/var/lib/janitorr";
            ExecStart = "${pkgs.janitorr}/bin/janitorr --server.port=${toString cfg.port} --spring.config.location=classpath:/,file:${appConfig},file:${cfg.secretsFile}";
            Restart = "on-failure";
            RestartSec = "30s";
            UMask = "0077";
          };
        };
      };
    };
}
