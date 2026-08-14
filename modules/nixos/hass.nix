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
      inherit (lib) mkEnableOption mkIf;
      configuration = pkgs.writeText "home-assistant-configuration.yaml" ''
        default_config:

        frontend:
          themes: !include_dir_merge_named themes

        automation: !include automations.yaml
        script: !include scripts.yaml
        scene: !include scenes.yaml
      '';
    in
    {
      options.hass.enable = mkEnableOption "Home Assistant";

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
