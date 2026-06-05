{ ... }:
{
  flake.modules.nixos.tailnet =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.tailnet;
      inherit (lib)
        concatStringsSep
        getExe'
        mapAttrsToList
        mkIf
        mkOption
        types
        unique
        ;

      tailscale = getExe' config.services.tailscale.package "tailscale";

      serviceType = types.submodule (
        { config, ... }:
        {
          options = {
            host = mkOption {
              type = types.str;
              default = "127.0.0.1";
            };
            port = mkOption { type = types.port; };
            https = mkOption {
              type = types.port;
              default = config.port;
            };
          };
        }
      );

      serveLines = mapAttrsToList (
        _name: service:
        "${tailscale} serve --bg --https ${toString service.https} http://${service.host}:${toString service.port}"
      ) cfg.services;

      httpsPorts = mapAttrsToList (_name: service: service.https) cfg.services;
    in
    {
      options.tailnet.services = mkOption {
        type = types.attrsOf serviceType;
        default = { };
      };

      config = mkIf (cfg.services != { }) {
        assertions = [
          {
            assertion = builtins.length httpsPorts == builtins.length (unique httpsPorts);
            message = "tailnet.services https ports must be unique.";
          }
        ];

        systemd.services.tailnet-serve = {
          description = "Expose services over Tailscale Serve";
          wantedBy = [ "multi-user.target" ];
          wants = [ "tailscaled.service" ];
          after = [ "tailscaled.service" ];
          unitConfig = {
            StartLimitIntervalSec = "5min";
            StartLimitBurst = 5;
          };
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStartPre = "${tailscale} serve reset";
            ExecStart = pkgs.writeShellScript "tailnet-serve" (concatStringsSep "\n" serveLines);
            ExecStop = "${tailscale} serve reset";
            Restart = "on-failure";
            RestartSec = "10s";
          };
        };
      };
    };
}
