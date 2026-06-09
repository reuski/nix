{ ... }:
{
  flake.modules.nixos.navidrome =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.media.navidrome;
      media = config.media;
      inherit (lib) mkIf mkOption types;

      port = 4533;
    in
    {
      options.media.navidrome = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        musicFolder = mkOption {
          type = types.str;
          default = "${media.libraryDir}/music";
        };
        environmentFile = mkOption {
          type = types.nullOr types.path;
          default = null;
          description = "Env file for first-run admin (ND_DEVAUTOCREATEADMINPASSWORD).";
        };
      };

      config = mkIf cfg.enable {
        services.navidrome = {
          enable = true;
          inherit (cfg) environmentFile;
          settings = {
            Address = "127.0.0.1";
            Port = port;
            MusicFolder = cfg.musicFolder;
          };
        };

        users.users.navidrome.extraGroups = [ media.group ];

        media.directories.${cfg.musicFolder} = { };

        proxy.services.navidrome.port = port;
      };
    };
}
