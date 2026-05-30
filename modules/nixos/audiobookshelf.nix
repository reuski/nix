{ ... }:
{
  flake.modules.nixos.audiobookshelf =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.media.audiobookshelf;
      inherit (lib)
        mkIf
        mkOption
        types
        ;

      port = 8000;
    in
    {
      options.media.audiobookshelf = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        group = mkOption {
          type = types.str;
          default = "media";
        };
        libraries = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };
      };

      config = mkIf cfg.enable {
        services.audiobookshelf = {
          enable = true;
          group = cfg.group;
          host = "127.0.0.1";
          inherit port;
        };

        proxy.services.audiobookshelf.port = port;

        users.groups.${cfg.group} = { };
        users.users = {
          audiobookshelf.extraGroups = [ cfg.group ];
          ${config.profile.username}.extraGroups = [ cfg.group ];
        };

        systemd.tmpfiles.rules = map (
          path: "d ${path} 2775 ${config.profile.username} ${cfg.group} -"
        ) cfg.libraries;

        systemd.services.audiobookshelf.serviceConfig.UMask = "0002";
      };
    };
}
