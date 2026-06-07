{ ... }:
{
  flake.modules.nixos.hass =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.hass;
      inherit (lib) mkIf mkOption types;
      configuration = pkgs.writeText "home-assistant-configuration.yaml" ''
        default_config:

        frontend:
          themes: !include_dir_merge_named themes

        http:
          use_x_forwarded_for: true
          trusted_proxies:
            - 127.0.0.1
            - "::1"

        automation: !include automations.yaml
        script: !include scripts.yaml
        scene: !include scenes.yaml
      '';
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
          volumes = [ "${configuration}:/config/configuration.yaml:ro" ];
        };
      };
    };
}
