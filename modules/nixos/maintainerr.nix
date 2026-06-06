{ ... }:
{
  flake.modules.nixos.maintainerr =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.media.maintainerr;
      media = config.media;
      inherit (lib) mkIf mkOption types;
      port = 6246;
    in
    {
      options.media.maintainerr.enable = mkOption {
        type = types.bool;
        default = false;
      };

      config = mkIf cfg.enable {
        quadlets.maintainerr = {
          image = "ghcr.io/maintainerr/maintainerr:latest";
          user = "${toString media.uid}:${toString media.gid}";
          inherit port;
          environment = {
            UI_HOSTNAME = "127.0.0.1";
            UI_PORT = toString port;
          };
          stateDir = {
            path = "/var/lib/maintainerr";
            mount = "/opt/data";
          };
        };
      };
    };
}
