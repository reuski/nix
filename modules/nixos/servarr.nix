{ ... }:
{
  flake.modules.nixos.servarr =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.media.servarr;
      media = config.media;
      inherit (lib)
        mapAttrs
        mkIf
        mkOption
        types
        ;

      apps = {
        sonarr.port = 8989;
        radarr.port = 7878;
        prowlarr.port = 9696;
      };
    in
    {
      options.media.servarr.enable = mkOption {
        type = types.bool;
        default = false;
      };

      config = mkIf cfg.enable {
        quadlets = mapAttrs (name: app: {
          image = "lscr.io/linuxserver/${name}:latest";
          identity = true;
          inherit (app) port;
          stateDir.path = "/var/lib/${name}";
          volumes = [ "${media.libraryDir}:${media.libraryDir}" ];
        }) apps
        // {
          flaresolverr = {
            image = "ghcr.io/flaresolverr/flaresolverr:latest";
            environment.LOG_LEVEL = "info";
          };
        };
      };
    };
}
