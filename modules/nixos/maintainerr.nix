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
      dataDir = "/var/lib/maintainerr";
    in
    {
      options.media.maintainerr.enable = mkOption {
        type = types.bool;
        default = false;
      };

      config = mkIf cfg.enable {
        # No linuxserver.io image exists for maintainerr; ghcr is upstream's own.
        virtualisation.quadlet.containers.maintainerr.containerConfig = {
          image = "ghcr.io/maintainerr/maintainerr:latest";
          name = "maintainerr";
          networks = [ "host" ];
          autoUpdate = "registry";
          user = "${toString media.uid}:${toString media.gid}";
          environments = {
            TZ = config.profile.timeZone;
            UI_HOSTNAME = "127.0.0.1";
            UI_PORT = toString port;
          };
          volumes = [ "${dataDir}:/opt/data:rw" ];
        };

        proxy.services.maintainerr.port = port;

        systemd.tmpfiles.rules = [
          "d ${dataDir} 0750 ${media.user} ${media.group} -"
        ];
      };
    };
}
