{ ... }:
{
  flake.modules.nixos.degoog =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.degoog;
      port = 4444;
      inherit (lib)
        mkEnableOption
        mkIf
        mkOption
        types
        ;
    in
    {
      options.degoog = {
        enable = mkEnableOption "Degoog metasearch";
        environmentFile = mkOption {
          type = types.path;
          description = "SOPS-provided environment file containing DEGOOG_SETTINGS_PASSWORDS.";
        };
      };

      config = mkIf cfg.enable {
        quadlets.degoog = {
          image = "ghcr.io/degoog-org/degoog:latest";
          identity = true;
          inherit port;
          containerConfig = {
            networks = [ ];
            publishPorts = [ "127.0.0.1:${toString port}:${toString port}" ];
            healthOnFailure = "kill";
          };
          environment.DEGOOG_DISTRUST_PROXY = "0";
          environmentFiles = [ cfg.environmentFile ];
          stateDir = {
            path = "/var/lib/degoog";
            mount = "/app/data";
          };
        };
      };
    };
}
