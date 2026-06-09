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
      inherit (lib) mapAttrsToList mkOption types;

      directoryType = types.submodule {
        options = {
          mode = mkOption {
            type = types.str;
            default = "2775";
          };
          owner = mkOption {
            type = types.str;
            default = cfg.user;
          };
          group = mkOption {
            type = types.str;
            default = cfg.group;
          };
        };
      };
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
        directories = mkOption {
          type = types.attrsOf directoryType;
          default = { };
          description = "Directories created via tmpfiles, owned by the media identity by default.";
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

        media.directories.${cfg.libraryDir} = { };

        systemd.tmpfiles.rules = mapAttrsToList (
          path: d: "d ${path} ${d.mode} ${d.owner} ${d.group} -"
        ) cfg.directories;
      };
    };
}
