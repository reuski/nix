{ ... }:
{
  flake.modules.nixos.vaultwarden =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.vaultwarden;
      inherit (lib)
        mkIf
        mkOption
        types
        ;
    in
    {
      options.vaultwarden = {
        enable = mkOption {
          type = types.bool;
          default = false;
        };
        domain = mkOption { type = types.str; };
        port = mkOption {
          type = types.port;
          default = 8222;
        };
        environmentFile = mkOption {
          type = types.nullOr types.path;
          default = null;
        };
      };

      config = mkIf cfg.enable {
        services.vaultwarden = {
          enable = true;
          dbBackend = "sqlite";
          backupDir = "/var/backup/vaultwarden";
          environmentFile = mkIf (cfg.environmentFile != null) cfg.environmentFile;
          config = {
            ROCKET_ADDRESS = "127.0.0.1";
            ROCKET_PORT = cfg.port;
            DOMAIN = cfg.domain;
            SIGNUPS_ALLOWED = false;
            INVITATIONS_ALLOWED = true;
            SIGNUPS_VERIFY = false;
            SHOW_PASSWORD_HINT = false;
          };
        };
      };
    };
}
