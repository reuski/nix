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
      mediaGroup = config.media.group;
      inherit (lib)
        genAttrs
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
        libraries = mkOption {
          type = types.listOf types.str;
          default = [ ];
        };
      };

      config = mkIf cfg.enable {
        services.audiobookshelf = {
          enable = true;
          group = mediaGroup;
          host = "127.0.0.1";
          inherit port;
        };

        proxy.services.audiobookshelf.port = port;

        users.users.audiobookshelf.extraGroups = [ mediaGroup ];

        media.directories = genAttrs cfg.libraries (_: { });

        systemd.services.audiobookshelf.serviceConfig.UMask = "0002";
      };
    };
}
