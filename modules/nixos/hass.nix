{ ... }:
{
  flake.modules.nixos.hass =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.homeAssistant;
      inherit (lib) mkIf mkOption types;
      port = 8123;
      dataDir = "/var/lib/home-assistant";
    in
    {
      options.homeAssistant.enable = mkOption {
        type = types.bool;
        default = false;
      };

      config = mkIf cfg.enable {
        virtualisation.quadlet.containers.home-assistant.containerConfig = {
          image = "ghcr.io/home-assistant/home-assistant:stable";
          name = "home-assistant";
          networks = [ "host" ];
          autoUpdate = "registry";
          environments.TZ = config.profile.timeZone;
          volumes = [ "${dataDir}:/config" ];
        };

        proxy.services.hass.port = port;

        systemd.tmpfiles.rules = [
          "d ${dataDir} 0750 root root -"
        ];
      };
    };
}
