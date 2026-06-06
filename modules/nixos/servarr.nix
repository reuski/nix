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
        mapAttrsToList
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
        virtualisation.quadlet.containers =
          mapAttrs (name: _: {
            containerConfig = {
              image = "lscr.io/linuxserver/${name}:latest";
              inherit name;
              networks = [ "host" ];
              autoUpdate = "registry";
              environments = media.containerEnv;
              volumes = [
                "/var/lib/${name}:/config"
                "${media.libraryDir}:${media.libraryDir}"
              ];
            };
          }) apps
          // {
            flaresolverr.containerConfig = {
              image = "ghcr.io/flaresolverr/flaresolverr:latest";
              name = "flaresolverr";
              networks = [ "host" ];
              autoUpdate = "registry";
              environments = {
                TZ = config.profile.timeZone;
                LOG_LEVEL = "info";
              };
            };
          };

        proxy.services = mapAttrs (_: app: { inherit (app) port; }) apps;

        systemd.tmpfiles.rules = mapAttrsToList (
          name: _: "d /var/lib/${name} 0755 ${media.user} ${media.group} -"
        ) apps;
      };
    };
}
