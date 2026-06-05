{ inputs, ... }:
{
  flake.modules.nixos.heimdash =
    { config, lib, ... }:
    let
      cfg = config.services.heimdash;
      port = 8082;
    in
    {
      imports = [ inputs.heimdash.nixosModules.default ];

      services.heimdash.listen = lib.mkDefault "127.0.0.1:${toString port}";

      proxy.services = lib.mkIf cfg.enable {
        heimdash.port = port;
      };
    };
}
