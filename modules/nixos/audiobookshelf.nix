{ ... }:
{
  flake.modules.nixos.audiobookshelf =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.media.audiobookshelf;
      inherit (lib)
        getExe'
        mkIf
        mkOption
        types
        ;

      port = 8000;
      tailscale = getExe' config.services.tailscale.package "tailscale";
    in
    {
      options.media.audiobookshelf = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        group = mkOption {
          type = types.str;
          default = "media";
        };
        libraries = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };
        tailscaleServe = mkOption {
          type = types.bool;
          default = false;
        };
      };

      config = mkIf cfg.enable {
        services.audiobookshelf = {
          enable = true;
          group = cfg.group;
          host = "127.0.0.1";
          inherit port;
        };

        proxy.services.audiobookshelf.port = port;

        users.groups.${cfg.group} = { };
        users.users = {
          audiobookshelf.extraGroups = [ cfg.group ];
          ${config.profile.username}.extraGroups = [ cfg.group ];
        };

        systemd.tmpfiles.rules = map (
          path: "d ${path} 2775 ${config.profile.username} ${cfg.group} -"
        ) cfg.libraries;

        systemd.services = {
          audiobookshelf.serviceConfig.UMask = "0002";

          audiobookshelf-tailscale = mkIf cfg.tailscaleServe {
            description = "Expose Audiobookshelf over Tailscale Serve";
            wantedBy = [ "multi-user.target" ];
            wants = [ "tailscaled.service" ];
            after = [
              "tailscaled.service"
              "audiobookshelf.service"
            ];
            unitConfig = {
              StartLimitIntervalSec = "5min";
              StartLimitBurst = 5;
            };
            serviceConfig = {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = "${tailscale} serve --bg --https 443 http://127.0.0.1:${toString port}";
              ExecStop = "${tailscale} serve --https 443 off";
              Restart = "on-failure";
              RestartSec = "10s";
            };
          };
        };
      };
    };
}
