{ ... }:
{
  flake.modules.nixos.mumble =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.mumble;
      inherit (lib) mkEnableOption mkIf mkOption types;
    in
    {
      options.mumble = {
        enable = mkEnableOption "the Mumble (murmur) VOIP server";
        environmentFile = mkOption {
          type = types.str;
          description = "sops env file providing MUMBLE_PASSWORD=<server password>.";
        };
      };

      config = mkIf cfg.enable {
        services.murmur = {
          enable = true;
          openFirewall = true;
          password = "$MUMBLE_PASSWORD";
          environmentFile = cfg.environmentFile;
        };
      };
    };
}
