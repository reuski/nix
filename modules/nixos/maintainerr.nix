{ ... }:
{
  flake.modules.nixos.maintainerr =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.maintainerr;
      media = config.media;
      inherit (lib) mkEnableOption mkIf;
      port = 6246;
    in
    {
      options.maintainerr.enable = mkEnableOption "Maintainerr";

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
