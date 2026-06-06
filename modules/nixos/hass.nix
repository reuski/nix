{ ... }:
{
  flake.modules.nixos.hass =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.hass;
      inherit (lib) mkIf mkOption types;
    in
    {
      options.hass.enable = mkOption {
        type = types.bool;
        default = false;
      };

      config = mkIf cfg.enable {
        quadlets.hass = {
          image = "ghcr.io/home-assistant/home-assistant:stable";
          port = 8123;
          stateDir = {
            path = "/var/lib/home-assistant";
            owner = "root";
            group = "root";
          };
        };
      };
    };
}
