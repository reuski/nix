{ ... }:
{
  flake.modules.nixos.servarr =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.servarr;
      media = config.media;
      inherit (lib) genAttrs mapAttrs mkEnableOption mkIf;

      apps = {
        sonarr.port = 8989;
        radarr.port = 7878;
        lidarr.port = 8686;
        prowlarr.port = 9696;
      };

      rootFolders = [
        "${media.libraryDir}/movies"
        "${media.libraryDir}/series"
        "${media.libraryDir}/music"
      ];
    in
    {
      options.servarr.enable = mkEnableOption "the servarr media stack";

      config = mkIf cfg.enable {
        quadlets =
          mapAttrs (name: app: {
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

        media.directories = genAttrs rootFolders (_: { });
      };
    };
}
