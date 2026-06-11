{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  flake.modules.darwin.secrets =
    { config, ... }:
    {
      home-manager.users.${config.profile.username} = {
        imports = [ homeManager.secrets ];
        sops.defaultSopsFile = ../../secrets + "/${config.networking.hostName}.yaml";
      };
    };
}
