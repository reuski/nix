{ config, ... }:
let
  inherit (config.flake.modules) darwin homeManager;
in
{
  configurations.darwin.abraxas.module =
    { config, ... }:
    {
      imports = [
        darwin.mac
        darwin.zed
        darwin.tableplus
        ./_desktop.nix
      ];

      networking.hostName = "abraxas";
      networking.computerName = "abraxas";
      networking.localHostName = "abraxas";

      nixpkgs.hostPlatform = "aarch64-darwin";

      home-manager.users.${config.profile.username} = {
        imports = [
          homeManager.dev
          homeManager.colima
          homeManager.postgres
          homeManager.redis
        ];
        sops.secrets.env.sopsFile = ../../../secrets/env.yaml;
      };

      system.stateVersion = 6;
    };
}
