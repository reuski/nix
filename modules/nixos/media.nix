{ ... }:
{
  flake.modules.nixos.media =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.media;
      inherit (lib) mkOption types;
    in
    {
      options.media = {
        user = mkOption {
          type = types.str;
          default = "media";
        };
        group = mkOption {
          type = types.str;
          default = "media";
        };
        uid = mkOption {
          type = types.ints.unsigned;
          default = 985;
        };
        gid = mkOption {
          type = types.ints.unsigned;
          default = 985;
        };
        libraryDir = mkOption {
          type = types.str;
          default = "/srv/media";
        };
        containerEnv = mkOption {
          type = types.attrsOf types.str;
          readOnly = true;
          default = {
            TZ = config.profile.timeZone;
            PUID = toString cfg.uid;
            PGID = toString cfg.gid;
            UMASK = "002";
          };
          description = "Shared identity environment for linuxserver.io media containers.";
        };
      };

      config = {
        users.groups.${cfg.group}.gid = cfg.gid;
        users.users.${cfg.user} = {
          isSystemUser = true;
          uid = cfg.uid;
          group = cfg.group;
        };
        users.users.${config.profile.username}.extraGroups = [ cfg.group ];

        systemd.tmpfiles.rules = [
          "d ${cfg.libraryDir} 2775 ${cfg.user} ${cfg.group} -"
        ];
      };
    };
}
