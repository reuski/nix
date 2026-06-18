{ config, inputs, ... }:
let
  inherit (config.flake.modules) homeManager nixos;
in
{
  configurations.nixos.hiisi.module =
    { config, ... }:
    {
      imports = [
        inputs.disko.nixosModules.disko
        ./_disko.nix
        inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t480
        ./_hardware.nix
        nixos.laptop
        ./_desktop.nix
      ];

      sops.secrets.env = {
        sopsFile = ../../../secrets/env.yaml;
        owner = config.profile.username;
      };

      home-manager.users.${config.profile.username}.imports = [
        homeManager.dev
        homeManager.secrets
      ];

      system.stateVersion = config.system.nixos.release;
    };
}
