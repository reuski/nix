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
        ./_desktop.nix
      ];

      networking.hostName = "abraxas";
      networking.computerName = "abraxas";
      networking.localHostName = "abraxas";

      nixpkgs.hostPlatform = "aarch64-darwin";

      home-manager.users.${config.profile.username} = {
        imports = [
          homeManager.dev
          homeManager.llama
          homeManager.colima
          homeManager.postgres
          homeManager.redis
        ];
      };

      system.stateVersion = 6;
    };
}
