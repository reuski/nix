{ config, inputs, ... }:
let
  inherit (config.flake.modules) homeManager nixos;
in
{
  configurations.nixos.sampo.module =
    { config, ... }:
    {
      imports = [
        inputs.disko.nixosModules.disko
        ./_disko.nix
        ./_hardware.nix
        nixos.desktop
        nixos.gaming
        ./_audio.nix
      ];

      sops.secrets.env = {
        owner = config.profile.username;
      };

      home-manager.users.${config.profile.username}.imports = [
        homeManager.dev
        homeManager.secrets
      ];

      system.stateVersion = config.system.nixos.release;
    };
}
