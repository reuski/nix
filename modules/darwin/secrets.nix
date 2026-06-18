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
        sops.defaultSopsFile =
          let
            hostFile = ../../secrets + "/${config.networking.hostName}.yaml";
          in
          if builtins.pathExists hostFile then hostFile else ../../secrets/env.yaml;
      };
    };
}
