{ config, ... }:
let
  inherit (config.flake.modules) darwin;
in
{
  configurations.darwin.abraxas.module =
    { config, ... }:
    {
      imports = [
        darwin.mac
        darwin.development
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
