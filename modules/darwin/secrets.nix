{ config, ... }:
let
  inherit (config.flake.modules) homeManager;
in
{
  flake.modules.darwin.secrets =
    { config, ... }:
    {
      home-manager.users.${config.profile.username} = {
        imports = [
          homeManager.secrets
          homeManager.ssh
        ];
        sops.defaultSopsFile =
          let
            hostFile = ../../secrets + "/${config.networking.hostName}.yaml";
          in
          if builtins.pathExists hostFile then hostFile else ../../secrets/env.yaml;
        sops.secrets.env.sopsFile = ../../secrets/env.yaml;
        sops.secrets."ssh/id_ed25519" = {
          sopsFile = ../../secrets/ssh.yaml;
          mode = "0400";
        };
        sops.secrets.admin_age_key = {
          sopsFile = ../../secrets/admin.yaml;
          mode = "0400";
        };
      };
    };
}
