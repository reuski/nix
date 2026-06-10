{ ... }:
{
  flake.modules.nixos.tome =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.tome;
      inherit (lib)
        mkEnableOption
        mkIf
        mkOption
        types
        ;
      port = 3001;
    in
    {
      options.tome = {
        enable = mkEnableOption "Tome";
        calibreLibrary = mkOption {
          type = types.str;
          default = config.calibre.library;
          description = "Calibre library mounted read-write so Tome can sync progress back to metadata.db.";
        };
      };

      config = mkIf cfg.enable {
        assertions = [
          {
            assertion = config.calibre.enable;
            message = "tome requires calibre.enable for the shared library.";
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
