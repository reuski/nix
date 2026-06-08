{ ... }:
{
  flake.modules.nixos.tome =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.media.tome;
      inherit (lib) mkIf mkOption types;
      port = 3001;
    in
    {
      options.media.tome = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        calibreLibrary = mkOption {
          type = types.str;
          default = config.media.calibre.library;
          description = "Calibre library mounted read-write so Tome can sync progress back to metadata.db.";
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = config.media.calibre.enable;
            message = "media.tome requires media.calibre.enable for the shared library.";
          }
        ];

        quadlets.tome = {
          image = "ghcr.io/masonfox/tome:latest";
          identity = true;
          inherit port;
          environment = {
            PORT = toString port;
            CALIBRE_DB_PATH = "/calibre/metadata.db";
            NEXT_PUBLIC_BASE_URL = "https://tome.${config.proxy.domain}";
          };
          stateDir = {
            path = "/var/lib/tome";
            mount = "/app/data";
          };
          volumes = [ "${cfg.calibreLibrary}:/calibre" ];
        };
      };
    };
}
