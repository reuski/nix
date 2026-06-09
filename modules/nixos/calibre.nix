{ ... }:
{
  flake.modules.nixos.calibre =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.media.calibre;
      media = config.media;
      inherit (lib) mkIf mkOption types;

      webPort = 8084;
    in
    {
      options.media.calibre = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        library = mkOption {
          type = types.str;
          default = "${media.libraryDir}/books";
        };
      };

      config = mkIf cfg.enable {
        media.directories.${cfg.library} = { };

        systemd.services.calibre-init = {
          requiredBy = [ "calibre-web.service" ];
          before = [ "calibre-web.service" ];
          environment.QT_QPA_PLATFORM = "offscreen";
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            User = media.user;
            Group = media.group;
            UMask = "0002";
          };
          script = ''
            test -f ${cfg.library}/metadata.db \
              || ${pkgs.calibre}/bin/calibredb --with-library=${cfg.library} list >/dev/null
          '';
        };

        services.calibre-web = {
          enable = true;
          listen.ip = "127.0.0.1";
          listen.port = webPort;
          user = media.user;
          group = media.group;
          options = {
            calibreLibrary = cfg.library;
            enableBookConversion = true;
            enableBookUploading = true;
          };
        };

        systemd.services.calibre-web.serviceConfig.UMask = "0002";

        proxy.services.calibre.port = webPort;
      };
    };
}
