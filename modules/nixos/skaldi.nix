{ inputs, ... }:
{
  flake.modules.nixos.skaldi =
    { config, lib, ... }:
    let
      cfg = config.services.skaldi;
      port = 8083;
    in
    {
      imports = [ inputs.skaldi.nixosModules.default ];

      services.skaldi = {
        openFirewall = lib.mkDefault true;
        settings.server.port = port;
      };

      proxy.services = lib.mkIf cfg.enable {
        skaldi.port = port;
      };
    };
}
