{ config, ... }:
let
  inherit (config.flake.modules) darwin homeManager;
  dev = import ./_dev.nix { inherit darwin homeManager; };
in
{
  configurations.darwin.abraxas.module =
    { config, ... }:
    {
      imports = [
        darwin.mac
        dev
        ./_desktop.nix
      ];

      networking.hostName = "abraxas";
      networking.computerName = "abraxas";
      networking.localHostName = "abraxas";

      nixpkgs.hostPlatform = "aarch64-darwin";

      home-manager.users.${config.profile.username}.sops.secrets.env = { };

      system.stateVersion = 6;
    };
}
